import Fluent
import Queues
import Vapor

/// Scheduled job periodically synchronizing data from Microsoft Graph.
public struct GraphSyncJob: AsyncScheduledJob {
	/// Default initializer
	public init() {}

	/// Runs the synchronization job for all configured team identifiers.
	public func run(context: QueueContext) async throws {
		let app = context.application
		let now = Date()
		let from = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 24 * 3600)
		_ = try await Self.sync(
			env: app,
			filters: .init(
				teamNameFilters: [],
				from: from,
				to: now
			)
		)
	}
}
