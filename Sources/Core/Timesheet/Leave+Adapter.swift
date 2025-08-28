import Vapor

/// Adapter functions for Leave: communication with Microsoft Graph (time-off and reasons)
extension Leave {
    /// Fetch time-off requests for a team within an optional time window.
    public static func adapterFetchTimeOff(teamId: String, from: Date?, to: Date?, graph: MicrosoftGraphClientProtocol, client: Client) async throws -> [GraphTimeOff] {
        do {
            return try await graph.listTimeOffRequests(teamId: teamId, from: from, to: to, client: client)
        } catch {
            throw Abort(.internalServerError, reason: "Leave adapter error: \(error.localizedDescription)")
        }
    }

    /// Fetch time-off reasons for a team.
    public static func adapterFetchReasons(teamId: String, graph: MicrosoftGraphClientProtocol, client: Client) async throws -> [GraphTimeOffReason] {
        do {
            return try await graph.listTimeOffReasons(teamId: teamId, client: client)
        } catch {
            throw Abort(.internalServerError, reason: "Leave adapter error: \(error.localizedDescription)")
        }
    }
}
