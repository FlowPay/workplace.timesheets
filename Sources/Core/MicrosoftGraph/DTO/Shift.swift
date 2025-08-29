import Vapor

public struct GraphShift: Content {
	public let id: String
	public let userId: UUID?
	public let sharedShift: SharedShift?

	public struct SharedShift: Content {
		public let displayName: String?
		public let startDateTime: Date
		public let endDateTime: Date
		public let activities: [Activity]?
	}

	public struct Activity: Content {
		public let isPaid: Bool
		public let startDateTime: Date
		public let endDateTime: Date

		init(startDate: Date, endDate: Date, isPaid: Bool) {
			self.startDateTime = startDate
			self.endDateTime = endDate
			self.isPaid = isPaid
		}
	}
}
