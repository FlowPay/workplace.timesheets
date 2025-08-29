import XCTVapor

@testable import App
@testable import Core

/// Tests covering `/sync/{teamId}` endpoint persistence logic.
final class SyncControllerTests: BaseTestCase {
	/// Ensures users, time entries, breaks and leaves are stored.
	func testSyncPersistsEntities() async throws {
		struct MockGraph: MicrosoftGraphClientProtocol {
			func listTeams(client: Client) async throws -> [GraphTeam] { [] }
			func listGroupsByNames(_ names: [String], client: Client) async throws -> [GraphGroup] { [] }
			func listGroupMembers(groupId: String, client: Client) async throws -> [GraphUser] { [] }
			func listUsers(client: Client) async throws -> [GraphUser] {
				[GraphUser(id: "u1", displayName: "Alice")]
			}
			func listShifts(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphShift] { [] }
			func listTimeCards(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeCard] {
				let iso = ISO8601DateFormatter()
				iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
				let cin = GraphDateTimeTimeZone(dateTime: iso.string(from: Date()), timeZone: nil)
				let cout = GraphDateTimeTimeZone(dateTime: iso.string(from: Date().addingTimeInterval(3600)), timeZone: nil)
				let bstart = GraphDateTimeTimeZone(dateTime: iso.string(from: Date().addingTimeInterval(600)), timeZone: nil)
				let bend = GraphDateTimeTimeZone(dateTime: iso.string(from: Date().addingTimeInterval(900)), timeZone: nil)
				return [GraphTimeCard(id: "c1", userId: "u1", clockInEvent: cin, clockOutEvent: cout, breaks: [GraphTimeCard.Break(start: bstart, end: bend)])]
			}
			func listTimeOffRequests(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeOff] {
				let iso = ISO8601DateFormatter()
				iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
				return [
					GraphTimeOff(
						id: "o1",
						userId: "u1",
						startDateTime: GraphDateTimeTimeZone(dateTime: iso.string(from: Date()), timeZone: nil),
						endDateTime: GraphDateTimeTimeZone(dateTime: iso.string(from: Date().addingTimeInterval(1800)), timeZone: nil),
						timeOffReasonId: "r1"
					)
				]
			}
			func listTimeOffReasons(teamId: String, client: Client) async throws -> [GraphTimeOffReason] {
				[GraphTimeOffReason(id: "r1", displayName: "Vacation")]
			}
		}

		app.graphClient = MockGraph()

		try app.test(.POST, "/sync/team1") { res in
			XCTAssertEqual(res.status, .accepted)
		}

		let workers = try await Worker.query(on: app.db).all()
		XCTAssertEqual(workers.count, 1)

		let entries = try await TimeEntry.query(on: app.db).with(\.$breaks).all()
		XCTAssertEqual(entries.count, 1)
		XCTAssertEqual(entries.first?.breaks.count, 1)

		let leaves = try await Leave.query(on: app.db).all()
		XCTAssertEqual(leaves.count, 1)
		XCTAssertEqual(leaves.first?.type, "Vacation")
	}

	/// Ensures the /sync endpoint (without teamId) discovers teams and triggers sync for each.
	func testSyncAllPersistsForMultipleTeams() async throws {
		struct MockGraph: MicrosoftGraphClientProtocol {
			func listTeams(client: Client) async throws -> [GraphTeam] {
				[GraphTeam(id: "t1", displayName: "Team 1"), GraphTeam(id: "t2", displayName: "Team 2")]
			}
			func listGroupsByNames(_ names: [String], client: Client) async throws -> [GraphGroup] { [] }
			func listGroupMembers(groupId: String, client: Client) async throws -> [GraphUser] { [] }
			func listUsers(client: Client) async throws -> [GraphUser] {
				[GraphUser(id: "u1", displayName: "Alice")]
			}
			func listShifts(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphShift] { [] }
			func listTimeCards(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeCard] {
				let iso = ISO8601DateFormatter()
				iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
				let cin = GraphDateTimeTimeZone(dateTime: iso.string(from: Date()), timeZone: nil)
				let cout = GraphDateTimeTimeZone(dateTime: iso.string(from: Date().addingTimeInterval(3600)), timeZone: nil)
				return [GraphTimeCard(id: "c1-\(teamId)", userId: "u1", clockInEvent: cin, clockOutEvent: cout, breaks: [])]
			}
			func listTimeOffRequests(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeOff] {
				let iso = ISO8601DateFormatter()
				iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
				return [
					GraphTimeOff(
						id: "o1-\(teamId)",
						userId: "u1",
						startDateTime: GraphDateTimeTimeZone(dateTime: iso.string(from: Date()), timeZone: nil),
						endDateTime: GraphDateTimeTimeZone(dateTime: iso.string(from: Date().addingTimeInterval(1800)), timeZone: nil),
						timeOffReasonId: "r1"
					)
				]
			}
			func listTimeOffReasons(teamId: String, client: Client) async throws -> [GraphTimeOffReason] {
				[GraphTimeOffReason(id: "r1", displayName: "Vacation")]
			}
		}

		app.graphClient = MockGraph()

		try app.test(.POST, "/sync") { res in
			XCTAssertEqual(res.status, .accepted)
		}

		let workers = try await Worker.query(on: app.db).all()
		XCTAssertEqual(workers.count, 1)

		let entries = try await TimeEntry.query(on: app.db).all()
		XCTAssertEqual(entries.count, 2)

		let leaves = try await Leave.query(on: app.db).all()
		XCTAssertEqual(leaves.count, 2)
	}
}
