import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import HandyMacrosExternal

let testMacros: [String: Macro.Type] = [
    "addCancellationToWillSet": AddCancellationToWillSetMacro.self,
]

final class HandyMacrosTests: XCTestCase {
    func test_addCancellationToWillSet() async throws {
        assertMacroExpansion(
            """
            actor MyActor {
                @addCancellationToWillSet var task: Task<Void, Never>?
            }
            """,
            expandedSource: """
            actor MyActor {
                var task: Task<Void, Never>? {
                    willSet {
                        task?.cancel()
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}
