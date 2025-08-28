import XCTest
@testable import Core

/// Tests ensuring required Microsoft Graph OAuth scopes are declared.
final class MicrosoftGraphScopeTests: XCTestCase {
    /// Verify that the list of required scopes matches the documented set.
    func testRequiredScopes() throws {
        let expected: Set<String> = [
            "User.Read.All",
            "Group.Read.All",
            "Schedule.Read.All",
            "Presence.Read.All"
        ]
        XCTAssertEqual(Set(MicrosoftGraphScope.required), expected)
    }
}
