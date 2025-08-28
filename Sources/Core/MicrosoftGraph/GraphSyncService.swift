import Vapor
import Fluent

/// Service responsible for synchronizing data from Microsoft Graph
/// and persisting it into local models.
public struct GraphSyncService {
    /// Default initializer
    public init() {}

    /// Performs synchronization for the provided team identifier.
    /// - Parameters:
    ///   - teamId: Identifier of the team to synchronize.
    ///   - app: Application providing database and HTTP clients.
    public func sync(teamId: String, app: Application) async throws {
        let graph = app.graphClient
        let client = app.client
        let db = app.db

        // Fetch users and upsert workers
        let users = try await graph.listUsers(client: client)
        for user in users {
            let existing = try await Worker.query(on: db)
                .filter(\.$employeeKey == user.id)
                .first()
            if let existing {
                // Update name if changed
                existing.fullName = user.displayName ?? existing.fullName
                try await existing.save(on: db)
            } else {
                let worker = Worker(employeeKey: user.id, fullName: user.displayName ?? "")
                try await worker.save(on: db)
            }
        }

        // Map workers for quick lookup
        let workers = try await Worker.query(on: db).all().reduce(into: [String: Worker]()) { dict, worker in
            dict[worker.employeeKey] = worker
        }

        // Fetch time cards and persist time entries with breaks
        let timeCards = try await graph.listTimeCards(teamId: teamId, client: client)
        for card in timeCards {
            guard let worker = workers[card.userId],
                  try await TimeEntry.query(on: db).filter(\.$graphID == card.id).first() == nil,
                  let end = card.clockOutDateTime else { continue }

            let entry = TimeEntry(workerID: try worker.requireID(), graphID: card.id, date: card.clockInDateTime, startAt: card.clockInDateTime, endAt: end)
            try await entry.save(on: db)

            for brk in card.breaks ?? [] {
                let breakModel = Break(timeEntryID: try entry.requireID(), workerID: try worker.requireID(), startAt: brk.startDateTime, endAt: brk.endDateTime)
                try await breakModel.save(on: db)
            }
        }

        // Fetch time-off reasons and build lookup
        let reasons = try await graph.listTimeOffReasons(teamId: teamId, client: client)
        let reasonMap = Dictionary(uniqueKeysWithValues: reasons.map { ($0.id, $0.displayName) })

        // Fetch time-off requests and persist leaves
        let timeOffs = try await graph.listTimeOffRequests(teamId: teamId, client: client)
        for off in timeOffs {
            guard let worker = workers[off.userId],
                  try await Leave.query(on: db).filter(\.$graphID == off.id).first() == nil else { continue }
            let reason = reasonMap[off.timeOffReasonId] ?? "unknown"
            let leave = Leave(workerID: try worker.requireID(), graphID: off.id, startAt: off.startDateTime, endAt: off.endDateTime, type: reason)
            try await leave.save(on: db)
        }
    }
}
