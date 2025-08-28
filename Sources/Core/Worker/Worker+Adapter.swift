import Vapor

/// Adapter functions for Worker: communication with Microsoft Graph
extension Worker {
    /// Returns the set of active user IDs based on configured Azure AD group names.
    /// If no group names are configured, returns an empty set to indicate "all allowed".
    public static func adapterAllowedUserIDs(graph: MicrosoftGraphClientProtocol, client: Client) async throws -> Set<String> {
        do {
            let names = Configuration.shared.msGraphGroupNames
            guard !names.isEmpty else { return [] }
            let groups = try await graph.listGroupsByNames(names, client: client)
            var ids = Set<String>()
            for g in groups {
                let members = try await graph.listGroupMembers(groupId: g.id, client: client)
                for m in members { ids.insert(m.id) }
            }
            return ids
        } catch {
            throw Abort(.internalServerError, reason: "Worker adapter error: \(error.localizedDescription)")
        }
    }

    /// Fetches all users from Microsoft Graph.
    public static func adapterFetchAll(graph: MicrosoftGraphClientProtocol, client: Client) async throws -> [GraphUser] {
        do {
            return try await graph.listUsers(client: client)
        } catch {
            throw Abort(.internalServerError, reason: "Worker adapter error: \(error.localizedDescription)")
        }
    }
}
