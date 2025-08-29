import Vapor

public struct GraphTimeOff: Content {
	public let id: String
	public let userId: UUID
	public let startDateTime: GraphDateTimeTimeZone
	public let endDateTime: GraphDateTimeTimeZone
	public let timeOffReasonId: String?

	public var startDate: Date { startDateTime.date }
	public var endDate: Date { endDateTime.date }
}

public struct GraphTimeOffReason: Content {
	public let id: String
	public let displayName: String
}
