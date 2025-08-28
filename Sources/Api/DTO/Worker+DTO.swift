import Core
import Vapor

extension Worker {
    /// Payload for creating a worker
    struct Input: Content, Validatable {
        var employeeKey: String
        var fullName: String
        var team: String?
        var role: String?

        static func validations(_ validations: inout Validations) {
            validations.add("employeeKey", as: String.self, is: .count(1...))
            validations.add("fullName", as: String.self, is: .count(1...))
        }
    }

    /// Payload for updating a worker
    struct Update: Content, Validatable {
        var employeeKey: String?
        var fullName: String?
        var team: String?
        var role: String?

        static func validations(_ validations: inout Validations) {}
    }

    /// Representation returned by the API
    struct Output: Content {
        var id: UUID
        var employeeKey: String
        var fullName: String
        var team: String?
        var role: String?
        var archivedAt: Date?
        var createdAt: Date
        var updatedAt: Date

        init(worker: Worker) throws {
            guard let id = worker.id, let createdAt = worker.createdAt, let updatedAt = worker.updatedAt else {
                throw Abort(.internalServerError, reason: "Worker model is not fully initialized")
            }
            self.id = id
            self.employeeKey = worker.employeeKey
            self.fullName = worker.fullName
            self.team = worker.team
            self.role = worker.role
            self.archivedAt = worker.archivedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    /// Query parameters for listing workers
    struct ListQuery: Content {
        var page: Int?
        var per: Int?
        var q: String?
        var team: String?
        var role: String?
        var archived: Bool?
    }
}
