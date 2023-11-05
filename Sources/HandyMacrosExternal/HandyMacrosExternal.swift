//
//  File.swift
//  
//
//  Created by Jinwoo Kim on 11/5/23.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct HandyMacrosExternal: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AddObjCCompletionHandlerMacro.self,
        AddCancellationToWillSetMacro.self
    ]
}
