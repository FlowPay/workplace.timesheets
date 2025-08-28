import Fluent
import Foundation
import Vapor

extension Worker {
    /// Options for listing workers
    public struct ListOptions {
        public let page: Int
        public let per: Int
        public let search: String?
        public let team: String?
        public let role: String?
        public let includeArchived: Bool

        /// Initialize the list options container
        public init(page: Int, per: Int, search: String?, team: String?, role: String?, includeArchived: Bool) {
            self.page = page
            self.per = per
            self.search = search
            self.team = team
            self.role = role
            self.includeArchived = includeArchived
        }
    }

    /// Retrieve a paginated list of workers applying optional filters
    /// - Parameters:
    ///   - query: Listing parameters
    ///   - db: Database instance
    /// - Returns: A paginated list of workers
    public static func list(_ query: ListOptions, on db: Database) async throws -> Page<Worker> {
        let builder = Worker.query(on: db)

        if !query.includeArchived {
            builder.filter(\.$archivedAt == nil)
        }

        if let team = query.team {
            builder.filter(\.$team == team)
        }

        if let role = query.role {
            builder.filter(\.$role == role)
        }

        if let search = query.search, !search.isEmpty {
            builder.group(.or) { group in
                group.filter(\.$fullName ~~ search)
                group.filter(\.$employeeKey ~~ search)
            }
        }

        builder.sort(\.$fullName, .ascending)

        let pageRequest = PageRequest(page: query.page, per: query.per)
        return try await builder.paginate(pageRequest)
    }
}
