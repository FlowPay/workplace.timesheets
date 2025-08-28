import Fluent
import Vapor

/// DB functions for Break: helpers for persistence
extension Break {
    /// Creates and saves a break for a given time entry and worker.
    public static func dbCreate(for entry: TimeEntry, worker: Worker, start: Date, end: Date, on db: Database) async throws {
        let model = Break(timeEntryID: try entry.requireID(), workerID: try worker.requireID(), startAt: start, endAt: end)
        try await model.save(on: db)
    }
}
