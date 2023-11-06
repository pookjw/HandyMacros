import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

public struct AddObjCCompletionHandlerMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard var funcDecl: FunctionDeclSyntax = declaration.as(FunctionDeclSyntax.self) else {
            throw CustomError.message("@AddClangCompletionHandler only works on functions")
        }
        
        if let requiresAsyncSpecifier: Diagnostic = requiresAsyncSpecifier(funcDecl: funcDecl) {
            context.diagnose(requiresAsyncSpecifier)
            return []
        }
        
        let completionParameterName: String = node.stringArgument(for: "parameterName") ?? "completion"
        let selectorName: String? = node.stringArgument(for: "selectorName")
        let doesThrow: Bool = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let (unwrappedReturnType, optionalCount, isNumeric): (String, Int, Bool) = {
            guard let returnTypeSyntax: TypeSyntax = funcDecl.signature.returnClause?.type else {
                return nil
            }
            
            let (typeSyntax, optionalCount): (TypeSyntax, Int) = returnTypeSyntax.wrappedValue
            
            guard
                let identifierSyntax: IdentifierTypeSyntax = typeSyntax.as(IdentifierTypeSyntax.self) else {
                return nil
            }
            
            let originalReturnType: String = identifierSyntax.name.text
            
            return (originalReturnType, optionalCount, typeSyntax.isNumeric)
        }() ?? ("Void", .zero, false)
        let originalReturnType: String = {
            var result: String = unwrappedReturnType
            for _ in 0..<optionalCount {
                result += "?"
            }
            return result
        }()
        
        let completionParameterType: String = if doesThrow {
            if unwrappedReturnType == "Void" {
                "@escaping (@Sendable (Swift.Error?) -> Void)"
            } else if isNumeric {
                "@escaping (@Sendable (Foundation.NSNumber?, Swift.Error?) -> Void)"
            } else {
                "@escaping (@Sendable (\(unwrappedReturnType)?, Swift.Error?) -> Void)"
            }
        } else {
            if unwrappedReturnType == "Void" {
                "@escaping () -> Void"
            } else if isNumeric {
                "@escaping (Foundation.NSNumber?) -> Void"
            } else {
                "@escaping (\(unwrappedReturnType)?) -> Void"
            }
        }
        
        //
        
        let oldParameters: FunctionParameterListSyntax = funcDecl.signature.parameterClause.parameters
        var newParameters: FunctionParameterListSyntax = oldParameters
        
        for newParameter in newParameters {
            guard newParameter.type.is(OptionalTypeSyntax.self) else {
                continue
            }
            
            var targetSyntax: TypeSyntax = newParameter.type
            
            // unwrap multiple optionals...
            while let optioalTypeSyntax: OptionalTypeSyntax = targetSyntax.as(OptionalTypeSyntax.self) {
                targetSyntax = optioalTypeSyntax.wrappedType
            }
            
            guard
                targetSyntax.isNumeric,
                let index: SyntaxChildrenIndex = oldParameters.index(of: newParameter)
            else {
                continue
            }
            
            newParameters[index].type = .init(stringLiteral: "Foundation.NSNumber?")
        }
        
        let completionParameter: FunctionParameterSyntax = .init(
            firstName: .identifier(completionParameterName),
            colon: .colonToken(trailingTrivia: .space),
            type: TypeSyntax(stringLiteral: completionParameterType)
        )
        
        if
            var lastParameter: FunctionParameterListSyntax.Element = newParameters.last,
            let lastIndex: SyntaxChildrenIndex = newParameters.index(of: lastParameter)
        {
            newParameters.remove(at: lastIndex)
            lastParameter.trailingComma = .commaToken(trailingTrivia: .space)
            newParameters.append(lastParameter)
            newParameters.append(completionParameter)
        } else {
            newParameters.append(completionParameter)
        }
        
        funcDecl.signature.parameterClause.parameters = newParameters
        
        //
        
        funcDecl.signature.effectSpecifiers?.asyncSpecifier = nil
        funcDecl.signature.effectSpecifiers?.throwsSpecifier = nil
        
        //
        
        let returnTypeSyntax: TypeSyntax = .init(IdentifierTypeSyntax(name: .identifier("Foundation.Progress")))
        if var existingReturnSyntax: ReturnClauseSyntax = funcDecl.signature.returnClause?.as(ReturnClauseSyntax.self) {
            existingReturnSyntax.type = returnTypeSyntax
            funcDecl.signature.returnClause = existingReturnSyntax
        } else {
            funcDecl.signature.returnClause = .init(type: returnTypeSyntax)
        }
        
        //
        
       funcDecl.attributes.removeCurrentMacroAttribute(node: node)
        
        let objcAttributeString: String
        if let selectorName: String {
            objcAttributeString = "@objc(\(selectorName))"
        } else {
            objcAttributeString = "@objc"
        }
        let syntax: AttributeListSyntax = .init(stringLiteral: objcAttributeString)
        funcDecl.attributes.append(contentsOf: syntax)
        
        //
        
        let callArguments: [String] = oldParameters.map { param in
            let valName: String = {
                let argName: String = (param.secondName ?? param.firstName).text
                
                let (typeSyntax, optionalCount): (TypeSyntax, Int) = param.type.wrappedValue
                
                guard typeSyntax.isNumeric else {
                    return argName
                }
                
                guard let identifierTypeSyntax: IdentifierTypeSyntax = typeSyntax.as(IdentifierTypeSyntax.self) else {
                    return argName
                }
                
                let typeName: String = identifierTypeSyntax.name.text
                
                let conversionMethod: String = {
                    if typeName.hasSuffix("UInt") {
                        "uintValue"
                    } else if typeName.hasSuffix("UInt8") {
                        "uint8Value"
                    } else if typeName.hasSuffix("UInt16") {
                        "uint16Value"
                    } else if typeName.hasSuffix("UInt32") {
                        "uint32Value"
                    } else if typeName.hasSuffix("UInt64") {
                        "uint64Value"
                    } else if typeName.hasSuffix("Int") {
                        "intValue"
                    } else if typeName.hasSuffix("Int8") {
                        "int8Value"
                    } else if typeName.hasSuffix("Int16") {
                        "int16Value"
                    } else if typeName.hasSuffix("Int32") {
                        "int32Value"
                    } else if typeName.hasSuffix("Int64") {
                        "int64Value"
                    } else {
                        "intValue"
                    }
                }()
                
                if optionalCount == .zero {
                    return "\(argName).\(conversionMethod)"
                } else {
                    return "\(argName)?.\(conversionMethod)"
                }
            }()
            
            
            let paramName: String = param.firstName.text
            if paramName != "_" {
                return "\(paramName): \(valName)"
            }
            
            return "\(valName)"
        }
        let call: ExprSyntax = "\(funcDecl.name)(\(raw: callArguments.joined(separator: ", ")))"
        
        var prefixCoalescingNils: String = .init()
        var suffixCoalescingNils: String = .init()
        for _ in 0..<optionalCount {
            prefixCoalescingNils = "(" + prefixCoalescingNils
            suffixCoalescingNils += ") ?? nil"
        }
        
        let resultDeclaration: String = switch (unwrappedReturnType, isNumeric, doesThrow) {
        case ("Void", _, false):
            """
            
                    await \(call)
                    progress.completedUnitCount = 1
                    \(completionParameterName)()
            """
        case ("Void", _, true):
            """
            
                    let error: Swift.Error?
                    
                    do {
                        try await \(call)
                        error = nil
                    } catch let _error {
                        error = _error
                    }
                    
                    progress.completedUnitCount = 1
                    \(completionParameterName)(error)
            """
        case (_, true, false):
            """
            
                    let result: Foundation.NSNumber? = await .init(integerLiteral: \(call))
                    progress.completedUnitCount = 1
                    \(completionParameterName)(result)
            """
        case (_, true, true):
            """
            
                    let result: Foundation.NSNumber?
                    let error: Swift.Error?
                    
                    do {
                        result = try await .init(integerLiteral: \(call))
                        error = nil
                    } catch let _error {
                        result = nil
                        error = _error
                    }
                    
                    progress.completedUnitCount = 1
                    \(completionParameterName)(result, error)
            """
        case (_, _, false):
            """
            
                    let result: \(originalReturnType)? = await \(call)
                    progress.completedUnitCount = 1
                    \(completionParameterName)(\(prefixCoalescingNils)result\(suffixCoalescingNils))
            """
        default:
            """
            
                    let result: \(originalReturnType)?
                    let error: Swift.Error?
                    
                    do {
                        result = try await \(call)
                        error = nil
                    } catch let _error {
                        result = nil
                        error = _error
                    }
                    
                    progress.completedUnitCount = 1
                    \(completionParameterName)(\(prefixCoalescingNils)result\(suffixCoalescingNils), error)
            """
        }
        
        let newBody: ExprSyntax = """
        
            let progress: Foundation.Progress = .init(totalUnitCount: 1)
            
            let task: Task<Void, Never> = .init {
                \(raw: resultDeclaration)
            }
            
            progress.cancellationHandler = {
                task.cancel()
            }
            
            return progress
        """
        
        funcDecl.body = CodeBlockSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            statements: CodeBlockItemListSyntax(
                [
                    CodeBlockItemSyntax(item: .expr(newBody))
                ]
            ),
            rightBrace: .rightBraceToken(leadingTrivia: .newline)
        )
        
        //
        
        return [.init(funcDecl)]
    }
    
    private static func requiresAsyncSpecifier(funcDecl: FunctionDeclSyntax) -> Diagnostic? {
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier == nil else {
            return nil
        }
        
        var newEffects: FunctionEffectSpecifiersSyntax
        if let existingEffects: FunctionEffectSpecifiersSyntax = funcDecl.signature.effectSpecifiers {
            newEffects = existingEffects
            newEffects.asyncSpecifier = .keyword(.async)
        } else {
            newEffects = .init(asyncSpecifier: .keyword(.async))
        }
        
        var newSignature: FunctionSignatureSyntax = funcDecl.signature
        newSignature.effectSpecifiers = newEffects
        
        let messageID = MessageID(domain: "HandyMacro", id: "addAsyncSpecifier")
        
        let diagnostic: Diagnostic = .init(
            // Where the error should go
            node: Syntax(funcDecl.funcKeyword),
            position: nil,
            message: SimpleDiagnosticMessage(
                message: "can only add a completion-handler variant to an 'async' function",
                diagnosticID: messageID,
                severity: .error
            ),
            highlights: nil,
            notes: [],
            fixIts: [
                .init(
                    message: SimpleDiagnosticMessage(
                        message: "add `async`",
                        diagnosticID: messageID,
                        severity: .error
                    ),
                    changes: [
                        .replace(
                            oldNode: .init(funcDecl.signature),
                            newNode: .init(newSignature)
                        )
                    ]
                )
            ]
        )
        
        return diagnostic
    }
}
