import SwiftSyntax
import SwiftSyntaxMacros

extension AttributeSyntax {
    func argumentExprSyntax(name: String) -> LabeledExprListSyntax.Element? {
        return arguments?
            .as(LabeledExprListSyntax.self)?
            .first(where: { $0.label?.as(TokenSyntax.self)?.text == name })
    }
    
    func stringArgument(for name: String) -> String? {
        guard
            let element: LabeledExprListSyntax.Element = argumentExprSyntax(name: name),
            case let .stringSegment(result)? = element.expression.as(StringLiteralExprSyntax.self)?.segments.first
        else {
            return nil
        }
        
        return result.content.text
    }
}
