import Fluent
import Vapor

/// DB functions for TimeEntry: persistence and reconciliation
extension TimeEntry {
	/// Upsert time cards as time entries and breaks; prune records not present remotely in the given window.
	/// - Parameters:
	///   - cards: Remote time cards from Microsoft Graph
	///   - workers: Map of Graph userId to persisted Worker
	///   - window: Optional date window used for pruning (by `date` field)
	///   - db: Database
    public static func upsert(
        from cards: [GraphTimeCard],
        workers: [Worker],
        prune: Bool = true,
        on db: Database
    ) async throws -> (Int, Int, Int) {
        let remoteIDs = Set(cards.map { $0.id })
        db.logger.info("TimeEntry.upsert cards=\(cards.count) workers=\(workers.count) prune=\(prune)")
        // Map workers by Graph user id (employeeKey holds Graph user id string)
        let workersByGraphId = Dictionary(uniqueKeysWithValues: workers.map { ($0.employeeKey.lowercased(), $0) })

		var updated = 0
		var inserted = 0
		var deleted = 0

        var allDBEntries = try await TimeEntry.query(on: db).with(\.$breaks).all()
            .reduce(into: [:]) { partial, entry in
                partial[entry.graphID] = entry
            }

        // Upsert entries and reconcile breaks
        var matched = 0
        for card in cards {
            let graphUserId = card.userId.uuidString.lowercased()
            var worker: Worker
            if let w = workersByGraphId[graphUserId] {
                worker = w
            } else {
                db.logger.debug("No worker match for userId=\(graphUserId); creating placeholder worker")
                let newWorker = Worker(employeeKey: graphUserId, fullName: graphUserId)
                try await newWorker.create(on: db)
                worker = newWorker
            }
            guard let end = card.clockOutEvent?.dateTime else {
                db.logger.debug("No clockOut for time card id=\(card.id), skipping")
                continue
            }
            matched += 1

			if let entry = allDBEntries[card.id] {
				/// Update fields if changed
				var needsSave = false

                if entry.date != card.clockInEvent.dateTime {
                    entry.date = card.clockInEvent.dateTime
                    needsSave = true
                }
                if entry.startAt != card.clockInEvent.dateTime {
                    entry.startAt = card.clockInEvent.dateTime
                    needsSave = true
                }
                if entry.endAt != end {
                    entry.endAt = end
                    needsSave = true
                }

				if needsSave {
					updated += 1
					try await entry.save(on: db)
				}

                // Reconcile breaks by Graph breakId when available; simpler and correct
                // Strategy: wipe existing breaks for the entry and re-create from remote
                try await entry.$breaks.query(on: db).delete()
                if let remoteBreaks = card.breaks {
                    try await remoteBreaks.map { b in
                        try Break(
                            timeEntryID: entry.requireID(),
                            workerID: worker.requireID(),
                            graphID: b.breakId,
                            startAt: b.start.dateTime,
                            endAt: b.end.dateTime
                        )
                    }.create(on: db)
                }

			} else {
				// Create new entry and breaks
                let entry = TimeEntry(
                    workerID: try worker.requireID(),
                    graphID: card.id,
                    date: card.clockInEvent.dateTime,
                    startAt: card.clockInEvent.dateTime,
                    endAt: end
                )
                try await entry.save(on: db)
                inserted += 1
                // Track newly created entry to avoid duplicate inserts on duplicate cards
                allDBEntries[card.id] = entry

                if let breaks = card.breaks {
                    try await breaks.map { b in
                        try Break(
                            timeEntryID: entry.requireID(),
                            workerID: worker.requireID(),
                            graphID: b.breakId,
                            startAt: b.start.dateTime,
                            endAt: b.end.dateTime
                        )
                    }.create(on: db)
                }
			}
        }

        db.logger.info("TimeEntry.upsert matched=\(matched) updated=\(updated) inserted=\(inserted) so far")

        // Prune entries not present remotely within the provided window
        guard prune else { return (updated, inserted, deleted) }

        let toDelete = allDBEntries.values.filter { !remoteIDs.contains($0.graphID) }
        deleted = toDelete.count

		for entry in toDelete {
			try await entry.$breaks.query(on: db).delete()
			try await entry.delete(on: db)
		}

        db.logger.info("TimeEntry.upsert completed updated=\(updated) inserted=\(inserted) deleted=\(deleted)")
        return (updated, inserted, deleted)
    }
}
