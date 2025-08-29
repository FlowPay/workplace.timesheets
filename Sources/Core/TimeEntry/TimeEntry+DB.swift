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
		let workerMap = try Dictionary(uniqueKeysWithValues: workers.map { (try $0.requireID(), $0) })

		var updated = 0
		var inserted = 0
		var deleted = 0

		let allDBEntries = try await TimeEntry.query(on: db).with(\.$breaks).all()
			.reduce(into: [:]) { partial, entry in
				partial[entry.graphID] = entry
			}

		// Upsert entries and reconcile breaks
		for card in cards {
			guard let worker = workerMap[card.userId], let end = card.clockOutDate else { continue }

			if let entry = allDBEntries[card.id] {
				/// Update fields if changed
				var needsSave = false

				if entry.date != card.clockInDate {
					entry.date = card.clockInDate
					needsSave = true
				}
				if entry.startAt != card.clockInDate {
					entry.startAt = card.clockInDate
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

				// TODO: Optimize break reconciliation
				// Reconcile breaks for this entry
				let remoteBreaks = Set(card.breaks ?? [])
				let currentBreaks = entry.breaks
				let currentSet = Set(entry.breaks.map { GraphTimeCard.Break(start: $0.startAt, end: $0.endAt) })

				// Delete outdated breaks
				for breakk in currentBreaks where !remoteBreaks.contains(GraphTimeCard.Break(start: breakk.startAt, end: breakk.endAt)) {
					try await breakk.delete(on: db)
				}

				// Create new breaks
				for timeCardBreak in (card.breaks ?? []) {
					let bKey = GraphTimeCard.Break(start: timeCardBreak.start.date, end: timeCardBreak.end.date)
					if !currentSet.contains(bKey) {
						try await Break(timeEntryID: try entry.requireID(), workerID: try worker.requireID(), startAt: timeCardBreak.start.date, endAt: timeCardBreak.end.date)
							.create(on: db)
					}
				}

			} else {
				// Create new entry and breaks
				let entry = TimeEntry(workerID: try worker.requireID(), graphID: card.id, date: card.clockInDate, startAt: card.clockInDate, endAt: end)
				try await entry.save(on: db)
				inserted += 1

				try await card.breaks?.map { timeCardBreak in
					try Break(timeEntryID: entry.requireID(), workerID: worker.requireID(), startAt: timeCardBreak.start.date, endAt: timeCardBreak.end.date)
				}
				.create(on: db)
			}
		}

		// Prune entries not present remotely within the provided window
		guard prune else { return (updated, inserted, deleted) }

		let toDelete = allDBEntries.values.filter { !remoteIDs.contains($0.graphID) }
		deleted = toDelete.count

		for entry in toDelete {
			try await entry.$breaks.query(on: db).delete()
			try await entry.delete(on: db)
		}

		return (updated, inserted, deleted)
	}
}
