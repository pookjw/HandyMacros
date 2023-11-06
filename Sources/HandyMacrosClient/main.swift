import Foundation
import HandyMacros

@objc
final class MyObject: NSObject {
    @addCancellationToWillSet
    var number: Task<Void, Never>?
    
    @addObjCCompletionHandler(parameterName: "c")
    func foo_2(num: Int????) async throws -> Int {
        .zero
    }
}
