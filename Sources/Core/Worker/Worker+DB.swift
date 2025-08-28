import Fluent
import Vapor

/// DB functions for Worker: persistence and soft-delete logic
extension Worker {
    /// Upserts workers from Graph users. If `allowedUserIDs` is non-empty, any user not in the set
    /// is kept but marked as archived (deletedAt) if not already set.
    /// Returns a lookup map by employeeKey for downstream relations.
    public static func dbUpsertAll(from users: [GraphUser], allowedUserIDs: Set<String>, on db: Database) async throws -> [String: Worker] {
        var map: [String: Worker] = [:]
        for user in users {
            let existing = try await Worker.query(on: db)
                .filter(\.$employeeKey == user.id)
                .first()
            if let existing {
                existing.fullName = user.displayName ?? existing.fullName
                if !allowedUserIDs.isEmpty && !allowedUserIDs.contains(user.id) && existing.archivedAt == nil {
                    existing.archivedAt = Date()
                }
                try await existing.save(on: db)
                map[user.id] = existing
            } else {
                let worker = Worker(employeeKey: user.id, fullName: user.displayName ?? "")
                if !allowedUserIDs.isEmpty && !allowedUserIDs.contains(user.id) {
                    worker.archivedAt = Date()
                }
                try await worker.save(on: db)
                map[user.id] = worker
            }
        }
        return map
    }
}
