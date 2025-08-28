import Core
import Fluent
import Vapor

/// Controller exposing read operations for time entries.
public struct TimesheetController: RouteCollection {
	/// Default initializer
	public init() {}

	/// Register routes
	public func boot(routes: RoutesBuilder) throws {
		routes.group("workers") { workers in
			workers.group(":id", "time-entries") { group in
				group.get(use: self.list)
			}
		}
	}

	/// Lists time entries for a worker with optional date filtering.
	func list(request: Request) async throws -> Response {
		let workerID: UUID = try request.parameters.require("id")
		let from = try? request.query.get(Date.self, at: "from")
		let to = try? request.query.get(Date.self, at: "to")

		var query = TimeEntry.query(on: request.db).filter(\.$worker.$id == workerID)
		if let from { query = query.filter(\.$date >= from) }
		if let to { query = query.filter(\.$date <= to) }

		let entries = try await query.with(\.$breaks).all()
		let outputs = try entries.map { try TimeEntry.Output($0) }
		return try await outputs.encodeResponse(for: request)
	}
}
