import Core
import Fluent
import Vapor

/// Controller exposing CRUD operations for workers
public struct WorkerController: RouteCollection {
	/// Default initializer
	public init() {}

	/// Register routes on the provided routes builder
	public func boot(routes: RoutesBuilder) throws {
		routes.group("workers") { workers in
		}
	}

}
