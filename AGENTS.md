# Agents.md Guide for Contributors (Swift Vapor Microservice)

This **Agents.md** file provides comprehensive guidelines for Contributors working with this Swift codebase built on the Vapor framework. It covers the project structure, coding standards, testing protocols, documentation practices, and development workflow to ensure that all contributions align with our project's conventions and quality standards.

## Project Structure for Contributors

Contributors should be aware of the repository's structure and the role of each major directory:

- **`Sources/Core`** – Core business logic and data models (using Fluent ORM) that Contributors should maintain. This layer contains model definitions, database migrations, and domain services.
- **`Sources/Api`** – REST API layer for controllers, request/response DTOs, and middleware. Controllers handle HTTP routes and use Core logic; Contributors should keep controller code thin and delegate to Core when appropriate.
- **`Sources/App`** – Application configuration and startup. Contributors use this for wiring components together (database setup, routing, configuration in `configure.swift`). This layer integrates Core and Api.
- **`Sources/Run`** – Executable entry point (main program) for running the service. Contributors should generally not modify this unless changing startup behavior; it creates the application, calls `configure()` and launches the server.
- **`Tests/`** – Test suite (XCTest cases) that Contributors must extend and keep passing. Tests are organized by feature (e.g., ClientAppTests, APIKeyTests, etc.) and spin up an in-memory Vapor application for integration testing.
- **`docs/`** – Documentation resources. This includes the OpenAPI specification (`openapi.json`) and related docs (like `description.md` or `openapi.html`). Contributors should reference these for understanding service contracts and update them when APIs change.
- **Configuration Files** – Environment-specific settings are provided via environment variables (no committed secret files). Contributors should use env vars (e.g., database credentials, service ports) instead of hardcoded values.

*Note:* This service follows a standard three-layer architecture (Core, Api, App) as used across FlowPay’s Swift microservices. Contributors should preserve this separation of concerns, placing new code in the appropriate layer. For example, business rules belong in Core, not directly in controllers, and HTTP-specific logic belongs in Api.

## Coding Conventions and Best Practices for Contributors

Contributors must adhere to the project's coding standards to ensure consistency and readability:

- **Language and Style**: Generate code in **Swift 5** (the project’s language). Follow existing Swift style conventions (naming, file organization, etc.) present in the repository. Use proper indentation and formatting consistent with the current code (e.g. 4-space indentation, braces on new lines).
- **Documentation in Code**: Use `//` for inline code comments and DocC-style `///` comments for variables, methods, structures, and other declarations. All comments must be written in **English** to help human developers understand the code.
- **Meaningful Names**: Use meaningful variable, function, and type names. Avoid single-letter or overly generic names; instead, use descriptive names that convey intent while following the project's naming conventions (CamelCase for types, lowerCamelCase for variables/functions, etc.).
- **Use of Comments**: When encountering a code section whose purpose isn't immediately clear, add explanatory comments. Comments must be concise and relevant, explaining the "why" behind non-trivial logic or decisions.
- **Guard Clauses**: To avoid deep nesting, prefer using `guard` statements for early exits rather than multiple nested `if` blocks. This keeps the code flatter and improves readability.
- **Environment Configuration**: Read configuration values (database URLs, API endpoints, credentials, etc.) from **environment variables** rather than hardcoding them. This ensures the code is portable and secure.
- **Monetary Values**: Use Swift’s `Decimal` type for all money-related values and calculations. Avoid `Float` or `Double` for monetary amounts to prevent precision and rounding errors.
- **Concurrency**:
  - When possible, leverage Swift's `async let` pattern within asynchronous contexts to perform concurrent operations efficiently, improving performance and parallelism.
  - For loading multiple Fluent model relations across different fields of a model, or performing multiple sets of asynchronous tasks, use Swift concurrency's `TaskGroup` (e.g., `withThrowingTaskGroup`) to execute these loads in parallel. This approach is especially valuable when retrieving distinct relations (on different fields), reducing overall latency. For example:
    ```swift
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await user.$address.load(on: db) }
        group.addTask { try await user.$login.load(on: db) }                                                                          
      
        try await group.waitForAll()
    }
    ```
- **Avoid Duplicating Fields**: Before adding or modifying model fields or DTO properties, verify that a similar field does not already exist under a different name to avoid redundancy.
- **Consistent Architecture Usage**: Follow the established layering – implement database models and logic in **Core**, API endpoints and controllers in **Api**, and configuration wiring in **App**. Do not bypass layers (no business logic directly in controllers, etc.).
- **Controller Responses**: Controllers should always return `Response` objects or alternatively throw Vapor’s `Abort` exception with the correct HTTP status code and a descriptive `reason`. Ensure the status code and error reasons align with API logic and documentation (e.g., return `Response(status: .created, ...)` for successful creation, `Response(status: .ok, ...)` for retrieval, or `throw Abort(.badRequest, reason: "Invalid input provided")` for validation failures).
- **Input Validation**: Use Vapor's built-in `Validators` on DTO properties to enforce formal constraints (e.g., length, format, range). Map validation failures to clear, human-readable errors consistent with the OpenAPI `schema` definitions (e.g., `Abort(.badRequest, reason: "Username must be at least 3 characters")`).

	```swift
	// Address Input DTO with validators
	extension Address {
	  struct Input: Content, Validatable {
	    var street: String
	    var zipCode: String
	
	    static func validations(_ v: inout Validations) {
	      v.add("street", as: String.self, .count(1...))
	      v.add("zipCode", as: String.self, .custom { zip in
	        let pattern = try Regex(#"^[0-9]{5}$"#)
	        guard zip.wholeMatch(of: pattern) != nil else {
	          throw BasicValidationError("Zip code must be exactly 5 digits")
	        }
	      })
	    }
	  }
	}
	
	// User Input DTO with nested Address validation
	extension User {
	  struct Input: Content, Validatable {
	    var name: String
	    var email: String
	    var address: Address.Input
	
	    static func validations(_ v: inout Validations) {
	      v.add("name", as: String.self, .count(3...))
	      v.add("email", as: String.self, .email)
	      v.add("address", as: Address.Input.self, .valid)
	    }
	  }
	}
	
	// In Controller:
	func createUser(req: Request) async throws -> User.Output {
	  let input = try req.content.decode(User.Input.self)
	  do {
	    try User.Input.validate(content: req)
	  } catch {
	    throw Abort(.badRequest, reason: "Validation failed: \(error)")
	  }
	  // proceed with creation...
	}
	```

- **Error Handling**(.badRequest, reason: "Username must be at least 3 characters")\`).
- **Error Handling**: Use Vapor's built-in error handling patterns. All errors returned by controllers must include a clear, human-readable `reason` field (e.g., `Abort(.badRequest, reason: "Invalid user ID provided")`) so that API clients receive meaningful messages.
- **Security & Secrets**: Never hard-code secrets, API keys, or passwords. Use environment variables for any sensitive information.
- **Code Formatting**: Ensure code is well-indented, and if a formatter (like SwiftLint/SwiftFormat) is configured, conform to those rules.
- **Pre-commit Formatting Check**: Before committing, run the project's formatter or linter to verify that code indentation and styling are correct and consistent.
- **External Dependencies**: If a feature requires a new Swift package or dependency, modify `Package.swift` accordingly, justify the addition, and update documentation.
- **DTO Conventions**:
  - Declare all Data Transfer Objects (DTOs) within an **extension** of the corresponding Core entity.
  - **Input**: Use the Input DTO as an initializer for the Core entity, declared in the same extension. For example:
    ```swift
    extension User {
      /// Input DTO for creating a new User
      struct Input: Content {
        let name: String
        let email: String
      }
    
      /// Initialize User from DTO
      init(from dto: Input) {
        self.name = dto.name
        self.email = dto.email
      }
    }
    ```
    - **Partial Initialization**: Sometimes, due to controller-specific logic, it is not possible to initialize the entire entity from the Input DTO. In these cases, include in the `///` DocC comment for `init(from:)` a clear warning that the created model is incomplete and cannot be saved correctly until all mandatory fields are populated.
  - **Output**: Define the Output DTO with an initializer that accepts the Core entity, declared in the same extension. Expose model relations conditionally by checking for non-nil values or using optional chaining to avoid `fatalError`. For example:
    ```swift
    extension User {
      /// Output DTO for exposing User data
      struct Output: Content {
        let id: UUID
        let name: String
        let email: String?
        let address: Address.Output?
    
        init(_ user: User) throws {
          self.id = try user.requireID()
          self.name = user.name
          self.email = user.email
    
          // Explict unwrap
          if let address = user.$address.value {
            self.address = Address.Output(address)
          } else { 
            self.address = nil
          }
      }
    }
    ```

## Testing Guidelines for Contributors

Writing and running tests is a critical part of this project. Contributors should ensure all new code is covered by tests and that all tests continue to pass:

- **Test Method Documentation**: Each test method must include a brief DocC comment describing the purpose of the test (e.g., "Creation of a user") and a detailed description of all assertions and checks performed.

- **Unit Tests for New Features**: For each new feature or bug fix, create corresponding **XCTest** unit tests (or integration tests using Vapor’s testing utilities) in the `Tests/` directory, following naming conventions (e.g., *FeatureName*Tests.swift).

- **Maintain Existing Tests**: If changes affect existing behavior, update relevant tests rather than remove them, unless behavior truly changes.

- **Running Tests**: Use Swift Package Manager commands:

  - Full suite: `swift test`
  - Specific target: `swift test --filter TargetName`

- **Test Environment**: Tests use in-memory SQLite by default. For external service calls, implement mocks or stubs to simulate responses.

- **Mocks for External Services**: Provide consistent mock responses for HTTP or service calls to keep tests reliable.

- **HTTP Request Construction Tests**: When writing unit tests for features that perform HTTP requests to other internal services or external providers, focus on verifying that the HTTP request—method, URL, headers, and body—is constructed correctly according to the target service's API specification. Do not test the provider or external dependencies themselves.

- **Mock Controllers for HTTP Tests**: To ensure tests remain reliable and do not fail due to unreachable external targets, set up mock HTTP controllers within the test suite. Configure the test application's environment (e.g., via environment variables or `Configuration` overrides) so HTTP clients point to these mock controllers. This makes mock endpoints discoverable and allows realistic end-to-end simulation of HTTP interactions.

- **Test Parallelism**\*\*: If tests are flaky, run sequentially (`--num-workers 1`) and document any parallelism issues in comments.

- **Code Coverage**: Aim for high coverage. Run with coverage when possible (`swift test --enable-code-coverage -c debug`) and report results. If not feasible, run without coverage but still test thoroughly.

- **Failing Tests Policy**: Address any failing test by fixing code or updating tests. Ensure a green suite before merging.

- **Use of Docker for Testing**: Optionally use Docker for end-to-end testing with a real database (`docker-compose`), while unit tests rely on SQLite.

- **API Contract Testing**: Validate endpoints against the OpenAPI spec, ideally via **Prism** proxy tests. If Prism is unavailable, manually sync implementation and spec.

- **Isolation and Repeatability**: Ensure tests clean up data or use unique inputs to avoid conflicts.

## Documentation and OpenAPI Guidelines for Contributors

Maintaining documentation is essential. Contributors should update docs as code changes:

- **Functional Documentation Updates**: When adding or modifying features, update `docs/description.md` or the README in clear English with proper Markdown formatting.
- **Comprehensive Service Description**: Cover service purpose, architecture, operations, workflows (with Mermaid diagrams if helpful), and onboarding steps for new developers.
- **OpenAPI Specification**: Keep `docs/openapi.json` in sync with implementation. Update and regenerate human-readable docs (`docs/openapi.html`) via Redocly or similar.
- **Mermaid Diagrams**: Use Mermaid syntax for sequence diagrams or flowcharts to clarify complex logic.
- **Markdown Quality**: Ensure proper headings, lists, tables, and fenced code blocks. Preview rendered Markdown if possible.
- **Docstring Comments**: Maintain DocC comments for key code elements in English.

## Pull Request and Commit Guidelines for Contributors

When preparing changes:

- **Descriptive Commits/PRs**: Summarize **what** and **why** in commit messages and PR descriptions. Reference related issues (e.g., `Fixes FPY-1234`).
- **Scope of Changes**: Keep PRs focused on a single task or feature. Avoid mixing unrelated changes.
- **Include Tests and Docs in PR**: Bundle code, tests, and documentation updates together.
- **Passing Checks**: Verify all tests and CI checks pass locally before marking the PR ready.
- **Code Review Assistance**: Highlight any non-obvious decisions or added dependencies in the PR description.
- **Formatting and Conventions**: Run linters/formatters locally to avoid CI style failures.
- **No Sensitive Info**: Do not commit secrets. Use dummy values in examples.
- **Collaborative Tone**: Maintain a professional tone; avoid AI references.

## Build, Deployment & Logging for Contributors

Before finalizing changes, perform these checks:

- **Compilation**: Ensure `swift build` or Xcode build completes without warnings/errors.
- **Local Run**: Start the service locally or in Docker to verify startup and endpoint accessibility.
- **Database Migrations**: Name migration files after the Git branch (e.g., `FPY-1234`), set the migration `name` property accordingly, and verify migrations on a fresh database.
- **Linting/Static Analysis**: Run SwiftLint/other linters and fix issues.
- **Continuous Integration**: Mirror CI steps locally to ensure no failures on macOS/Linux.
- **Environment Variables & Config**: Document any new env vars in README and provide safe defaults.
- **.env.testing**: Each repository must include a `.env.testing` file containing all necessary environment variables and their default values, so tests can be run end-to-end without manual intervention.
- **Dependency Management**: After adding dependencies, run `swift package resolve` and update `Package.resolved`.
- **Docker and Deployment**: Update `Dockerfile` or deployment scripts if dependencies change, and test Docker builds.
- **Logging and Monitoring**:
  - **Format & Context**: Use structured logs (`app.logger.info("msg", metadata: [...])`) with timestamps and correlation IDs.
  - **Important to Record**: Startup/shutdown events, HTTP requests/responses with status and timing, errors/exceptions with stack traces, external calls, and slow database queries.
  - **What Not to Include**: Sensitive data (PII, passwords, tokens), full payloads containing secrets, large binary blobs.
  - **Log Levels**:
    - Trace: detailed debugging
    - Debug: development info
    - Info: routine events
    - Warning: recoverable anomalies
    - Error: failures needing attention
    - Critical: unrecoverable errors
  - **Best Practices**: Use appropriate levels, propagate correlation IDs through middleware, keep Info concise, control verbosity via `LOG_LEVEL`, and rotate logs to prevent unbounded growth.
- **Final Review**: Self-review diff to catch any unintended changes and ensure compliance with these guidelines.

By following this Agents.md, all Contributors will produce code, tests, and documentation that integrate seamlessly with our Swift Vapor microservices, maintaining high quality and consistency with the team's standards.

