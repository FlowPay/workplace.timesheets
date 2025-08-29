import Core
import Fluent
import Vapor

/// Controller triggering synchronization of data from Microsoft Graph.
public struct SyncController: RouteCollection {
	/// Default initializer
	public init() {}

	/// Registers the `/sync` and `/sync/{teamId}` routes.
	public func boot(routes: RoutesBuilder) throws {
		routes.group("sync") { group in
			// Trigger sync for all Teams discovered via Microsoft Graph
			group.post(use: self.syncAll)
		}
	}

	/// Fetches users, shifts and time cards from Microsoft Graph for all discovered Teams.
	/// This endpoint auto-discovers Teams and triggers synchronization for each one.
	func syncAll(request: Request) async throws -> Response {
		struct Query: Content {
			let from: Date?
			let to: Date?
		}
		let q = try? request.query.decode(Query.self)
		let now = Date()
		let from = q?.from ?? Calendar.current.date(byAdding: .day, value: -30, to: now)!
		let to = q?.to ?? now

		do {
			let summary = try await GraphSyncJob.sync(
				env: request,
				filters: .init(
					teamNameFilters: ["Dipendenti FlowPay"],
					from: from,
					to: to
				)
			)

			return try encodeAccepted(summary, on: request)
		} catch {
			request.logger.report(error: error)
			throw error
		}
	}

	private func encodeAccepted<T: Content>(_ value: T, on req: Request) throws -> Response {
		var headers = HTTPHeaders()
		headers.add(name: .contentType, value: "application/json")
		let body = try JSONEncoder().encode(value)
		return Response(status: .accepted, headers: headers, body: .init(data: body))
	}

}
