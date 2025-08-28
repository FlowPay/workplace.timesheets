import Queues
import Vapor

/// Scheduled job periodically synchronizing data from Microsoft Graph.
public struct GraphSyncJob: AsyncScheduledJob {
    /// Default initializer
    public init() {}

    /// Runs the synchronization job for all configured team identifiers.
    public func run(context: QueueContext) async throws {
        let app = context.application
        let discovered = try await app.graphClient.listTeams(client: app.client)
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        app.logger.info("Scheduled sync start", metadata: ["teams": .string("\(discovered.count)")])
        for team in discovered {
            app.logger.info("Scheduled sync team", metadata: ["teamId": .string(team.id), "name": .string(team.displayName ?? "")])
            let allowedUserIDs = try await Worker.adapterAllowedUserIDs(graph: app.graphClient, client: app.client)
            let users = try await Worker.adapterFetchAll(graph: app.graphClient, client: app.client)
            let workers = try await Worker.dbUpsertAll(from: users, allowedUserIDs: allowedUserIDs, on: app.db)
            let cards = try await TimeEntry.adapterFetchTimeCards(teamId: team.id, from: from, to: now, graph: app.graphClient, client: app.client)
            try await TimeEntry.dbPersistAndReconcile(from: cards, workers: workers, window: (from, now), on: app.db)
            let reasons = try await Leave.adapterFetchReasons(teamId: team.id, graph: app.graphClient, client: app.client)
            let offs = try await Leave.adapterFetchTimeOff(teamId: team.id, from: from, to: now, graph: app.graphClient, client: app.client)
            try await Leave.dbPersistAndReconcile(from: offs, reasons: reasons, workers: workers, window: (from, now), on: app.db)
        }
        app.logger.info("Scheduled sync completed")
    }
}
