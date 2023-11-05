import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct AddCancellationToWillSetMacro: AccessorMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AccessorDeclSyntax] {
        guard let variableProperty: VariableDeclSyntax = declaration.as(VariableDeclSyntax.self) else {
            throw CustomError.message("can only apply to variables")
        }
        
        guard let variableProperty: VariableDeclSyntax = declaration.as(VariableDeclSyntax.self) else {
            throw CustomError.message("can only apply to variables")
        }
        
        guard
            let name: String = variableProperty.name,
            let type: TypeSyntax = variableProperty.type
        else {
            return []
        }
        
        let isOptional: Bool = type.is(OptionalTypeSyntax.self)
        
        let willSetAccessor: AccessorDeclSyntax = """
        willSet {
            \(raw: name + (isOptional ? "?" : "")).cancel()
        }
        """
        
        return [willSetAccessor]
    }
}
