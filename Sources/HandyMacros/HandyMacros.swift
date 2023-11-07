import Foundation

@attached(peer, names: overloaded)
public macro AddObjCCompletionHandler(parameterName: String = "completionHandler", selectorName: String? = nil) = #externalMacro(module: "HandyMacrosExternal", type: "AddObjCCompletionHandlerMacro")

@attached(accessor, names: named(willSet))
public macro AddCancellationToWillSet() = #externalMacro(module: "HandyMacrosExternal", type: "AddCancellationToWillSetMacro")
