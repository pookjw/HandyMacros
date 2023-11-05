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
            func foo() async throws -> Int {
                .zero
            }
            """,
            expandedSource: """
            @objc
            func foo(completionHandler: @escaping ((Int?, Error?) -> Void)) {
                let progress: Progress = .init(totalUnitCount: 1)
                
                let task: Task<Void, Never> = .init {
                    let result: Int?
                    let error: Error?
            
                    do {
                        result = try await foo()
                        error = nil
                    } catch let _error {
                        result = nil
                        error = _error
                    }
                    
                    progress.completedUnitCount = 1
                    completionHandler(result, error)
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
