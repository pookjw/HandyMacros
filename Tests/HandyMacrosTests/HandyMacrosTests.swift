import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import HandyMacrosExternal

let testMacros: [String: Macro.Type] = [
    "addCancellationToWillSet": AddCancellationToWillSetMacro.self,
    "addObjCCompletionHandler": AddObjCCompletionHandlerMacro.self
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
    
    func test_addClangCompletionHandler() async throws {
        assertMacroExpansion(
            """
            @addObjCCompletionHandler
            func foo(num: Int?) async throws -> Int {
                .zero
            }
            """,
            expandedSource: """
            func foo(num: Int?) async throws -> Int {
                .zero
            }

            @objc
            func foo(num: Foundation.NSNumber?, completion: @escaping (@Sendable (Foundation.NSNumber?, Swift.Error?) -> Void)) -> Foundation.Progress {
                let progress: Foundation.Progress = .init(totalUnitCount: 1)
                
                let task: Task<Void, Never> = .init {
                    
                    let result: Foundation.NSNumber?
                    let error: Swift.Error?
                    
                    do {
                        result = try await .init(integerLiteral: foo(num: num?.intValue))
                        error = nil
                    } catch let _error {
                        result = nil
                        error = _error
                    }
                    
                    progress.completedUnitCount = 1
                    completion(result, error)
                }
                
                progress.cancellationHandler = {
                    task.cancel()
                }
                
                return progress
            }
            """,
            macros: testMacros
        )
    }
}
