import Core
import Fluent
import Vapor
import Queues

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

                let batch = ImportBatch(filename: input.filename ?? input.file.filename, uploadedBy: input.uploadedBy)
                try await batch.save(on: request.db)

                // Persist file on disk for later processing
                var savedPath: String?
                if let data = input.file.data.getData(at: 0, length: input.file.data.readableBytes) {
                        let directory = request.application.directory.publicDirectory + "uploads/"
                        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                        let path = directory + (batch.id?.uuidString ?? UUID().uuidString) + ".xlsx"
                        try data.write(to: URL(fileURLWithPath: path))
                        savedPath = path
                }

                // Launch background job if file was saved
                if let path = savedPath, let id = batch.id {
                        let context = QueueContext(
                                queueName: .default,
                                configuration: request.application.queues.configuration,
                                application: request.application,
                                logger: request.logger,
                                on: request.eventLoop
                        )
                        Task { try await TimesheetImportJob().dequeue(context, .init(batchID: id, path: path)) }
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
