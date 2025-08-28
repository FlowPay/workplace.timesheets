import Core
import Vapor

/// Controller triggering synchronization of data from Microsoft Graph.
public struct SyncController: RouteCollection {
    /// Default initializer
    public init() {}

    /// Registers the `/sync/{teamId}` route.
    public func boot(routes: RoutesBuilder) throws {
        routes.group("sync") { group in
            // Trigger sync for all Teams discovered via Microsoft Graph
            group.post(use: self.syncAll)
            group.post(":teamId", use: self.sync)
        }
    }

    /// Fetches users, shifts and time cards from Microsoft Graph for the provided team.
    /// For now the data is simply fetched to validate connectivity.
    func sync(request: Request) async throws -> Response {
        let teamId: String = try request.parameters.require("teamId")
        let service = GraphSyncService()
        try await service.sync(teamId: teamId, app: request.application)
        return Response(status: .accepted)
    }

    /// Fetches users, shifts and time cards from Microsoft Graph for all discovered Teams.
    /// This endpoint auto-discovers Teams and triggers synchronization for each one.
    func syncAll(request: Request) async throws -> Response {
        let app = request.application
        let teams = try await app.graphClient.listTeams(client: app.client)
        let service = GraphSyncService()
        for team in teams {
            try await service.sync(teamId: team.id, app: app)
        }
        return Response(status: .accepted)
    }
}
