import Fluent
import Vapor

/// DB functions for Worker: persistence and soft-delete logic
extension Worker {
	/// Upserts workers from Graph users. If `allowedUserIDs` is non-empty, any user not in the set
	/// is kept but marked as archived (deletedAt) if not already set.
	/// Returns a lookup map by employeeKey for downstream relations.
	@discardableResult
	public static func dbUpsertAll(from users: [GraphUser], on db: Database) async throws -> [Worker] {

		var usersMap: [String: GraphUser] = users.reduce(into: [:]) { partialResult, user in
			partialResult[user.id] = user
		}

		let allDBWorkers = try await Worker.query(on: db).all()

		for worker in allDBWorkers {

			if let user = usersMap[worker.employeeKey] {
				// Existing worker, update name if changed
            if worker.fullName != (user.displayName ?? worker.fullName) {
                worker.fullName = user.displayName ?? worker.fullName
            }
            if worker.email != user.mail { worker.email = user.mail }

            // Archive or unarchive based on current user activity
            if user.isActive {
                // Ensure active users are not archived
                if worker.archivedAt != nil { worker.archivedAt = nil }
            } else {
                // Inactive users should be archived
                if worker.archivedAt == nil { worker.archivedAt = Date() }
            }

				usersMap.removeValue(forKey: worker.employeeKey)
			} else {
				// Worker not in current users, archive if needed
				worker.archivedAt = worker.archivedAt ?? Date()
			}

			try await worker.save(on: db)
		}

        let newWorkers: [Worker] = usersMap.values.compactMap { user in
            guard user.isActive else { return nil }
            return Worker(employeeKey: user.id, fullName: user.displayName ?? "", email: user.mail)
        }

		try await newWorkers.create(on: db)

		let allActive = allDBWorkers.filter { $0.archivedAt == nil } + newWorkers
		return allActive
	}
}
