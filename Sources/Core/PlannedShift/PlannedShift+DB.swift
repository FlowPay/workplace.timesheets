import Fluent
import Vapor

/// DB functions for PlannedShift: persistence and reconciliation
extension PlannedShift {

	/// Upsert planned shifts and their breaks; prune shifts not present remotely in the given window.
	/// - Parameters:
	///   - shifts: Remote shifts from Microsoft Graph
	///   - workers: Map of Graph userId to persisted Worker
	///   - window: Optional date window used for pruning (by `date` field)
	///   - db: Database
	public static func upsert(
		from shifts: [GraphShift],
		workers: [Worker],
		prune: Bool = true,
		on db: Database
	) async throws -> (Int, Int, Int) {
		let remoteIDs = Set(shifts.map { $0.id })
		let workersMap = try Dictionary(uniqueKeysWithValues: workers.map { (try $0.requireID(), $0) })
		let allDBShifts = try await PlannedShift.query(on: db).with(\.$breaks).all()
			.reduce(into: [:]) { partial, shift in
				partial[shift.graphID] = shift
			}

		var updated: Int = 0
		var inserted: Int = 0
		var deleted: Int = 0

		for shift in shifts {

			guard
				let sharedShift = shift.sharedShift,
				let userId = shift.userId
			else { continue }

			let start = sharedShift.startDateTime
			let end = sharedShift.endDateTime

			guard let worker = workersMap[userId] else { continue }

			guard let planned = allDBShifts[shift.id] else {

				// Create new planned shift
				let planned = PlannedShift(
					workerID: try worker.requireID(),
					graphID: shift.id,
					date: start,
					startAt: start,
					endAt: end
				)
				try await planned.create(on: db)
				inserted += 1

				// Create breaks for the new planned shift
				try await sharedShift.activities?.compactMap { activity -> PlannedBreak? in
					guard !activity.isPaid else { return nil }

					return try PlannedBreak(
						plannedShiftID: planned.requireID(),
						workerID: try worker.requireID(),
						start: activity.startDateTime,
						end: activity.endDateTime
					)
				}
				.create(on: db)

				continue
			}

			var needsSave = false
			if planned.date != start {
				planned.date = start
				needsSave = true
			}
			if planned.startAt != start {
				planned.startAt = start
				needsSave = true
			}
			if planned.endAt != end {
				planned.endAt = end
				needsSave = true
			}

			if needsSave {
				try await planned.save(on: db)
				updated += 1
			}

			//TODO: Optimize this chaos
			// Reconcile breaks (now leveraging Hashable/Equatable)
			let remoteBreaks: Set<GraphShift.Activity> = Set(sharedShift.activities ?? [])

			let currentBreaks = try await planned.$breaks.query(on: db).all()
			let currentSet: Set<GraphShift.Activity> = Set(currentBreaks.map { GraphShift.Activity(startDate: $0.startAt, endDate: $0.endAt, isPaid: false) })

			// Delete breaks that no longer exist remotely
			for br in currentBreaks where !remoteBreaks.contains(GraphShift.Activity(startDate: br.startAt, endDate: br.endAt, isPaid: false)) {
				try await br.delete(on: db)
			}

			// Create breaks that are present remotely but missing locally
			try await currentSet.filter { !remoteBreaks.contains($0) }
				.compactMap { remoteBreak -> PlannedBreak? in
					guard !remoteBreak.isPaid else { return nil }

					return try PlannedBreak(
						plannedShiftID: planned.requireID(),
						workerID: worker.requireID(),
						start: remoteBreak.startDateTime,
						end: remoteBreak.endDateTime
					)
				}
				.create(on: db)

		}

		// Prune shifts not present remotely within the provided window
		guard prune else { return (updated, inserted, deleted) }

		let toDelete = allDBShifts.values.filter { !remoteIDs.contains($0.graphID) }
		deleted = toDelete.count

		for ps in toDelete {
			try await ps.$breaks.query(on: db).delete()
			try await ps.delete(on: db)
		}

		return (updated, inserted, deleted)
	}
}

extension GraphShift.Activity: Hashable, Equatable {
	public static func == (lhs: GraphShift.Activity, rhs: GraphShift.Activity) -> Bool {
		lhs.startDateTime == rhs.startDateTime && lhs.endDateTime == rhs.endDateTime
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(startDateTime)
		hasher.combine(endDateTime)
	}
}
