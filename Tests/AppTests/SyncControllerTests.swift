import XCTVapor
@testable import App
@testable import Core

/// Tests covering `/sync/{teamId}` endpoint persistence logic.
final class SyncControllerTests: BaseTestCase {
    /// Ensures users, time entries, breaks and leaves are stored.
    func testSyncPersistsEntities() async throws {
        struct MockGraph: MicrosoftGraphClientProtocol {
            func listTeams(client: Client) async throws -> [GraphTeam] { [] }
            func listUsers(client: Client) async throws -> [GraphUser] {
                [GraphUser(id: "u1", displayName: "Alice")]
            }
            func listShifts(teamId: String, client: Client) async throws -> [GraphShift] { [] }
            func listTimeCards(teamId: String, client: Client) async throws -> [GraphTimeCard] {
                [GraphTimeCard(id: "c1", userId: "u1", clockInDateTime: Date(), clockOutDateTime: Date().addingTimeInterval(3600), breaks: [GraphTimeCard.TimeCardBreak(startDateTime: Date().addingTimeInterval(600), endDateTime: Date().addingTimeInterval(900))])]
            }
            func listTimeOffRequests(teamId: String, client: Client) async throws -> [GraphTimeOff] {
                [GraphTimeOff(id: "o1", userId: "u1", startDateTime: Date(), endDateTime: Date().addingTimeInterval(1800), timeOffReasonId: "r1")]
            }
            func listTimeOffReasons(teamId: String, client: Client) async throws -> [GraphTimeOffReason] {
                [GraphTimeOffReason(id: "r1", displayName: "Vacation")]
            }
        }

        app.graphClient = MockGraph()

        let service = GraphSyncService()
        try await service.sync(teamId: "team1", app: app)

        let workers = try await Worker.query(on: app.db).all()
        XCTAssertEqual(workers.count, 1)

        let entries = try await TimeEntry.query(on: app.db).with(\.$breaks).all()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.breaks.count, 1)

        let leaves = try await Leave.query(on: app.db).all()
        XCTAssertEqual(leaves.count, 1)
        XCTAssertEqual(leaves.first?.type, "Vacation")
    }
}
