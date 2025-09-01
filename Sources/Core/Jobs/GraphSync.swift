import Fluent
import Vapor

// MARK: - Shared sync environment
public protocol SyncEnvironment {
	var graphClient: MicrosoftGraphClientProtocol { get }
	var client: Client { get }
	var db: Database { get }
	var logger: Logger { get }
}

extension Application: SyncEnvironment {}
extension Request: SyncEnvironment {}

// MARK: - Graph Sync API
extension GraphSyncJob {
	/// Filters used to drive a Graph sync execution
	public struct SyncFilters {
		/// Optional display name filters; when provided, discovered teams are filtered by these substrings.
		public var teamNameFilters: [String]
		/// Optional date window. If nil, a default rolling window is applied using `fallbackDays`.
		public var from: Date
		/// Optional date window end. Defaults to `Date()` when not provided.
		public var to: Date

		public init(
			teamNameFilters: [String],
			from: Date,
			to: Date
		) {
			self.teamNameFilters = teamNameFilters
			self.from = from
			self.to = to
		}
	}

	/// Summary of persisted data produced by a sync execution
	public struct SyncSummary: Content {
		public let from: Date?
		public let to: Date?
		public let workersTotal: Int
		public let timeEntriesInWindow: Int
		public let breaksInWindow: Int
		public let plannedShiftsInWindow: Int
		public let plannedBreaksInWindow: Int
		public let leavesOverlappingWindow: Int
	}

	/// Executes a synchronization against Microsoft Graph using the provided filters.
	/// Breaks the orchestration into smaller documented steps for clarity and reuse.
	/// - Parameters:
	///   - env: Execution environment (Graph client, HTTP client, DB and Logger).
	///   - filters: Sync filters (teams by name, time window).
	/// - Returns: A `SyncSummary` with counts for the selected time window.
	@discardableResult
	public static func sync(env: SyncEnvironment, filters: SyncFilters) async throws -> SyncSummary {
		let from = filters.from
		let to = filters.to

		print("[GraphSync] start from=\(from) to=\(to) teamFilters=\(filters.teamNameFilters)")

		env.logger.debug("Fetching users")
		let users = try await env.graphClient.listUsers(client: env.client)
		env.logger.debug("Found \(users.count) users")
		let workers = users.map(Worker.init)
		env.logger.debug("Workers upserted: \(workers.count) active")
		env.logger.debug("Upserting workers")
		try await workers.upsert(on: env.db)

		// 1) Resolve teams to process
		env.logger.debug("Discovering teams")
		let teams: [GraphTeam] = try await env.graphClient.listTeams(client: env.client)
		print("[GraphSync] discovered teams=\(teams.count)")

		// 2) Process each team independently
		for team in teams {
			do {
				guard filters.teamNameFilters.isEmpty || filters.teamNameFilters.contains(where: { team.displayName?.contains($0) == true }) else {
					env.logger.debug("Skipping team \(team.id) (\(team.displayName ?? "")) due to name filter")
					continue
				}
				print("[GraphSync] sync team id=\(team.id) name=\(team.displayName ?? "")")

				env.logger.debug("Fetching team shifts")
				let graphShifts = try await env.graphClient.listShifts(teamId: team.id, from: from, to: to, top: nil, client: env.client)
				print("[GraphSync] team \(team.id) shifts=\(graphShifts.count)")
				let plannedShiftResults = try await PlannedShift.upsert(from: graphShifts, workers: workers, prune: false, on: env.db)
				env.logger.info("Planned shifts upserted: \(plannedShiftResults.1) inserted, \(plannedShiftResults.0) updated, \(plannedShiftResults.2) deleted")

				env.logger.debug("Fetching team time cards")
				let graphTimeCards = try await env.graphClient.listTimeCards(teamId: team.id, from: from, to: to, top: nil, client: env.client)
				print("[GraphSync] team \(team.id) timeCards=\(graphTimeCards.count)")
				let timeEntryResults = try await TimeEntry.upsert(from: graphTimeCards, workers: workers, prune: false, on: env.db)
				env.logger.info("Time entries upserted: \(timeEntryResults.1) inserted, \(timeEntryResults.0) updated, \(timeEntryResults.2) deleted")

				env.logger.debug("Fetching team time off requests and reasons")
				let listTimeOffReasons = try await env.graphClient.listTimeOffReasons(teamId: team.id, client: env.client)
				env.logger.debug("Team \(team.id) timeOff reasons=\(listTimeOffReasons.count)")
				let listTimeOffRequests = try await env.graphClient.listTimeOffRequests(teamId: team.id, from: from, to: to, top: nil, client: env.client)
				env.logger.info("Team \(team.id) timeOff requests received=\(listTimeOffRequests.count)")

				env.logger.debug("Upserting time off requests")
				try await Leave.upsert(from: listTimeOffRequests, reasons: listTimeOffReasons, workers: workers, prune: false, on: env.db)

			} catch {
				env.logger.error("Error syncing team \(team.id): \(String(reflecting: error))")
				env.logger.report(error: error)

			}
		}

		// 3) Summarize persisted data
		let summary = try await summarize(window: (from, to), on: env.db)
		env.logger.info("Graph sync completed")
		return summary
	}

	// MARK: Summary helper
	public static func summarize(window: (from: Date?, to: Date?), on db: Database) async throws -> SyncSummary {
		let workersTotal = try await Worker.query(on: db).count()

		var timeEntriesCount = 0
		if let from = window.from, let to = window.to {
			timeEntriesCount = try await TimeEntry.query(on: db)
				.filter(\.$date >= from)
				.filter(\.$date <= to)
				.count()
		}

		var breaksCount = 0
		if let from = window.from, let to = window.to {
			breaksCount = try await Break.query(on: db)
				.filter(\.$startAt >= from)
				.filter(\.$startAt <= to)
				.count()
		}

		var plannedShiftsCount = 0
		if let from = window.from, let to = window.to {
			plannedShiftsCount = try await PlannedShift.query(on: db)
				.filter(\.$date >= from)
				.filter(\.$date <= to)
				.count()
		}

		var plannedBreaksCount = 0
		if let from = window.from, let to = window.to {
			plannedBreaksCount = try await PlannedBreak.query(on: db)
				.filter(\.$startAt >= from)
				.filter(\.$startAt <= to)
				.count()
		}

		var leavesCount = 0
		if let from = window.from, let to = window.to {
			leavesCount = try await Leave.query(on: db)
				.group(.and) { g in
					g.filter(\.$startAt <= to)
					g.filter(\.$endAt >= from)
				}
				.count()
		}

		return SyncSummary(
			from: window.from,
			to: window.to,
			workersTotal: workersTotal,
			timeEntriesInWindow: timeEntriesCount,
			breaksInWindow: breaksCount,
			plannedShiftsInWindow: plannedShiftsCount,
			plannedBreaksInWindow: plannedBreaksCount,
			leavesOverlappingWindow: leavesCount
		)
	}
}
