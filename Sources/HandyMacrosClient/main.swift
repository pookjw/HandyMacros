import Foundation
import HandyMacros

@objc
final class MyObject: NSObject {
    @AddCancellationToWillSet
    var number: Task<Void, Never>?
    
    @AddObjCCompletionHandler
    func foo(number_1: Int??, number_2: Int?????, bool_1: Bool??) async throws -> String??? { "hello" }
}
