import SwiftSyntax

extension TypeSyntax {
    var isNumeric: Bool {
        guard let identifierTypeSyntax: IdentifierTypeSyntax = self.as(IdentifierTypeSyntax.self) else {
            return false
        }
        
        let numericTypes: [String] = [
            "Int",
            "Int8",
            "Int16",
            "Int32",
            "Int64",
            "UInt",
            "UInt8",
            "UInt16",
            "UInt32",
            "UInt64",
            "Double",
            "Float",
            "Bool"
        ]
        
        return numericTypes.first(where: { identifierTypeSyntax.name.text.hasSuffix($0) }) != nil
    }
    
    var wrappedValue: (TypeSyntax, Int) {
        var optionalCount: Int = .zero
        var typeSyntax: TypeSyntax = self
        while let optionalSyntax: OptionalTypeSyntax = typeSyntax.as(OptionalTypeSyntax.self) {
            typeSyntax = optionalSyntax.wrappedType
            optionalCount += 1
        }
        
        return (typeSyntax, optionalCount)
    }
}
