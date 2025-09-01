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
        public let isAtApprovedLocation: Bool?
        public let notes: String?

        public init(dateTime: Date, isAtApprovedLocation: Bool?, notes: String?) {
            self.dateTime = dateTime
            self.isAtApprovedLocation = isAtApprovedLocation
            self.notes = notes
        }

        enum CodingKeys: String, CodingKey { case dateTime, isAtApprovedLocation, notes }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.dateTime = try c.decode(Date.self, forKey: .dateTime)
            if let b = try? c.decode(Bool.self, forKey: .isAtApprovedLocation) {
                self.isAtApprovedLocation = b
            } else if let s = try? c.decode(String.self, forKey: .isAtApprovedLocation) {
                self.isAtApprovedLocation = (s as NSString).boolValue
            } else if (try? c.decodeNil(forKey: .isAtApprovedLocation)) == true {
                self.isAtApprovedLocation = nil
            } else {
                self.isAtApprovedLocation = nil
            }
            self.notes = try? c.decode(String.self, forKey: .notes)
        }
    }

}
