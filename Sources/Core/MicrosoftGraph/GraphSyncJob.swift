import Queues
import Vapor

/// Scheduled job periodically synchronizing data from Microsoft Graph.
public struct GraphSyncJob: AsyncScheduledJob {
    /// Default initializer
    public init() {}

    /// Runs the synchronization job for all configured team identifiers.
    public func run(context: QueueContext) async throws {
        let app = context.application
        let teams = Configuration.shared.msGraphTeamIDs
        let service = GraphSyncService()
        for team in teams {
            try await service.sync(teamId: team, app: app)
        }
    }
}
