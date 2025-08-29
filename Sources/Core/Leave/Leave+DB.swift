import Fluent
import Vapor

/// DB functions for Leave: persistence and reconciliation
extension Leave {

	/// Upsert time-off requests; prune leaves not present remotely in the given window.
	/// - Parameters:
	///   - offs: Remote time-off requests
	///   - reasons: Remote reasons list for mapping IDs to names
	///   - workers: Map of Graph userId to persisted Worker
	///   - db: Database
	public static func upsert(
		from offs: [GraphTimeOff],
		reasons: [GraphTimeOffReason],
		workers: [Worker],
		prune: Bool = true,
		on db: Database
	) async throws {
		let reasonMap = Dictionary(uniqueKeysWithValues: reasons.map { ($0.id, $0.displayName) })
		let remoteIDs = Set(offs.map { $0.id })
		let workersMap = try Dictionary(uniqueKeysWithValues: workers.map { (try $0.requireID(), $0) })

		let allDBLeaves = try await Leave.query(on: db).all()
			.reduce(into: [:]) { partial, leave in
				partial[leave.graphID] = leave
			}

		var leavesToAdd: [Leave] = []
		for off in offs {
			guard let worker = workersMap[off.userId] else { continue }

			let reason = off.timeOffReasonId.flatMap { reasonMap[$0] } ?? "unknown"

			if let leave = allDBLeaves[off.id] {
				var needsSave = false
				if leave.startAt != off.startDate {
					leave.startAt = off.startDate
					needsSave = true
				}
				if leave.endAt != off.endDate {
					leave.endAt = off.endDate
					needsSave = true
				}
				if leave.type != reason {
					leave.type = reason
					needsSave = true
				}
				if needsSave { try await leave.save(on: db) }
			} else {
				let leave = Leave(workerID: try worker.requireID(), graphID: off.id, startAt: off.startDate, endAt: off.endDate, type: reason)
				leavesToAdd.append(leave)
			}
		}

		// Create new leaves
		try await leavesToAdd.create(on: db)

		guard prune else { return }

		// Prune leaves not present remotely
		try await allDBLeaves.values.filter { !remoteIDs.contains($0.graphID) }
			.delete(force: true, on: db)
	}

}
