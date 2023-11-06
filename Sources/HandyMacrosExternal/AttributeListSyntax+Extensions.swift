import SwiftSyntax
import SwiftSyntaxMacros

extension AttributeListSyntax {
    @discardableResult
    mutating func removeCurrentMacroAttribute(node: SwiftSyntax.AttributeSyntax) -> [IdentifierTypeSyntax] {
        guard let nodeType: IdentifierTypeSyntax = node.attributeName.as(IdentifierTypeSyntax.self) else {
            return []
        }
        
        var filteredSyntaxs: [IdentifierTypeSyntax] = .init()
        
        self = filter { attribute in
            guard
                case let .attribute(attribute) = attribute,
                let attributeType: IdentifierTypeSyntax = attribute.attributeName.as(IdentifierTypeSyntax.self),
                attributeType.name.text == nodeType.name.text
            else {
                return true
            }
            
            filteredSyntaxs.append(attributeType)
            return false
        }
        
        return filteredSyntaxs
    }
}
