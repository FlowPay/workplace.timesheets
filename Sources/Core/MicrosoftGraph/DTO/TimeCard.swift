import Vapor

public struct GraphTimeCard: Content, Identifiable, Hashable {
	public let id: String
	public let userId: UUID
	public let clockInEvent: DatetimeEvent
	public let clockOutEvent: DatetimeEvent?
	public let breaks: [Break]?
	public let notes: String?

	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	public static func == (lhs: GraphTimeCard, rhs: GraphTimeCard) -> Bool {
		lhs.id == rhs.id
	}

	public struct Break: Content, Identifiable, Hashable {
		public var id: String { breakId }

		public let breakId: String
		public let start: DatetimeEvent
		public let end: DatetimeEvent

		public func hash(into hasher: inout Hasher) {
			hasher.combine(breakId)
		}

		public static func == (lhs: Break, rhs: Break) -> Bool {
			lhs.breakId == rhs.breakId
		}

	}

	public struct DatetimeEvent: Content {
		public let dateTime: Date
		public let isAtApprovedLocation: Bool
		public let notes: String?
	}

}
