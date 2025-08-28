import Fluent
import Vapor

/// DB functions for Leave: persistence and reconciliation
extension Leave {
    /// Persist time-off requests; reconcile deletions within the window.
    public static func dbPersistAndReconcile(from offs: [GraphTimeOff],
                                      reasons: [GraphTimeOffReason],
                                      workers: [String: Worker],
                                      window: (from: Date?, to: Date?),
                                      on db: Database) async throws {
        let reasonMap = Dictionary(uniqueKeysWithValues: reasons.map { ($0.id, $0.displayName) })

        for off in offs {
            guard let worker = workers[off.userId],
                  try await Leave.query(on: db).filter(\.$graphID == off.id).first() == nil else { continue }
            let reason = reasonMap[off.timeOffReasonId] ?? "unknown"
            let leave = Leave(workerID: try worker.requireID(), graphID: off.id, startAt: off.startDateTime, endAt: off.endDateTime, type: reason)
            try await leave.save(on: db)
        }

        // Reconcile deletions if both bounds present
        if let from = window.from, let to = window.to {
            let existingLeaves = try await Leave.query(on: db)
                .group(.and) { g in
                    g.filter(\.$startAt <= to)
                    g.filter(\.$endAt >= from)
                }
                .all()
            let remoteIDs = Set(offs.map { $0.id })
            for leave in existingLeaves where !remoteIDs.contains(leave.graphID) {
                try await leave.delete(on: db)
            }
        }
    }
}
