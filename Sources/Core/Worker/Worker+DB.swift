import Fluent
import FluentSQL
import Vapor

/// DB functions for Worker: persistence and soft-delete logic
extension Worker {

	public static func prune(notIn ids: [UUID], on db: Database) async throws {
		try await Worker.query(on: db)
			.filter(\.$id !~ ids)
			.set(\.$archivedAt, to: Date())
			.update()
	}
}
