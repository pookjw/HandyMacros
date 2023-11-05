import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

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
        let selectorName: String = node.stringArgument(for: "selectorName") ?? funcDecl.name.text
        let doesThrow: Bool = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let wrappedReturnType: String = {
            var targetSyntax: TypeSyntax? = funcDecl.signature.returnClause?.type
            
            // unwrap multiple optionals...
            while let optioalTypeSyntax: OptionalTypeSyntax = targetSyntax?.as(OptionalTypeSyntax.self) {
                targetSyntax = optioalTypeSyntax.wrappedType
            }
            
            guard let identifierSyntax: IdentifierTypeSyntax = targetSyntax?.as(IdentifierTypeSyntax.self) else {
                return nil
            }
            
            return identifierSyntax.name.text
        }() ?? "Void"
        
        let completionParameterType: String = if doesThrow {
            "@escaping (\(wrappedReturnType)?, Error?) -> Void"
        } else {
            "@escaping (\(wrappedReturnType)?) -> Void"
        }
        
        //
        
        let oldParameters: FunctionParameterListSyntax = funcDecl.signature.parameterClause.parameters
        var newParameters: FunctionParameterListSyntax = oldParameters
        
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
        funcDecl.signature.effectSpecifiers?.asyncSpecifier = nil
//        funcDecl.signature.returnClause = nil // TODO: Progress
        // TODO: Remove attribute
        
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
    
//    private static func requiresAttributesDiagnostic(funcDecl: FunctionDeclSyntax) -> Diagnostic? {
//        guard
//            funcDecl
//                .attributes
//                .first(
//                    where: { attribute in
//                        guard let name: String = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text else {
//                            return false
//                        }
//                        
//                        
//                        return name == "_silgen_name" || name == "_cdecl" || name == "objc"
//                    }
//                ) == nil
//        else {
//            return nil
//        }
//        
//        let sligenNameAttributes: AttributeListSyntax = {
//            var syntax: AttributeListSyntax = .init(stringLiteral: "@_silgen_name(\"<#\(funcDecl.name.text)#>\")")
//            syntax.trailingTrivia = .spaces(1)
//            
//            var result: AttributeListSyntax = funcDecl.attributes
//            if
//                var lastAttribute: AttributeListSyntax.Element = result.last,
//                let lastIndex: SyntaxChildrenIndex = result.lastIndex(of: lastAttribute)
//            {
//                result.remove(at: lastIndex)
//                
//                lastAttribute.leadingTrivia = .spaces(.zero)
//                result.append(contentsOf: syntax)
//                result.append(lastAttribute)
//            } else {
//                result.append(contentsOf: syntax)
//            }
//            
//            return result
//        }()
//        
//        let cDeclAttributes: AttributeListSyntax = {
//            var syntax: AttributeListSyntax = .init(stringLiteral: "@_cdecl(\"<#\(funcDecl.name.text)#>\")")
//            syntax.trailingTrivia = .spaces(1)
//            
//            var result: AttributeListSyntax = funcDecl.attributes
//            if
//                var lastAttribute: AttributeListSyntax.Element = result.last,
//                let lastIndex: SyntaxChildrenIndex = result.lastIndex(of: lastAttribute)
//            {
//                result.remove(at: lastIndex)
//                
//                lastAttribute.leadingTrivia = .spaces(.zero)
//                result.append(contentsOf: syntax)
//                result.append(lastAttribute)
//            } else {
//                result.append(contentsOf: syntax)
//            }
//            
//            return result
//        }()
//        
//        let objcAttributes: AttributeListSyntax = {
//            var syntax: AttributeListSyntax = .init(stringLiteral: "@objc")
//            syntax.trailingTrivia = .spaces(1)
//            
//            var result: AttributeListSyntax = funcDecl.attributes
//            if
//                var lastAttribute: AttributeListSyntax.Element = result.last,
//                let lastIndex: SyntaxChildrenIndex = result.lastIndex(of: lastAttribute)
//            {
//                result.remove(at: lastIndex)
//                
//                lastAttribute.leadingTrivia = .spaces(.zero)
//                result.append(contentsOf: syntax)
//                result.append(lastAttribute)
//            } else {
//                result.append(contentsOf: syntax)
//            }
//            
//            return result
//        }()
//        
//        let messageID = MessageID(domain: "HandyMacro", id: "addClangCompatibleAttribute")
//        
//        let diagnostic: Diagnostic = .init(
//            // Where the error should go
//            node: Syntax(funcDecl.funcKeyword),
//            position: nil,
//            message: SimpleDiagnosticMessage(
//                message: "can only add to a C-compatible function",
//                diagnosticID: messageID,
//                severity: .error
//            ),
//            highlights: nil,
//            notes: [],
//            fixIts: [
//                .init(
//                    message: SimpleDiagnosticMessage(
//                        message: "add `@_sligen_name`",
//                        diagnosticID: messageID,
//                        severity: .error
//                    ),
//                    changes: [
//                        .replace(
//                            oldNode: .init(funcDecl.attributes),
//                            newNode: .init(sligenNameAttributes)
//                        )
//                    ]
//                ),
//                .init(
//                    message: SimpleDiagnosticMessage(
//                        message: "add `@_cdecl`",
//                        diagnosticID: messageID,
//                        severity: .error
//                    ),
//                    changes: [
//                        .replace(
//                            oldNode: .init(funcDecl.attributes),
//                            newNode: .init(cDeclAttributes)
//                        )
//                    ]
//                ),
//                .init(
//                    message: SimpleDiagnosticMessage(
//                        message: "add `@objc`",
//                        diagnosticID: messageID,
//                        severity: .error
//                    ),
//                    changes: [
//                        .replace(
//                            oldNode: .init(funcDecl.attributes),
//                            newNode: .init(objcAttributes)
//                        )
//                    ]
//                )
//            ]
//        )
//        
//        return diagnostic
//    }
}
