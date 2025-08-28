import Core
import Fluent
import Job
import Queues
import Vapor

/// Controller handling timesheet import operations
public struct ImportController: RouteCollection {
	/// Default initializer
	public init() {}

	/// Register routes
	public func boot(routes: RoutesBuilder) throws {
		routes.group("imports") { imports in
			imports.post("timesheet", use: self.upload)
			imports.get(":batchId", use: self.detail)
		}
	}

	/// Uploads a timesheet file and enqueues processing
	func upload(request: Request) async throws -> Response {
                let input = try request.content.decode(ImportBatchDTO.UploadInput.self)
                try ImportBatchDTO.UploadInput.validate(content: request)

                // Create a new batch entry without additional metadata.
                // The filename and uploader are intentionally omitted since
                // the file is referenced via the external file service.
                let batch = ImportBatch(filename: nil, uploadedBy: nil)
		try await batch.save(on: request.db)

                // Launch background job using the provided file identifier
                if let id = batch.id {
                        let context = QueueContext(
                                queueName: .default,
                                configuration: request.application.queues.configuration,
                                application: request.application,
                                logger: request.logger,
                                on: request.eventLoop
                        )
                        Task { try await TimesheetImportJob().dequeue(context, .init(batchID: id, fileID: input.fileID)) }
                }

		let response = Response(status: .accepted)
		try response.content.encode(batch, as: .json)
		return response
	}

	/// Retrieves batch details
	func detail(request: Request) async throws -> Response {
		let id: UUID = try request.parameters.require("batchId")
		guard let batch = try await ImportBatch.find(id, on: request.db) else {
			throw Abort(.notFound, reason: "Batch not found")
		}
		return try await batch.encodeResponse(for: request)
	}
}
