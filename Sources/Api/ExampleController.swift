import Core
import FlowpayUtilities
import Foundation
import Vapor

/// Example routes controller
public struct ExampleController: RouteCollection {

	/// Default initializer
	public init() {}

	/// Register routes for this controller
	/// - Parameter routes: The route builder to attach endpoints to.
	public func boot(routes: RoutesBuilder) throws {
		let api = routes.grouped(ExampleMiddleware())

		api.group("examples") { examples in
			examples.get(use: self.list)
			examples.post(use: self.create)

			examples.group(":identifier") { example in
				example.get(use: self.details)
				example.put(use: self.edit)
				example.delete(use: self.delete)
			}
		}

		api.get("examples", use: self.list)
		api.post("examples", use: self.create)

	}

	/// Create a new example entity
	/// - Parameter request: Incoming request
	/// - Returns: The created entity as a response
	func create(request: Request) async throws -> Response {
		request.logger.debug("create example entity")

		let db = request.transactionalDB
		let content = try request.content.decode(ExampleEntity.Input.self)

		let example = ExampleEntity(
			stringExample: content.stringExample,
			optionalIntegerExample: content.optionalIntegerExample,
			enumExample: content.enumExample
		)

		let result = try ExampleEntity.Output(exampleEntity: example)

		let response = Response(status: .created)
		try response.content.encode(result, as: .json)
		return response
	}

	/// Retrieve all example entities
	/// - Parameter request: Incoming request
	func list(request: Request) async throws -> Response {
		request.logger.debug("list all example entity")

		let db = request.db
		let examples = try await ExampleEntity.list(from: db)

		let result = try examples.compactMap { try ExampleEntity.Output(exampleEntity: $0) }

		return try await result.encodeResponse(status: .created, for: request)
	}

	/// Retrieve a single example entity
	/// - Parameter request: Incoming request
	func details(request: Request) async throws -> Response {
		let id: UUID = try request.parameters.require("identifier")

		let db = request.transactionalDB
		guard let example = try await ExampleEntity.find(id, on: db) else {
			throw Abort(.notFound, reason: "Example entity with id \(id) not found")
		}

		let result = try ExampleEntity.Output(exampleEntity: example)
		return try await result.encodeResponse(for: request)
	}

	/// Edit an example entity - not implemented in template
	func edit(request: Request) async throws -> Response {
		throw Abort(.notImplemented, reason: "This repository is just a template ✌️")
	}

	/// Delete an example entity - not implemented in template
	func delete(request: Request) async throws -> Response {
		throw Abort(.notImplemented, reason: "This repository is just a template ✌️")
	}

}
