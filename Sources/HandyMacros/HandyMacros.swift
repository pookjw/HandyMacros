@attached(peer, names: overloaded)
public macro AddClangCompletionHandler(name: String = "completionHandler") = #externalMacro(module: "HandyMacrosExternal", type: "AddClangCompletionHandler")

@attached(accessor, names: named(willSet))
public macro addCancellationToWillSet() = #externalMacro(module: "HandyMacrosExternal", type: "AddCancellationToWillSetMacro")


