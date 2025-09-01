import Foundation
import Vapor

extension Worker {

	public convenience init(from graphUser: GraphUser) {
		self.init()
		self.id = graphUser.id
		self.fullName = graphUser.displayName ?? ""
		self.email = graphUser.mail
		self.archivedAt = graphUser.isActive ? nil : Date()
	}
}
