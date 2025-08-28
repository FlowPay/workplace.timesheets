import Core
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
			group.post(":teamId", use: self.sync)
		}
	}

	/// Fetches users, shifts and time cards from Microsoft Graph for the provided team.
	/// Orchestrates adapter (HTTP) and DB operations directly.
	func sync(request: Request) async throws -> Response {
		struct Query: Content {
			let from: Date?
			let to: Date?
			let days: Int?
		}
		let q = try? request.query.decode(Query.self)
		let now = Date()
		let defaultFrom = Calendar.current.date(byAdding: .day, value: -30, to: now)!
		let from = q?.from ?? (q?.days != nil ? Calendar.current.date(byAdding: .day, value: -(q!.days!), to: now)! : defaultFrom)
		let to = q?.to ?? now
		let teamId: String = try request.parameters.require("teamId")

		request.logger.info("Sync start", metadata: ["teamId": .string(teamId)])

		let allowedUserIDs = try await Worker.adapterAllowedUserIDs(graph: request.graphClient, client: request.client)
		let users = try await Worker.adapterFetchAll(graph: request.graphClient, client: request.client)
		request.logger.info("Users fetched", metadata: ["count": .string("\(users.count)")])
		let workers = try await Worker.dbUpsertAll(from: users, allowedUserIDs: allowedUserIDs, on: request.db)
		request.logger.info("Workers upserted", metadata: ["count": .string("\(workers.count)")])

		let cards = try await TimeEntry.adapterFetchTimeCards(teamId: teamId, from: from, to: to, graph: request.graphClient, client: request.client)
		request.logger.info("TimeCards fetched", metadata: ["count": .string("\(cards.count)")])
		try await TimeEntry.dbPersistAndReconcile(from: cards, workers: workers, window: (from, to), on: request.db)

		let reasons = try await Leave.adapterFetchReasons(teamId: teamId, graph: request.graphClient, client: request.client)
		let offs = try await Leave.adapterFetchTimeOff(teamId: teamId, from: from, to: to, graph: request.graphClient, client: request.client)
		request.logger.info("TimeOff fetched", metadata: ["count": .string("\(offs.count)")])
		try await Leave.dbPersistAndReconcile(from: offs, reasons: reasons, workers: workers, window: (from, to), on: request.db)

		request.logger.info("Sync completed", metadata: ["teamId": .string(teamId)])
		return Response(status: .accepted)
	}

	/// Fetches users, shifts and time cards from Microsoft Graph for all discovered Teams.
	/// This endpoint auto-discovers Teams and triggers synchronization for each one.
	func syncAll(request: Request) async throws -> Response {
		struct Query: Content {
			let from: Date?
			let to: Date?
			let days: Int?
		}
		let q = try? request.query.decode(Query.self)
		let now = Date()
		let defaultFrom = Calendar.current.date(byAdding: .day, value: -30, to: now)!
		let from = q?.from ?? (q?.days != nil ? Calendar.current.date(byAdding: .day, value: -(q!.days!), to: now)! : defaultFrom)
		let to = q?.to ?? now

		let teams = try await request.graphClient.listTeams(client: request.client)
		request.logger.info("Sync all start", metadata: ["teams": .string("\(teams.count)")])
		for team in teams {
			do {
				request.logger.info("Sync team", metadata: ["teamId": .string(team.id), "name": .string(team.displayName ?? "")])
				let allowedUserIDs = try await Worker.adapterAllowedUserIDs(graph: request.graphClient, client: request.client)
				let users = try await Worker.adapterFetchAll(graph: request.graphClient, client: request.client)
				let workers = try await Worker.dbUpsertAll(from: users, allowedUserIDs: allowedUserIDs, on: request.db)
				let cards = try await TimeEntry.adapterFetchTimeCards(teamId: team.id, from: from, to: to, graph: request.graphClient, client: request.client)
				try await TimeEntry.dbPersistAndReconcile(from: cards, workers: workers, window: (from, to), on: request.db)
				let reasons = try await Leave.adapterFetchReasons(teamId: team.id, graph: request.graphClient, client: request.client)
				let offs = try await Leave.adapterFetchTimeOff(teamId: team.id, from: from, to: to, graph: request.graphClient, client: request.client)
				try await Leave.dbPersistAndReconcile(from: offs, reasons: reasons, workers: workers, window: (from, to), on: request.db)
			} catch {
				request.logger.report(error: error)
				request.logger.error("Sync team failed", metadata: ["teamId": .string(team.id), "error": .string(error.localizedDescription)])
			}
		}
		request.logger.info("Sync all completed")
		return Response(status: .accepted)
	}
}
