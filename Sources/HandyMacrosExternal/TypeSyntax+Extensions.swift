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
            "Float"
        ]
        
        return numericTypes.first(where: { identifierTypeSyntax.name.text.hasSuffix($0) }) != nil
    }
}
