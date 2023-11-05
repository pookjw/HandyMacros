import SwiftSyntax
import SwiftSyntaxMacros

extension VariableDeclSyntax {
    func accessorsMatching(_ predicate: (TokenKind) -> Bool) -> [AccessorDeclSyntax] {
        let accessors: [AccessorDeclListSyntax.Element] = bindings
            .map { $0 as PatternBindingSyntax }
            .compactMap { patternBinding in
                switch patternBinding.accessorBlock?.accessors {
                case .accessors(let accessors):
                    accessors
                default:
                    nil
                }
            }
            .flatMap { $0 }
        
        return accessors
            .compactMap { accessor in
                guard let decl: AccessorDeclSyntax = accessor.as(AccessorDeclSyntax.self) else {
                    return nil
                }
                
                if predicate(decl.accessorSpecifier.tokenKind) {
                    return decl
                } else {
                    return nil
                }
            }
        
    }
    
    var isComputed: Bool {
        if !accessorsMatching({ $0 == .keyword(.get) }).isEmpty {
            return true
        } else {
            return bindings
                .contains { binding in
                    if case .getter = binding.accessorBlock?.accessors {
                        return true
                    } else {
                        return false
                    }
                }
        }
    }
    
    var isImmutable: Bool {
        bindingSpecifier.tokenKind == .keyword(.let)
    }
    
    var isInstance: Bool {
        for modifier in modifiers {
            for token in modifier.tokens(viewMode: .all) {
                if token.tokenKind == .keyword(.static) || token.tokenKind == .keyword(.class) {
                    return false
                }
            }
        }
        
        return true
    }
    
    var name: String? {
        guard
            let identifierPatters: IdentifierPatternSyntax = bindings
            .first?
            .pattern
            .as(IdentifierPatternSyntax.self)
        else {
            return nil
        }
        
        let identifier: TokenSyntax = identifierPatters.identifier
        
        return identifier.text
    }
    
    var type: TypeSyntax? {
        bindings.first?.typeAnnotation?.type
    }
    
    func hasMacroApplication(name: String) -> Bool {
        for attribute in attributes {
            switch attribute {
            case .attribute(let attribute):
                if attribute.attributeName.tokens(viewMode: .all).first(where: { $0.tokenKind == .identifier(name) }) != nil {
                    return true
                } else {
                    continue
                }
            default:
                return false
            }
        }
        
        return false
    }
}
