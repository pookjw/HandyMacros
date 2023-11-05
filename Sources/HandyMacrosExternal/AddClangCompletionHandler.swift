import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct AddClangCompletionHandler: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard var funcDecl: FunctionDeclSyntax = declaration.as(FunctionDeclSyntax.self) else {
            throw CustomError.message("@AddClangCompletionHandler only works on functions")
        }
        
        guard 
            funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        else {
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
            
            context.diagnose(diagnostic)
            return []
        }
        
        //
        
        guard
            funcDecl
                .attributes
                .first(
                    where: { attribute in
                        guard let name: String = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text else {
                            return false
                        }
                        
                        
                        return name == "_silgen_name" || name == "_cdecl" || name == "objc"
                    }
                ) != nil
        else {
            let sligenNameAttributes: AttributeListSyntax = {
                var syntax: AttributeListSyntax = .init(stringLiteral: "@_silgen_name(\"<#\(funcDecl.name.text)#>\")")
                syntax.trailingTrivia = .spaces(1)
                
                var result: AttributeListSyntax = funcDecl.attributes
                if
                    var lastAttribute: AttributeListSyntax.Element = result.last,
                    let lastIndex: SyntaxChildrenIndex = result.lastIndex(of: lastAttribute)
                {
                    result.remove(at: lastIndex)
                    
                    lastAttribute.leadingTrivia = .spaces(.zero)
                    result.append(contentsOf: syntax)
                    result.append(lastAttribute)
                } else {
                    result.append(contentsOf: syntax)
                }
                
                return result
            }()
            
            let cDeclAttributes: AttributeListSyntax = {
                var syntax: AttributeListSyntax = .init(stringLiteral: "@_cdecl(\"<#\(funcDecl.name.text)#>\")")
                syntax.trailingTrivia = .spaces(1)
                
                var result: AttributeListSyntax = funcDecl.attributes
                if
                    var lastAttribute: AttributeListSyntax.Element = result.last,
                    let lastIndex: SyntaxChildrenIndex = result.lastIndex(of: lastAttribute)
                {
                    result.remove(at: lastIndex)
                    
                    lastAttribute.leadingTrivia = .spaces(.zero)
                    result.append(contentsOf: syntax)
                    result.append(lastAttribute)
                } else {
                    result.append(contentsOf: syntax)
                }
                
                return result
            }()
            
            let messageID = MessageID(domain: "HandyMacro", id: "addClangCompatibleAttribute")
            
            let diagnostic: Diagnostic = .init(
                // Where the error should go
                node: Syntax(funcDecl.funcKeyword),
                position: nil,
                message: SimpleDiagnosticMessage(
                    message: "can only add to a C-compatible function",
                    diagnosticID: messageID,
                    severity: .error
                ),
                highlights: nil,
                notes: [],
                fixIts: [
                    .init(
                        message: SimpleDiagnosticMessage(
                            message: "add `@_sligen_name`",
                            diagnosticID: messageID,
                            severity: .error
                        ),
                        changes: [
                            .replace(
                                oldNode: .init(funcDecl.attributes),
                                newNode: .init(sligenNameAttributes)
                            )
                        ]
                    )
                ]
            )
            
            context.diagnose(diagnostic)
            return []
        }
        
        //
        
        let oldParameters: FunctionParameterListSyntax = funcDecl.signature.parameterClause.parameters
        var newParameters: FunctionParameterListSyntax = oldParameters
        
        //
        
        let completionName: String
        if
            let firstElement = node.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "name" }),
            let stringLiteral = firstElement.expression.as(StringLiteralExprSyntax.self),
            case let .stringSegment(_completionName)? = stringLiteral.segments.first
        {
            completionName = _completionName.content.description
        } else {
            completionName = "completionHandler"
        }
        
        let resultType: TypeSyntax? = funcDecl.signature.returnClause?.type
        
        let completionHandlerParameter: FunctionParameterSyntax = .init(
            firstName: .identifier(completionName),
            colon: .colonToken(trailingTrivia: .space),
            type: "@escaping (\(resultType ?? "Void")) -> Void" as TypeSyntax
        )
        
        if 
            var lastParameter: FunctionParameterListSyntax.Element = newParameters.last,
            let lastIndex: SyntaxChildrenIndex = newParameters.index(of: lastParameter)
        {
            newParameters.remove(at: lastIndex)
            lastParameter.trailingComma = .commaToken(trailingTrivia: .space)
        } else {
            
        }
        
        return []
    }
}
