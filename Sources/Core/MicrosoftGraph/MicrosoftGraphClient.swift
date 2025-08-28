import Vapor

/// Collection of Microsoft Graph OAuth scopes required by this service.
///
/// The Azure AD application used for server-to-server authentication **must**
/// be granted all of these scopes as application permissions so that users,
/// teams, schedules and presence information can be retrieved from Microsoft
/// Graph.
public enum MicrosoftGraphScope {
    /// Ordered list of required scope identifiers.
    public static let required: [String] = [
        "User.Read.All",      // list users in the tenant
        "Group.Read.All",     // access team resources
        "Schedule.Read.All",  // read shifts, time cards and time-off
        "Presence.Read.All"   // query user presence information
    ]
}

/// Protocol defining minimal Microsoft Graph operations used by the service.
public protocol MicrosoftGraphClientProtocol {
    /// Retrieves all teams in the tenant (basic info).
    func listTeams(client: Client) async throws -> [GraphTeam]
    /// Resolves Azure AD groups by display name (exact match).
    func listGroupsByNames(_ names: [String], client: Client) async throws -> [GraphGroup]
    /// Retrieves users that are members of the given Azure AD group.
    func listGroupMembers(groupId: String, client: Client) async throws -> [GraphUser]
    /// Retrieves all users in the tenant.
    func listUsers(client: Client) async throws -> [GraphUser]
    /// Retrieves shifts for a specific team (optionally for a time window).
    func listShifts(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphShift]
    /// Retrieves time cards for a specific team (optionally for a time window).
    func listTimeCards(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeCard]
    /// Retrieves time off requests for a specific team (optionally for a time window).
    func listTimeOffRequests(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeOff]
    /// Retrieves time off reasons for a specific team.
    func listTimeOffReasons(teamId: String, client: Client) async throws -> [GraphTimeOffReason]
}

/// Concrete implementation performing HTTP requests against Microsoft Graph.
public struct MicrosoftGraphClient: MicrosoftGraphClientProtocol {
    /// Base URL of Microsoft Graph, e.g. `https://graph.microsoft.com/v1.0`
    private let baseURL: String
    /// Provider responsible for fetching OAuth access tokens.
    private let tokenProvider: MicrosoftGraphTokenProvider

    /// Creates a new client.
    /// - Parameters:
    ///   - baseURL: Base Graph URL.
    ///   - tokenProvider: Provider used to obtain OAuth access tokens.
    public init(baseURL: String, tokenProvider: MicrosoftGraphTokenProvider) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    /// Performs a GET request against the specified path.
    private func get<T: Decodable>(_ path: String, client: Client, as type: T.Type) async throws -> T {
        let uri = URI(string: "\(baseURL)\(path)")
        var headers = HTTPHeaders()
        let token = try await tokenProvider.accessToken(client: client)
        headers.add(name: .authorization, value: "Bearer \(token)")
        let response = try await client.get(uri, headers: headers)
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Graph request failed with status \(response.status.code)")
        }
        return try response.content.decode(T.self)
    }

    /// Returns the list of teams (id, displayName) in the tenant.
    /// Uses the Groups endpoint filtered by teams.
    public func listTeams(client: Client) async throws -> [GraphTeam] {
        // Filter groups that are Teams and select only id and displayName
        let path = "/groups?$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&$select=id,displayName"
        let wrapper: GraphListWrapper<GraphTeam> = try await get(path, client: client, as: GraphListWrapper<GraphTeam>.self)
        return wrapper.value
    }

    /// Returns groups whose displayName matches any of the provided names.
    public func listGroupsByNames(_ names: [String], client: Client) async throws -> [GraphGroup] {
        var result: [GraphGroup] = []
        for name in names {
            // Exact displayName match
            let encoded = name.replacingOccurrences(of: "'", with: "''")
            let path = "/groups?$filter=displayName eq '\(encoded)'&$select=id,displayName"
            let wrapper: GraphListWrapper<GraphGroup> = try await get(path, client: client, as: GraphListWrapper<GraphGroup>.self)
            result.append(contentsOf: wrapper.value)
        }
        return result
    }

    /// Returns basic members of a group (id, displayName)
    public func listGroupMembers(groupId: String, client: Client) async throws -> [GraphUser] {
        let path = "/groups/\(groupId)/members?$select=id,displayName"
        let wrapper: GraphListWrapper<GraphUser> = try await get(path, client: client, as: GraphListWrapper<GraphUser>.self)
        return wrapper.value
    }

    /// Returns the list of users.
    public func listUsers(client: Client) async throws -> [GraphUser] {
        let wrapper: GraphListWrapper<GraphUser> = try await get("/users", client: client, as: GraphListWrapper<GraphUser>.self)
        return wrapper.value
    }

    /// Returns the list of shifts for a team.
    public func listShifts(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphShift] {
        let query = Self.rangeQuery(from: from, to: to)
        let wrapper: GraphListWrapper<GraphShift> = try await get("/teams/\(teamId)/schedule/shifts\(query)", client: client, as: GraphListWrapper<GraphShift>.self)
        return wrapper.value
    }

    /// Returns the list of time cards for a team.
    public func listTimeCards(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeCard] {
        let query = Self.rangeQuery(from: from, to: to)
        let wrapper: GraphListWrapper<GraphTimeCard> = try await get("/teams/\(teamId)/schedule/timeCards\(query)", client: client, as: GraphListWrapper<GraphTimeCard>.self)
        return wrapper.value
    }

    /// Returns the list of time off requests for a team.
    public func listTimeOffRequests(teamId: String, from: Date?, to: Date?, client: Client) async throws -> [GraphTimeOff] {
        let query = Self.rangeQuery(from: from, to: to)
        let wrapper: GraphListWrapper<GraphTimeOff> = try await get("/teams/\(teamId)/schedule/timeOffRequests\(query)", client: client, as: GraphListWrapper<GraphTimeOff>.self)
        return wrapper.value
    }

    /// Returns the list of time off reasons for a team.
    public func listTimeOffReasons(teamId: String, client: Client) async throws -> [GraphTimeOffReason] {
        let wrapper: GraphListWrapper<GraphTimeOffReason> = try await get("/teams/\(teamId)/schedule/timeOffReasons", client: client, as: GraphListWrapper<GraphTimeOffReason>.self)
        return wrapper.value
    }
}

extension MicrosoftGraphClient {
    /// Builds a query string for optional date range in RFC3339 format.
    static func rangeQuery(from: Date?, to: Date?) -> String {
        guard from != nil || to != nil else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var items: [String] = []
        if let from { items.append("startDateTime=\(iso.string(from: from))") }
        if let to { items.append("endDateTime=\(iso.string(from: to))") }
        return "?" + items.joined(separator: "&")
    }
}

/// Generic wrapper for Graph responses shaped as `{ "value": [...] }`.
struct GraphListWrapper<T: Decodable>: Decodable {
    let value: [T]
}

/// Simplified Graph user representation.
public struct GraphUser: Content {
    public let id: String
    public let displayName: String?
}

/// Simplified Graph group representation.
public struct GraphGroup: Content {
    public let id: String
    public let displayName: String?
}

/// Simplified Graph team representation.
public struct GraphTeam: Content {
    public let id: String
    public let displayName: String?
}

/// Simplified Graph shift representation.
public struct GraphShift: Content {
    public let id: String
    public let userId: String
    public let sharedShift: ShiftInfo

    public struct ShiftInfo: Content {
        public let startDateTime: Date
        public let endDateTime: Date
        public let breaks: [ShiftBreak]?
    }

    public struct ShiftBreak: Content {
        public let start: Date
        public let end: Date
    }
}

/// Simplified Graph time card representation.
public struct GraphTimeCard: Content {
    public let id: String
    public let userId: String
    public let clockInDateTime: Date
    public let clockOutDateTime: Date?
    public let breaks: [TimeCardBreak]?

    public struct TimeCardBreak: Content {
        public let startDateTime: Date
        public let endDateTime: Date
    }
}

/// Simplified Graph time-off request representation.
public struct GraphTimeOff: Content {
    public let id: String
    public let userId: String
    public let startDateTime: Date
    public let endDateTime: Date
    public let timeOffReasonId: String
}

/// Representation of a time-off reason.
public struct GraphTimeOffReason: Content {
    public let id: String
    public let displayName: String
}

extension Application {
    private struct MicrosoftGraphClientKey: StorageKey { typealias Value = MicrosoftGraphClientProtocol }
    /// Configured Microsoft Graph client.
    public var graphClient: MicrosoftGraphClientProtocol {
        get {
            guard let client = self.storage[MicrosoftGraphClientKey.self] else {
                fatalError("MicrosoftGraphClient not configured. Register in configure.swift or tests.")
            }
            return client
        }
        set { self.storage[MicrosoftGraphClientKey.self] = newValue }
    }
}

extension Request {
    /// Shortcut accessor for the configured Microsoft Graph client.
    public var graphClient: MicrosoftGraphClientProtocol { application.graphClient }
}
