import Vapor

public struct GraphUser: Content {
	public let id: UUID
	public let displayName: String?
	public let mail: String?
	public let accountEnabled: Bool
	public let userType: UserType

	public enum UserType: String, Codable, Sendable {
		case member = "Member"
		case guest = "Guest"
		case unknown = "Unknown"
	}

	var isActive: Bool {
		return accountEnabled && userType == .member
	}
}

public struct GraphGroup: Content {
	public let id: String
	public let displayName: String?
}

public struct GraphTeam: Content {
	public let id: UUID
	public let displayName: String?
}
