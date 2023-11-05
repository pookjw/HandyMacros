import Foundation
import HandyMacros

@objc
final class MyObject: NSObject {
    @addCancellationToWillSet
    var number: Task<Void, Never>?
    
//    @addObjCCompletionHandler(selector: .init("foo"))
//    @objc
//    @_silgen_name("foo")
    func foo(c: @escaping (Int?, Error?) -> Void) async {
        
    }
    
    @addObjCCompletionHandler
    func foo_2() async-> Int???? {
        nil
    }
}
