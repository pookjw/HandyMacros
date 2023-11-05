import SwiftDiagnostics

enum CustomError: Error, CustomStringConvertible {
    case message(String)
    
    var description: String {
        switch self {
        case .message(let string):
            string
        }
    }
}

struct SimpleDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: SwiftDiagnostics.MessageID
    let severity: SwiftDiagnostics.DiagnosticSeverity
}

extension SimpleDiagnosticMessage: FixItMessage {
    var fixItID: SwiftDiagnostics.MessageID { diagnosticID }
}
