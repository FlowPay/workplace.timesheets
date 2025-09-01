import Core
import Fluent
import Vapor

/// Controller triggering synchronization of data from Microsoft Graph.
public struct SyncController: RouteCollection {
	/// Default initializer
	public init() {}

	/// Registers the `/sync` and `/sync/{teamId}` routes.
	public func boot(routes: RoutesBuilder) throws {
		routes.group("sync") { group in
			// Trigger sync for all Teams discovered via Microsoft Graph
			group.post(use: self.syncAll)

			group.group(":teamId") { team in
				// Trigger sync for a specific Team by its Graph ID
				team.post(use: self.syncWorkers)
			}
		}
	}

	/// Fetches users, shifts and time cards from Microsoft Graph for all discovered Teams.
	/// This endpoint auto-discovers Teams and triggers synchronization for each one.
	func syncAll(request: Request) async throws -> Response {
		struct Query: Content {
			let from: Date?
			let to: Date?
		}
		let q = try? request.query.decode(Query.self)
		let now = Date()
		let from = q?.from ?? Calendar.current.date(byAdding: .day, value: -30, to: now)!
		let to = q?.to ?? now

		let nameFilters = Configuration.shared.msGraphTeamNames
		request.logger.info("/sync invoked from=\(from) to=\(to) teamFilters=\(nameFilters)")
		let summary = try await GraphSyncJob.sync(
			env: request,
			filters: .init(
				teamNameFilters: nameFilters,
				from: from,
				to: to
			)
		)

		return try await summary.encodeResponse(status: .ok, for: request)

	}

	/// Fetches users from Microsoft Graph and upserts them as Workers.
	func syncWorkers(request: Request) async throws -> Response {
		request.logger.debug("Fetching users")
		let users = try await request.graphClient.listUsers(client: request.client)
		request.logger.debug("Found \(users.count) users")
		let workers = users.map(Worker.init)
		request.logger.debug("Workers upserted: \(workers.count) active")
		request.logger.debug("Upserting workers")
		try await workers.upsert(on: request.db)

		return try await Response(status: .ok)
	}
}
