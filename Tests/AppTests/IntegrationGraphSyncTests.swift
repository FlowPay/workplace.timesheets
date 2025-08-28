import XCTVapor

@testable import App
@testable import Core

/// Optional integration tests hitting real Microsoft Graph APIs.
/// Enabled only when INTEGRATION_MS_GRAPH=1 and credentials are provided.
final class IntegrationGraphSyncTests: BaseTestCase {
	/// Smoke test: list teams and perform a 1-day sync for the first team.
	func testRealGraphSyncIfEnabled() async throws {
		if let flag = getenv("INTEGRATION_MS_GRAPH") {
			if String(cString: flag) != "1" { throw XCTSkip("INTEGRATION_MS_GRAPH not enabled") }
		} else {
			throw XCTSkip("INTEGRATION_MS_GRAPH not enabled")
		}
		// Ensure graph client is configured from env in configure(app)
		guard (try? await app.graphClient.listUsers(client: app.client)) != nil else {
			throw XCTSkip("Microsoft Graph not configured")
		}
		let teams = try await app.graphClient.listTeams(client: app.client)
		guard let team = teams.first else { throw XCTSkip("No teams available") }
		let now = ISO8601DateFormatter().string(from: Date())
		let from = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
		try app.test(.POST, "/sync/\(team.id)?from=\(from)&to=\(now)") { res in
			XCTAssertEqual(res.status, .accepted)
		}
	}
}
