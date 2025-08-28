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
            workers.post(use: self.create)
            workers.get(use: self.list)
            workers.group(":id") { worker in
                worker.get(use: self.detail)
                worker.put(use: self.update)
                worker.delete(use: self.archive)
                worker.post("restore", use: self.restore)
            }
        }
    }

    /// Create a new worker
    func create(request: Request) async throws -> Response {
        let input = try request.content.decode(Worker.Input.self)
        try Worker.Input.validate(content: request)

        let db = request.transactionalDB
        // Ensure employeeKey is unique (case-insensitive)
        let normalizedKey = input.employeeKey.lowercased()
        let existing = try await Worker.query(on: db)
            .filter(\.$employeeKey == normalizedKey)
            .first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "employeeKey already exists")
        }
        let worker = Worker(employeeKey: normalizedKey, fullName: input.fullName, team: input.team, role: input.role)
        try await worker.save(on: db)

        let output = try Worker.Output(worker: worker)
        return try await output.encodeResponse(status: .created, for: request)
    }

    /// List workers with optional filters and pagination
    func list(request: Request) async throws -> Response {
        let queryInput = try request.query.decode(Worker.ListQuery.self)

        let page = queryInput.page ?? 1
        let per = queryInput.per ?? 20
        let options = Worker.ListOptions(
            page: page,
            per: per,
            search: queryInput.q,
            team: queryInput.team,
            role: queryInput.role,
            includeArchived: queryInput.archived ?? false
        )

        let pageResult = try await Worker.list(options, on: request.db)
        let outputs = try pageResult.items.map { try Worker.Output(worker: $0) }

        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: "X-Total", value: pageResult.metadata.total.description)
        response.headers.replaceOrAdd(name: "X-Page", value: pageResult.metadata.page.description)
        response.headers.replaceOrAdd(name: "X-Per-Page", value: pageResult.metadata.per.description)
        try response.content.encode(outputs, as: .json)
        return response
    }

    /// Retrieve worker details
    func detail(request: Request) async throws -> Response {
        let id: UUID = try request.parameters.require("id")
        guard let worker = try await Worker.find(id, on: request.db) else {
            throw Abort(.notFound, reason: "Worker not found")
        }
        let output = try Worker.Output(worker: worker)
        return try await output.encodeResponse(for: request)
    }

    /// Update worker data
    func update(request: Request) async throws -> Response {
        let id: UUID = try request.parameters.require("id")
        let input = try request.content.decode(Worker.Update.self)
        try Worker.Update.validate(content: request)

        let db = request.transactionalDB
        guard let worker = try await Worker.find(id, on: db) else {
            throw Abort(.notFound, reason: "Worker not found")
        }

        if let employeeKey = input.employeeKey?.lowercased(), employeeKey != worker.employeeKey {
            let existing = try await Worker.query(on: db)
                .filter(\.$employeeKey == employeeKey)
                .first()
            if existing != nil {
                throw Abort(.conflict, reason: "employeeKey already exists")
            }
            worker.employeeKey = employeeKey
        }

        if let fullName = input.fullName { worker.fullName = fullName }
        if let team = input.team { worker.team = team }
        if let role = input.role { worker.role = role }

        try await worker.save(on: db)
        let output = try Worker.Output(worker: worker)
        return try await output.encodeResponse(for: request)
    }

    /// Archive (soft delete) a worker
    func archive(request: Request) async throws -> Response {
        let id: UUID = try request.parameters.require("id")
        let db = request.transactionalDB
        guard let worker = try await Worker.find(id, on: db) else {
            throw Abort(.notFound, reason: "Worker not found")
        }
        worker.archivedAt = Date()
        try await worker.save(on: db)
        return Response(status: .noContent)
    }

    /// Restore an archived worker
    func restore(request: Request) async throws -> Response {
        let id: UUID = try request.parameters.require("id")
        let db = request.transactionalDB
        guard let worker = try await Worker.find(id, on: db) else {
            throw Abort(.notFound, reason: "Worker not found")
        }
        worker.archivedAt = nil
        try await worker.save(on: db)
        let output = try Worker.Output(worker: worker)
        return try await output.encodeResponse(for: request)
    }
}
