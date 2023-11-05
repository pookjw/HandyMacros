import HandyMacros
import Foundation
import Observation

final class MyObject {
    @addCancellationToWillSet
    var number: Task<Void, Never>?
    
    func foo() /*async*/ {
        
    }
}
