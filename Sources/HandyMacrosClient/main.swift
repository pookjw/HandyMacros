import Foundation
import HandyMacros

@objc
final class MyObject: NSObject {
    @addCancellationToWillSet
    var number: Task<Void, Never>?
    
    @addObjCCompletionHandler(parameterName: "c", selectorName: "foo_3:")
    func foo_2() async throws -> Int {
        .zero
    }
}
