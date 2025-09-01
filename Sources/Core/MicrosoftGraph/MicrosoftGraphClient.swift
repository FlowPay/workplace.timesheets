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
		"User.Read.All",  // list users in the tenant
		"Group.Read.All",  // access team resources
		"Schedule.Read.All",  // read shifts, time cards and time-off
		"Presence.Read.All",  // query user presence information
		"Team.ReadBasic.All",  // read basic team information
	]
}

/// Protocol defining minimal Microsoft Graph operations used by the service.
public protocol MicrosoftGraphClientProtocol {
	/// Retrieves all teams in the tenant (basic info).
	func listTeams(client: Client) async throws -> [GraphTeam]
	/// Retrieves users that are members of the given Azure AD group.
	func listMembers(groupId: UUID, client: Client) async throws -> [GraphUser]
	/// Retrieves all users in the tenant.
	func listUsers(client: Client) async throws -> [GraphUser]
	/// Retrieves shifts for a specific team (optionally for a time window).
    func listShifts(teamId: UUID, from: Date?, to: Date?, top: Int? , client: Client) async throws -> [GraphShift]
	/// Retrieves time cards for a specific team (optionally for a time window).
    func listTimeCards(teamId: UUID, from: Date?, to: Date?, top: Int?, client: Client) async throws -> [GraphTimeCard]
	/// Retrieves time off requests for a specific team (optionally for a time window).
    func listTimeOffRequests(teamId: UUID, from: Date?, to: Date?, top: Int?, client: Client) async throws -> [GraphTimeOff]
	/// Retrieves time off reasons for a specific team.
	func listTimeOffReasons(teamId: UUID, client: Client) async throws -> [GraphTimeOffReason]
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
	func get<T: Decodable>(_ path: String, client: Client, as type: T.Type = T.self) async throws -> T {
		try await getAbsolute("\(baseURL)\(path)", client: client, as: T.self)
	}

	/// Performs a GET request against an absolute URL and decodes the response as `T`.
	private func getAbsolute<T: Decodable>(_ absolute: String, client: Client, as type: T.Type = T.self) async throws -> T {
		let uri = URI(string: absolute)
		var headers = HTTPHeaders()

		let token = try await tokenProvider.accessToken(client: client)

		headers.bearerAuthorization = .init(token: token)

		let request = ClientRequest(method: .GET, url: uri, headers: headers)
		let response = try await client.send(request)

		guard response.status == .ok else {
			throw Abort(
				.internalServerError,
				reason:
					"Graph request failed with status \(response.status.code)\nResponse: \(response.body?.getString(at: 0, length: response.body?.readableBytes ?? 0) ?? "<empty>")\nRequest: \(request)"
			)
		}

		// Decode with ISO8601 dates including fractional seconds (Graph returns 2022-09-21T12:52:21.927Z)
		var buffer = response.body ?? .init()
		let readable = buffer.readableBytes
		let data = buffer.readData(length: readable) ?? Data()
		let decoder = JSONDecoder()
		let iso = ISO8601DateFormatter()
		iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		decoder.dateDecodingStrategy = .custom { decoder in
			let container = try decoder.singleValueContainer()
			let str = try container.decode(String.self)
			if let d = iso.date(from: str) {
				return d
			}
			// Fallback: try without fractional seconds
			let isoNoFrac = ISO8601DateFormatter()
			isoNoFrac.formatOptions = [.withInternetDateTime]
			if let d2 = isoNoFrac.date(from: str) {
				return d2
			}
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(str)")
		}
		return try decoder.decode(T.self, from: data)
	}

	/// Performs a paged GET across Graph list responses supporting `@odata.nextLink`.
	func getPaged<T: Decodable>(_ path: String, client: Client, as type: T.Type = T.self) async throws -> [T] {
		var results: [T] = []
		var nextURL: String? = "\(baseURL)\(path)"
		while let url = nextURL {
			// Trace the page fetch to aid debugging
			let page: GraphPagedListWrapper<T> = try await getAbsolute(url, client: client, as: GraphPagedListWrapper<T>.self)
			results.append(contentsOf: page.value)
			// Debug pagination trace
			if let nl = page.nextLink { print("Graph paging nextLink detected:", nl) }
			nextURL = page.nextLink
		}
		return results
	}

	/// Returns the list of teams (id, displayName) in the tenant.
	/// Uses the Groups endpoint filtered by teams.
	public func listTeams(client: Client) async throws -> [GraphTeam] {
		// Filter groups that are Teams and select only id and displayName
		let path = "/groups?$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&$select=id,displayName"
		let page: GraphPagedListWrapper<GraphTeam> = try await get(path, client: client)
		return page.value
	}

	/// Returns basic members of a group (id, displayName)
	public func listMembers(groupId: UUID, client: Client) async throws -> [GraphUser] {
		let path = "/groups/\(groupId.uuidString.lowercased())/members?$select=id,displayName"
		let page: GraphPagedListWrapper<GraphUser> = try await get(path, client: client)
		return page.value
	}

	/// Returns the list of users.
	public func listUsers(client: Client) async throws -> [GraphUser] {
		// Fetch only the properties we model in GraphUser
		return try await getPaged("/users?$select=id,displayName,mail,accountEnabled,userType", client: client)
	}

	/// Returns the list of shifts for a team.
    public func listShifts(teamId: UUID, from: Date?, to: Date?, top: Int? = nil, client: Client) async throws -> [GraphShift] {

		// let queryDateString = queryDateString(start: from, end: to)

        var uri = "/teams/\(teamId.uuidString.lowercased())/schedule/shifts"
        if let top { uri += "?$top=\(top)" }
		// + "?$filter=userId ne null"
		// + (queryDateString != nil ? " and \(queryDateString!)" : "")

		let items: [GraphShift] = try await getPaged(uri, client: client)
		return items
	}

	/// Returns the list of time cards for a team.
    public func listTimeCards(teamId: UUID, from: Date?, to: Date?, top: Int? = nil, client: Client) async throws -> [GraphTimeCard] {

		// let queryDateString = queryDateString(start: from, end: to)

        var uri = "/teams/\(teamId.uuidString.lowercased())/schedule/timeCards"
        if let top { uri += "?$top=\(top)" }
		// + "?$filter=userId ne null"
		// + (queryDateString != nil ? " and \(queryDateString!)" : "")

		let items: [GraphTimeCard] = try await getPaged(uri, client: client)
		return items
	}

	/// Returns the list of time off requests for a team.
    public func listTimeOffRequests(teamId: UUID, from: Date?, to: Date?, top: Int? = nil, client: Client) async throws -> [GraphTimeOff] {

		// let queryDateString = queryDateString(start: from, end: to)

        var uri = "/teams/\(teamId.uuidString.lowercased())/schedule/timeOffRequests"
        if let top { uri += "?$top=\(top)" }
		// + "?$filter=userId ne null"
		// + (queryDateString != nil ? " and \(queryDateString!)" : "")

		let items: [GraphTimeOff] = try await getPaged(uri, client: client)
		return items
	}

	/// Returns the list of time off reasons for a team.
	public func listTimeOffReasons(teamId: UUID, client: Client) async throws -> [GraphTimeOffReason] {

		let queryDateString: String? = nil  //TODO: queryDateString(start: from, end: to)

		let uri =
			"/teams/\(teamId.uuidString.lowercased())/schedule/timeOffReasons"
		// + "?$filter=userId ne null"
		// + (queryDateString != nil ? " and \(queryDateString!)" : "")
		let items: [GraphTimeOffReason] = try await getPaged(uri, client: client)
		return items
	}

	public func queryDateString(start: Date?, end: Date?) -> String? {
		let dateFormatter = ISO8601DateFormatter()
		dateFormatter.formatOptions = [.withFullDate]

		var dateQueryString = ""
		if let start = start {
			dateQueryString += "startDateTime ge \(dateFormatter.string(from: start))"
		}
		if let end = end {
			if !dateQueryString.isEmpty {
				dateQueryString += " and "
			}
			dateQueryString += "endDateTime le \(dateFormatter.string(from: end))"
		}

		return dateQueryString.isEmpty ? nil : dateQueryString
	}
}

// DTO types and wrappers moved to Sources/Core/MicrosoftGraph/DTO

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
