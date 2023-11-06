# HandyMacros

Swift Macro들

## `AddCancellationToWillSetMacro`

`Task`의 type을 가진 propery에 `cancel()`을 호출해주는 `willSet` accessor를 추가해줘요.

### 예시

```swift
class Object {
    @addCancellationToWillSet
    var number: Task<Void, Never>?
    /* Expanded -- START */
    {
        willSet {
            number?.cancel()
        }
    }
    /* Expanded -- END */
}
```

## `AddObjCCompletionHandlerMacro`

`async` method를 completion block 형태의 새로운 `@objc` method로 만들어줘요.

[`apple/swift-syntax의 AddCompletionHandlerMacro.swift`](https://github.com/apple/swift-syntax/blob/main/Examples/Sources/MacroExamples/Implementation/Peer/AddCompletionHandlerMacro.swift)와 다른 점은

- `NSProgress`를 통한 cancel을 지원해요.

- Error Handling을 지원해요.

- `@objc`를 자동으로 추가해줘요. Objective-C에 맞는 형태로 변환해줘요.

- `Int?`를 `NSNumber?`로 변환해줘요.

TODO : `@_silgen_name` 지원 (`@_cdecl`은 지원 불가 - Swift ABI를 지원하지 않음)

### 예시

⬇️ 간단한 예시

```swift
@objc class Object: NSObject {
    @addObjCCompletionHandler
    func foo() async -> Void {}
    
    /* Expanded -- START */
    @objc
    func foo(completion: @escaping () -> Void) -> Foundation.Progress {
        let progress: Foundation.Progress = .init(totalUnitCount: 1)
        
        let task: Task<Void, Never> = .init {
            
            await foo()
            progress.completedUnitCount = 1
            completion()
        }
        
        progress.cancellationHandler = {
            task.cancel()
        }
        
        return progress
    }
    /* Expanded -- END */
}
```

⬇️ 복잡한 예시 (여러 개의 parameter, multiple optionals, throwing Error, Int -> NSNumber 변환)

```swift
@objc class Object: NSObject {
    @addObjCCompletionHandler
    func foo(number_1: Int??, number_2: Int?????) async throws -> String??? { "hello" }
    
    /* Expanded -- START */
    @objc
    func foo(number_1: Foundation.NSNumber?, number_2: Foundation.NSNumber?, completion: @escaping (@Sendable (String?, Swift.Error?) -> Void)) -> Foundation.Progress {
        let progress: Foundation.Progress = .init(totalUnitCount: 1)
        
        let task: Task<Void, Never> = .init {
            
            let result: String???
            let error: Swift.Error?
            
            do {
                result = try await foo(number_1: number_1?.intValue, number_2: number_2?.intValue)
                error = nil
            } catch let _error {
                result = nil
                error = _error
            }
            
            progress.completedUnitCount = 1
            completion(((result) ?? nil) ?? nil, error)
        }
        
        progress.cancellationHandler = {
            task.cancel()
        }
        
        return progress
    }
    /* Expanded -- END */
}
```
