import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import HandyMacrosExternal

let testMacros: [String: Macro.Type] = [
    "AddCancellationToWillSet": AddCancellationToWillSetMacro.self,
    "AddObjCCompletionHandler": AddObjCCompletionHandlerMacro.self
]

final class HandyMacrosTests: XCTestCase {
    func test_addCancellationToWillSet() async throws {
        assertMacroExpansion(
            """
            actor MyActor {
                @AddCancellationToWillSet var task: Task<Void, Never>?
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
            @AddObjCCompletionHandler
            func foo(num: Int?) async throws -> [Int] {
                [.zero]
            }
            """,
            expandedSource: """
            func foo(num: Int?) async throws -> [Int] {
                [.zero]
            }

            @objc
            func foo(num: Foundation.NSNumber?, completion: @escaping (@Sendable ([Int]?, Swift.Error?) -> Void)) -> Foundation.Progress {
                let progress: Foundation.Progress = .init(totalUnitCount: 1)
                
                let task: Task<Void, Never> = .init {
                    
                    let result: [Int]?
                    let error: Swift.Error?
                    
                    do {
                        result = try await foo(num: num?.intValue)
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
