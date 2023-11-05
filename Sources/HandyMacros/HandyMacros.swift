import Foundation

@attached(peer, names: overloaded)
public macro addObjCCompletionHandler(parameterName: String = "completionHandler", selectorName: String? = nil) = #externalMacro(module: "HandyMacrosExternal", type: "AddObjCCompletionHandlerMacro")

@attached(accessor, names: named(willSet))
public macro addCancellationToWillSet() = #externalMacro(module: "HandyMacrosExternal", type: "AddCancellationToWillSetMacro")
