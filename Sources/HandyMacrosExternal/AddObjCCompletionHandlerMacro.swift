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
        let selectorName: String? = node.stringArgument(for: "selectorName")
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
            if wrappedReturnType == "Void" {
                "@escaping (Error?) -> Void"
            } else {
                "@escaping (\(wrappedReturnType)?, Error?) -> Void"
            }
        } else {
            if wrappedReturnType == "Void" {
                "@escaping () -> Void"
            } else {
                "@escaping (\(wrappedReturnType)?) -> Void"
            }
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
            let argName = param.secondName ?? param.firstName
            
            let paramName = param.firstName
            if paramName.text != "_" {
                return "\(paramName.text): \(argName.text)"
            }
            
            return "\(argName.text)"
        }
        let call: ExprSyntax = "\(funcDecl.name)(\(raw: callArguments.joined(separator: ", ")))"
        
        let newBody: ExprSyntax = if wrappedReturnType == "Void" {
            """
            
                let progress: Foundation.Progress = .init(totalUnitCount: 1)
                
                let task: Task<Void, Never> = .init {
                    let error: Error?
                    
                    do {
                        try await \(call)
                        error = nil
                    } catch let _error {
                        error = _error
                    }
                    
                    progress.completedUnitCount = 1
                    \(raw: completionParameterName)(error)
                }
                
                progress.cancellationHandler = {
                    task.cancel()
                }
                
                return progress
            """
        } else {
            """
            
                let progress: Foundation.Progress = .init(totalUnitCount: 1)
                
                let task: Task<Void, Never> = .init {
                    let result: \(raw: wrappedReturnType)?
                    let error: Error?
                    
                    do {
                        result = try await \(call)
                        error = nil
                    } catch let _error {
                        result = nil
                        error = _error
                    }
                    
                    progress.completedUnitCount = 1
                    \(raw: completionParameterName)(result, error)
                }
                
                progress.cancellationHandler = {
                    task.cancel()
                }
                
                return progress
            """
        }
        
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
