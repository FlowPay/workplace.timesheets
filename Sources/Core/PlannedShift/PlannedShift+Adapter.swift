import Vapor

/// Adapter functions for PlannedShift: communication with Microsoft Graph (shifts)
extension PlannedShift {
	/// Fetch planned shifts for a team within an optional time window.
	// public static func adapterFetchShifts(teamId: String, from: Date?, to: Date?, graph: MicrosoftGraphClientProtocol, client: Client) async throws -> [GraphShift] {
	//     do {
	//         return try await graph.listShifts(teamId: teamId, from: from, to: to, client: client)
	//     } catch {
	//         throw Abort(.internalServerError, reason: "PlannedShift adapter error: \(error.localizedDescription)")
	//     }
	// }
}
