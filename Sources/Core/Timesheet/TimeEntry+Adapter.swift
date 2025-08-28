import Vapor

/// Adapter functions for TimeEntry: communication with Microsoft Graph (time cards)
extension TimeEntry {
    /// Fetch time cards for a team within an optional time window.
    public static func adapterFetchTimeCards(teamId: String, from: Date?, to: Date?, graph: MicrosoftGraphClientProtocol, client: Client) async throws -> [GraphTimeCard] {
        do {
            return try await graph.listTimeCards(teamId: teamId, from: from, to: to, client: client)
        } catch {
            throw Abort(.internalServerError, reason: "TimeEntry adapter error: \(error.localizedDescription)")
        }
    }
}
