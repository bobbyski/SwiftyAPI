import Foundation

public enum SwiftEndpointGenerator {
    public static func generate(document: OpenAPIDocument, accessLevel: String = "public") -> String {
        let typeName = sanitizeTypeName(document.summary.title) + "Endpoint"
        let operations = document.summary.operations

        var lines: [String] = [
            "import Foundation",
            "",
            "\(accessLevel) enum \(typeName): String, CaseIterable {"
        ]

        for operation in operations {
            let caseName = sanitizeCaseName(operation.operationID ?? "\(operation.method.rawValue) \(operation.path)")
            lines.append("    case \(caseName) = \"\(operation.method.rawValue.uppercased()) \(operation.path)\"")
        }

        if operations.isEmpty {
            lines.append("    // No operations were found in this OpenAPI document.")
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func sanitizeTypeName(_ value: String) -> String {
        let words = value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        let joined = words.map { word in
            word.prefix(1).uppercased() + word.dropFirst()
        }.joined()

        return joined.isEmpty ? "OpenAPI" : joined
    }

    private static func sanitizeCaseName(_ value: String) -> String {
        if value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            let first = value.prefix(1).lowercased()
            let rest = value.dropFirst()
            let proposed = first + rest
            if proposed.first?.isNumber == true {
                return "operation\(proposed.prefix(1).uppercased())\(proposed.dropFirst())"
            }
            return proposed
        }

        let words = value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        guard let first = words.first else {
            return "operation"
        }

        let rest = words.dropFirst().map { word in
            word.prefix(1).uppercased() + word.dropFirst()
        }

        let proposed = ([first.lowercased()] + rest).joined()
        if proposed.first?.isNumber == true {
            return "operation\(proposed.prefix(1).uppercased())\(proposed.dropFirst())"
        }

        return proposed
    }
}
