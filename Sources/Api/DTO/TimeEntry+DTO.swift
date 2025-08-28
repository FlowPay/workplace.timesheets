import Core
import Vapor

extension TimeEntry {
	/// Representation returned by the API
	struct Output: Content {
		var id: UUID
		var date: Date
		var startAt: Date
		var endAt: Date
		var breaks: [Break.Output]

		init(_ entry: TimeEntry) throws {
			guard let id = entry.id else {
				throw Abort(.internalServerError, reason: "TimeEntry model is not fully initialized")
			}
			self.id = id
			self.date = entry.date
			self.startAt = entry.startAt
			self.endAt = entry.endAt
			self.breaks = entry.breaks.map { Break.Output($0) }
		}
	}
}

extension Break {
	/// Output representation for a break
	struct Output: Content {
		var startAt: Date
		var endAt: Date

		init(_ br: Break) {
			self.startAt = br.startAt
			self.endAt = br.endAt
		}
	}
}
