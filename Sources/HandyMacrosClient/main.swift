import Foundation
import HandyMacros

@objc
final class MyObject: NSObject {
    @addCancellationToWillSet
    var number: Task<Void, Never>?
    
    @addObjCCompletionHandler
    func foo(number_1: Int??, number_2: Int?????) async throws -> String??? { "hello" }
}
