import SwiftSyntax
import SwiftSyntaxMacros

extension AttributeSyntax {
    func argumentExprSyntax<T: SyntaxProtocol>(name: String, syntaxType: T.Type = T.self) -> T? {
        arguments?
            .as(LabeledExprListSyntax.self)?
            .first(where: { $0.label?.text == name })?
            .as(T.self)
    }
    
    func stringArgument(for name: String) -> String? {
        guard
            let stringExprSyntax: StringLiteralExprSyntax = argumentExprSyntax(name: name),
            case let .stringSegment(result)? = stringExprSyntax.segments.first
        else {
            return nil
        }
        
        return result.content.description
    }
}
