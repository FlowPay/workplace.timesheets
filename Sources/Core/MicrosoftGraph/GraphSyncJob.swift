import Queues
import Vapor

/// Scheduled job periodically synchronizing data from Microsoft Graph.
public struct GraphSyncJob: AsyncScheduledJob {
    /// Default initializer
    public init() {}

    /// Runs the synchronization job for all configured team identifiers.
    public func run(context: QueueContext) async throws {
        let app = context.application
        let service = GraphSyncService()
        // Auto-discover all Teams using Microsoft Graph
        let discovered = try await app.graphClient.listTeams(client: app.client)
        for team in discovered {
            try await service.sync(teamId: team.id, app: app)
        }
    }
}
