import Core
import Fluent
import Vapor

/// Controller triggering synchronization of data from Microsoft Graph.
public struct SyncController: RouteCollection {
	/// Default initializer
	public init() {}

	/// Registers the `/sync` and `/sync/{teamId}` routes.
    public func boot(routes: RoutesBuilder) throws {
        routes.group("sync") { group in
            // Trigger sync for all Teams discovered via Microsoft Graph
            group.post(use: self.syncAll)
            // Trigger sync for a specific team id (manual debug route)
            group.post(":teamId", use: self.syncTeam)
            // Dedicated routes to upsert specific schedule entities
            group.group(":teamId", "schedule") { schedule in
                schedule.post("shifts", use: self.syncTeamShifts)
                schedule.post("timeCards", use: self.syncTeamTimeCards)
                schedule.post("timeOffRequests", use: self.syncTeamTimeOff)
            }
        }
    }

	/// Fetches users, shifts and time cards from Microsoft Graph for all discovered Teams.
	/// This endpoint auto-discovers Teams and triggers synchronization for each one.
	func syncAll(request: Request) async throws -> Response {
		struct Query: Content {
			let from: Date?
			let to: Date?
		}
		let q = try? request.query.decode(Query.self)
		let now = Date()
		let from = q?.from ?? Calendar.current.date(byAdding: .day, value: -30, to: now)!
		let to = q?.to ?? now

        do {
            let nameFilters = Configuration.shared.msGraphTeamNames
            request.logger.info("/sync invoked from=\(from) to=\(to) teamFilters=\(nameFilters)")
            let summary = try await GraphSyncJob.sync(
                env: request,
                filters: .init(
                    teamNameFilters: nameFilters,
                    from: from,
                    to: to
                )
            )

			return try encodeAccepted(summary, on: request)
		} catch {
			request.logger.report(error: error)
			throw error
		}
	}

    private func encodeAccepted<T: Content>(_ value: T, on req: Request) throws -> Response {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        let body = try JSONEncoder().encode(value)
        return Response(status: .accepted, headers: headers, body: .init(data: body))
    }

    /// Manually sync a specific team by id, focusing on timecards and shifts (no date filters)
    func syncTeam(request: Request) async throws -> Response {
        struct Output: Content {
            let teamId: UUID
            let shiftsCount: Int
            let timecardsCount: Int
            struct Upsert: Content { let updated: Int; let inserted: Int; let deleted: Int }
            let timeEntriesUpserted: Upsert
        }
        struct ErrorOut: Content { let teamId: String; let error: String }

        do {
            let teamId: UUID = try request.parameters.require("teamId")
            let users = try await request.graphClient.listUsers(client: request.client)
            let workers = try await Worker.dbUpsertAll(from: users, on: request.db)

            let graphShifts = try await request.graphClient.listShifts(teamId: teamId, from: nil, to: nil, top: 200, client: request.client)
            let _ = try await PlannedShift.upsert(from: graphShifts, workers: workers, prune: false, on: request.db)

            let graphTimeCards = try await request.graphClient.listTimeCards(teamId: teamId, from: nil, to: nil, top: 200, client: request.client)
            let timeEntryResults = try await TimeEntry.upsert(from: graphTimeCards, workers: workers, prune: false, on: request.db)

            let out = Output(teamId: teamId, shiftsCount: graphShifts.count, timecardsCount: graphTimeCards.count, timeEntriesUpserted: .init(updated: timeEntryResults.0, inserted: timeEntryResults.1, deleted: timeEntryResults.2))
            return try encodeAccepted(out, on: request)
        } catch {
            let err = ErrorOut(teamId: (try? request.parameters.require("teamId")) ?? "<missing>", error: String(reflecting: error))
            var headers = HTTPHeaders(); headers.add(name: .contentType, value: "application/json")
            let body = try JSONEncoder().encode(err)
            return Response(status: .internalServerError, headers: headers, body: .init(data: body))
        }
    }

    // MARK: Dedicated per-entity syncs (no date filters)
    func syncTeamShifts(request: Request) async throws -> Response {
        struct Output: Content { let teamId: UUID; let shiftsCount: Int; let upserted: PlannedShiftResponse }
        struct PlannedShiftResponse: Content { let updated: Int; let inserted: Int; let deleted: Int }
        struct Err: Content { let teamId: String; let error: String }

        do {
            let teamId: UUID = try request.parameters.require("teamId")
            let users = try await request.graphClient.listUsers(client: request.client)
            let workers = try await Worker.dbUpsertAll(from: users, on: request.db)
            let shifts = try await request.graphClient.listShifts(teamId: teamId, from: nil, to: nil, top: 200, client: request.client)
            let res = try await PlannedShift.upsert(from: shifts, workers: workers, prune: false, on: request.db)
            let out = Output(teamId: teamId, shiftsCount: shifts.count, upserted: .init(updated: res.0, inserted: res.1, deleted: res.2))
            return try encodeAccepted(out, on: request)
        } catch {
            var headers = HTTPHeaders(); headers.add(name: .contentType, value: "application/json")
            let body = try JSONEncoder().encode(Err(teamId: (try? request.parameters.require("teamId")) ?? "<missing>", error: String(reflecting: error)))
            return Response(status: .internalServerError, headers: headers, body: .init(data: body))
        }
    }

    func syncTeamTimeCards(request: Request) async throws -> Response {
        struct Output: Content { let teamId: UUID; let timecardsCount: Int; let upserted: TimeEntryResponse }
        struct TimeEntryResponse: Content { let updated: Int; let inserted: Int; let deleted: Int }
        struct Err: Content { let teamId: String; let error: String }

        do {
            let teamId: UUID = try request.parameters.require("teamId")
            let users = try await request.graphClient.listUsers(client: request.client)
            let workers = try await Worker.dbUpsertAll(from: users, on: request.db)
            let timecards = try await request.graphClient.listTimeCards(teamId: teamId, from: nil, to: nil, top: 200, client: request.client)
            let res = try await TimeEntry.upsert(from: timecards, workers: workers, prune: false, on: request.db)
            let out = Output(teamId: teamId, timecardsCount: timecards.count, upserted: .init(updated: res.0, inserted: res.1, deleted: res.2))
            return try encodeAccepted(out, on: request)
        } catch {
            var headers = HTTPHeaders(); headers.add(name: .contentType, value: "application/json")
            let body = try JSONEncoder().encode(Err(teamId: (try? request.parameters.require("teamId")) ?? "<missing>", error: String(reflecting: error)))
            return Response(status: .internalServerError, headers: headers, body: .init(data: body))
        }
    }

    func syncTeamTimeOff(request: Request) async throws -> Response {
        struct Output: Content { let teamId: UUID; let requestsCount: Int; let reasonsCount: Int }

        let teamId: UUID = try request.parameters.require("teamId")
        let users = try await request.graphClient.listUsers(client: request.client)
        let workers = try await Worker.dbUpsertAll(from: users, on: request.db)
        let reasons = try await request.graphClient.listTimeOffReasons(teamId: teamId, client: request.client)
        let requests = try await request.graphClient.listTimeOffRequests(teamId: teamId, from: nil, to: nil, top: 200, client: request.client)
        try await Leave.upsert(from: requests, reasons: reasons, workers: workers, prune: false, on: request.db)
        let out = Output(teamId: teamId, requestsCount: requests.count, reasonsCount: reasons.count)
        return try encodeAccepted(out, on: request)
    }
}
