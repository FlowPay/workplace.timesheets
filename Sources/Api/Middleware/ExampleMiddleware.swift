import Core
import Vapor

/// Simple example middleware used during tests
struct ExampleMiddleware: AsyncMiddleware {

	/// Middleware entry point
	/// - Parameters:
	///   - request: Incoming request
	///   - next: Next responder in the chain
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		request.logger.debug("ExampleMiddleware hit")
		return try await next.respond(to: request)
	}

}
