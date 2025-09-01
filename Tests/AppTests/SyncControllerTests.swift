import XCTVapor

@testable import App
@testable import Core

/// Tests covering `/sync/{teamId}` endpoint persistence logic.
final class SyncControllerTests: BaseTestCase {
	/// Ensures users, time entries, breaks and leaves are stored.
	func testSyncPersistsEntities() async throws {
		struct MockGraph: MicrosoftGraphClientProtocol {
			func listTeams(client: Client) async throws -> [GraphTeam] {
				[GraphTeam(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000f1")!, displayName: "Dipendenti FlowPay")]
			}
			func listMembers(groupId: UUID, client: Client) async throws -> [GraphUser] { [] }
			func listUsers(client: Client) async throws -> [GraphUser] {
				[GraphUser(id: "00000000-0000-0000-0000-000000000001", displayName: "Alice", mail: nil, accountEnabled: true, userType: .member)]
			}
			func listShifts(teamId: UUID, from: Date?, to: Date?, client: Client) async throws -> [GraphShift] { [] }
			func listTimeCards(teamId: UUID, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeCard] {
				let user = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
				let now = Date()
				let cin = GraphTimeCard.DatetimeEvent(dateTime: now, isAtApprovedLocation: false, notes: nil)
				let cout = GraphTimeCard.DatetimeEvent(dateTime: now.addingTimeInterval(3600), isAtApprovedLocation: false, notes: nil)
				let bstart = GraphTimeCard.DatetimeEvent(dateTime: now.addingTimeInterval(600), isAtApprovedLocation: false, notes: nil)
				let bend = GraphTimeCard.DatetimeEvent(dateTime: now.addingTimeInterval(900), isAtApprovedLocation: false, notes: nil)
				return [
					GraphTimeCard(
						id: "c1",
						userId: user,
						clockInEvent: cin,
						clockOutEvent: cout,
						breaks: [GraphTimeCard.Break(breakId: "b1", start: bstart, end: bend)],
						notes: nil
					)
				]
			}
			func listTimeOffRequests(teamId: UUID, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeOff] {
				let user = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
				let now = Date()
				return [
					GraphTimeOff(
						id: "o1",
						userId: user,
						startDateTime: GraphDateTimeTimeZone(dateTime: now, timeZone: nil),
						endDateTime: GraphDateTimeTimeZone(dateTime: now.addingTimeInterval(1800), timeZone: nil),
						timeOffReasonId: "r1"
					)
				]
			}
			func listTimeOffReasons(teamId: UUID, client: Client) async throws -> [GraphTimeOffReason] {
				[GraphTimeOffReason(id: "r1", displayName: "Vacation")]
			}
		}

		app.graphClient = MockGraph()

		try app.test(.POST, "/sync") { res in
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
				[
					GraphTeam(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!, displayName: "Dipendenti FlowPay - Team 1"),
					GraphTeam(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000a2")!, displayName: "Dipendenti FlowPay - Team 2"),
				]
			}
			func listMembers(groupId: UUID, client: Client) async throws -> [GraphUser] { [] }
			func listUsers(client: Client) async throws -> [GraphUser] {
				[GraphUser(id: "00000000-0000-0000-0000-000000000001", displayName: "Alice", mail: nil, accountEnabled: true, userType: .member)]
			}
			func listShifts(teamId: UUID, from: Date?, to: Date?, client: Client) async throws -> [GraphShift] { [] }
			func listTimeCards(teamId: UUID, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeCard] {
				let user = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
				let now = Date()
				let cin = GraphTimeCard.DatetimeEvent(dateTime: now, isAtApprovedLocation: false, notes: nil)
				let cout = GraphTimeCard.DatetimeEvent(dateTime: now.addingTimeInterval(3600), isAtApprovedLocation: false, notes: nil)
				return [GraphTimeCard(id: "c1-\(teamId)", userId: user, clockInEvent: cin, clockOutEvent: cout, breaks: [], notes: nil)]
			}
			func listTimeOffRequests(teamId: UUID, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeOff] {
				let user = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
				let now = Date()
				return [
					GraphTimeOff(
						id: "o1-\(teamId)",
						userId: user,
						startDateTime: GraphDateTimeTimeZone(dateTime: now, timeZone: nil),
						endDateTime: GraphDateTimeTimeZone(dateTime: now.addingTimeInterval(1800), timeZone: nil),
						timeOffReasonId: "r1"
					)
				]
			}
			func listTimeOffReasons(teamId: UUID, client: Client) async throws -> [GraphTimeOffReason] {
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
