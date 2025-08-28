import Fluent
import Vapor

/// DB functions for TimeEntry: persistence and reconciliation
extension TimeEntry {
    /// Persist time cards as time entries and breaks; reconcile deletions within the window.
    public static func dbPersistAndReconcile(from cards: [GraphTimeCard],
                                          workers: [String: Worker],
                                          window: (from: Date?, to: Date?),
                                          on db: Database) async throws {
        // Create new entries and breaks
        for card in cards {
            guard let worker = workers[card.userId],
                  try await TimeEntry.query(on: db).filter(\.$graphID == card.id).first() == nil,
                  let end = card.clockOutDateTime else { continue }

            let entry = TimeEntry(workerID: try worker.requireID(), graphID: card.id, date: card.clockInDateTime, startAt: card.clockInDateTime, endAt: end)
            try await entry.save(on: db)

            for brk in card.breaks ?? [] {
                try await Break.dbCreate(for: entry, worker: worker, start: brk.startDateTime, end: brk.endDateTime, on: db)
            }
        }

        // Reconcile deletions only if both bounds are present
        if let from = window.from, let to = window.to {
            let existingEntries = try await TimeEntry.query(on: db)
                .filter(\.$date >= from)
                .filter(\.$date <= to)
                .all()
            let remoteIDs = Set(cards.map { $0.id })
            for entry in existingEntries where !remoteIDs.contains(entry.graphID) {
                try await entry.$breaks.query(on: db).delete()
                try await entry.delete(on: db)
            }
        }
    }
}
