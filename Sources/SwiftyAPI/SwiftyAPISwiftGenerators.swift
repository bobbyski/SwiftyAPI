import Foundation

public struct SwiftyAPIURLSessionClientGenerator: SwiftyAPICodeGenerator {
    public let name = "Swift URLSession Client"
    public let description = "Generates a Swift client that uses Foundation URLSession for transport, Codable models for JSON payloads, and async/await methods for each operation."
    public let language = "Swift"
    public let variation = "URLSession"
    public let type = "client"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.client, .model, .request, .support]

    public init() {}

    public func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPISwiftGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(
            files: [
                SwiftyAPIGeneratedFile(path: "Generated/Models.swift", kind: .model, contents: helper.modelsSource(imports: "import Foundation")),
                SwiftyAPIGeneratedFile(path: "Generated/APIClient.swift", kind: .client, contents: clientSource(helper: helper))
            ],
            diagnostics: helper.diagnostics
        )
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPISwiftGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation
        let methodName = helper.methodName(for: operation)
        let bodyArgument = operation.requestBody == nil ? "" : "body: \(helper.requestTypeName(for: operation))(/* TODO */)"
        let responseLine: String
        if helper.responseTypeName(for: operation) == nil {
            responseLine = "try await client.\(methodName)(\(bodyArgument))"
        } else {
            responseLine = "let response = try await client.\(methodName)(\(bodyArgument))"
        }
        let referencedModels = helper.methodReferencedModelsSource()

        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            let client = \(helper.clientTypeName)(baseURL: URL(string: "\(context.serverURL ?? "https://api.example.com")")!)
            \(responseLine)
            \(referencedModels)
            """,
            responseExample: helper.responseModelObjectExample(for: operation, prefix: "let response = ") ?? "HTTP 204 / empty response"
        )
    }

    private func clientSource(helper: SwiftyAPISwiftGeneratorHelper) -> String {
        var lines: [String] = [
            "import Foundation",
            "",
            "\(helper.accessLevel) struct \(helper.clientTypeName) {",
            "    \(helper.accessLevel) var baseURL: URL",
            "    \(helper.accessLevel) var session: URLSession",
            "    \(helper.accessLevel) var decoder: JSONDecoder",
            "    \(helper.accessLevel) var encoder: JSONEncoder",
            "",
            "    \(helper.accessLevel) init(",
            "        baseURL: URL,",
            "        session: URLSession = .shared,",
            "        decoder: JSONDecoder = JSONDecoder(),",
            "        encoder: JSONEncoder = JSONEncoder()",
            "    ) {",
            "        self.baseURL = baseURL",
            "        self.session = session",
            "        self.decoder = decoder",
            "        self.encoder = encoder",
            "    }",
            ""
        ]

        if helper.operations.isEmpty {
            lines.append("    // No operations were found in this OpenAPI document.")
        }

        for operation in helper.operations {
            lines.append(methodSource(operation: operation, helper: helper))
            lines.append("")
        }

        lines += [
            "    private func makeURL(path: String, queryItems: [URLQueryItem]) -> URL {",
            "        var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: \"/\"))), resolvingAgainstBaseURL: false)!",
            "        components.queryItems = queryItems.isEmpty ? nil : queryItems",
            "        return components.url!",
            "    }",
            "}",
            ""
        ]

        return lines.joined(separator: "\n")
    }

    private func methodSource(operation: OpenAPIOperation, helper: SwiftyAPISwiftGeneratorHelper) -> String {
        let requestType = operation.requestBody.map { _ in helper.requestTypeName(for: operation) }
        let responseType = helper.responseTypeName(for: operation)
        let returnType = responseType ?? "Void"
        let bodyParameter = requestType.map { ", body: \($0)" } ?? ""
        let queryItems = operation.parameters
            .filter { $0.location == "query" }
            .map { "URLQueryItem(name: \"\($0.name)\", value: nil)" }
            .joined(separator: ", ")
        let contentType = operation.requestBody?.contentTypes.first ?? "application/json"

        var lines: [String] = [
            "    \(helper.accessLevel) func \(helper.methodName(for: operation))(\(bodyParameter.dropFirst(2))) async throws -> \(returnType) {",
            "        let url = makeURL(path: \"\(operation.path)\", queryItems: [\(queryItems)])",
            "        var request = URLRequest(url: url)",
            "        request.httpMethod = \"\(operation.method.rawValue.uppercased())\""
        ]

        if requestType != nil {
            lines += [
                "        request.setValue(\"\(contentType)\", forHTTPHeaderField: \"Content-Type\")",
                "        request.httpBody = try encoder.encode(body)"
            ]
        }

        lines += [
            "        let (data, response) = try await session.data(for: request)",
            "        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {",
            "            throw \(helper.clientTypeName)Error.unexpectedStatusCode",
            "        }"
        ]

        if let responseType {
            lines.append("        return try decoder.decode(\(responseType).self, from: data)")
        }

        lines.append("    }")
        return lines.joined(separator: "\n")
    }
}

public struct SwiftyAPIVaporServerGenerator: SwiftyAPICodeGenerator {
    public let name = "Swift Vapor Server"
    public let description = "Generates Swift server scaffolding for Vapor, including route registration, request DTOs, response DTOs, and handler stubs for each OpenAPI operation."
    public let language = "Swift"
    public let variation = "Vapor"
    public let type = "server"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.model, .request, .support]

    public init() {}

    public func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPISwiftGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(
            files: [
                SwiftyAPIGeneratedFile(path: "Generated/VaporModels.swift", kind: .model, contents: helper.modelsSource(imports: "import Vapor")),
                SwiftyAPIGeneratedFile(path: "Generated/VaporRoutes.swift", kind: .support, contents: routesSource(helper: helper))
            ],
            diagnostics: helper.diagnostics
        )
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPISwiftGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation
        let referencedModels = helper.methodReferencedModelsSource()
        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            app.\(operation.method.rawValue)(\(helper.vaporPathSegments(for: operation))) { request async throws -> \(helper.responseTypeName(for: operation) ?? "HTTPStatus") in
                try await handlers.\(helper.methodName(for: operation))(request)
            }
            \(referencedModels)
            """,
            responseExample: helper.responseModelObjectExample(for: operation, prefix: "return ") ?? "return .noContent"
        )
    }

    private func routesSource(helper: SwiftyAPISwiftGeneratorHelper) -> String {
        var lines: [String] = [
            "import Vapor",
            "",
            "\(helper.accessLevel) protocol \(helper.serverTypeName)Handlers {"
        ]

        if helper.operations.isEmpty {
            lines.append("    // No operations were found in this OpenAPI document.")
        } else {
            for operation in helper.operations {
                lines.append("    func \(helper.methodName(for: operation))(_ request: Request) async throws -> \(helper.responseTypeName(for: operation) ?? "HTTPStatus")")
            }
        }

        lines += [
            "}",
            "",
            "\(helper.accessLevel) func register\(helper.serverTypeName)Routes(_ app: RoutesBuilder, handlers: any \(helper.serverTypeName)Handlers) throws {"
        ]

        for operation in helper.operations {
            lines += [
                "    app.\(operation.method.rawValue)(\(helper.vaporPathSegments(for: operation))) { request async throws -> \(helper.responseTypeName(for: operation) ?? "HTTPStatus") in",
                "        try await handlers.\(helper.methodName(for: operation))(request)",
                "    }"
            ]
        }

        lines += [
            "}",
            ""
        ]

        return lines.joined(separator: "\n")
    }
}

private struct SwiftyAPISwiftGeneratorHelper {
    var title: String
    var operations: [OpenAPIOperation]
    var options: SwiftyAPIGeneratorOptions
    var diagnostics: [SwiftyAPIGeneratorDiagnostic] = []

    init(document: OpenAPIDocument, options: SwiftyAPIGeneratorOptions) {
        self.title = document.summary.title
        self.operations = document.summary.operations
        self.options = options
    }

    init(title: String, operations: [OpenAPIOperation], options: SwiftyAPIGeneratorOptions) {
        self.title = title
        self.operations = operations
        self.options = options
    }

    var accessLevel: String {
        options.accessLevel.rawValue
    }

    var clientTypeName: String {
        "\(typeName(title))Client"
    }

    var serverTypeName: String {
        "\(typeName(title))Server"
    }

    func modelsSource(imports: String) -> String {
        var lines: [String] = [
            imports,
            ""
        ]

        let models = modelDefinitions()
        if models.isEmpty {
            lines.append("// No request or response models were found in this OpenAPI document.")
        } else {
            lines.append(contentsOf: models)
        }

        lines += [
            "",
            "\(accessLevel) enum \(clientTypeName)Error: Error {",
            "    case unexpectedStatusCode",
            "}",
            ""
        ]

        return lines.joined(separator: "\n")
    }

    func modelDefinitions() -> [String] {
        var definitions: [String] = []
        var emitted = Set<String>()

        for operation in operations {
            if let requestBody = operation.requestBody {
                appendModel(name: requestTypeName(for: operation), fields: requestBody.schemaFields, to: &definitions, emitted: &emitted)
            }

            if let response = operation.responses.first(where: { $0.schemaFields.isEmpty == false }),
               let responseName = responseTypeName(for: operation) {
                appendModel(name: responseName, fields: response.schemaFields, to: &definitions, emitted: &emitted)
            }
        }

        return definitions
    }

    func methodReferencedModelsSource() -> String {
        let definitions = modelDefinitions()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard definitions.isEmpty == false else {
            return ""
        }

        return """

        // Referenced models
        \(definitions.joined(separator: "\n\n"))
        """
    }

    func methodName(for operation: OpenAPIOperation) -> String {
        variableName(operation.operationID ?? "\(operation.method.rawValue) \(operation.path)")
    }

    func requestTypeName(for operation: OpenAPIOperation) -> String {
        operation.requestBody?.schemaName.map(typeName) ?? "\(typeName(methodName(for: operation)))Request"
    }

    func responseTypeName(for operation: OpenAPIOperation) -> String? {
        guard let response = operation.responses.first(where: { $0.schemaFields.isEmpty == false }) else {
            return nil
        }
        return response.schemaName.map(typeName) ?? "\(typeName(methodName(for: operation)))Response"
    }

    func responseModelObjectExample(for operation: OpenAPIOperation, prefix: String) -> String? {
        guard let response = operation.responses.first(where: { $0.schemaFields.isEmpty == false }),
              let responseType = responseTypeName(for: operation) else {
            return nil
        }

        if response.schemaFields.isEmpty {
            return "\(prefix)\(responseType)()"
        }

        let fieldLines = response.schemaFields.map { field in
            "    \(variableName(field.name)): \(exampleValue(for: field))"
        }

        return """
        \(prefix)\(responseType)(
        \(fieldLines.joined(separator: ",\n"))
        )
        """
    }

    func vaporPathSegments(for operation: OpenAPIOperation) -> String {
        let segments = operation.path
            .split(separator: "/")
            .map { segment -> String in
                if segment.hasPrefix("{"), segment.hasSuffix("}") {
                    let name = segment.dropFirst().dropLast()
                    return "\":\(name)\""
                }
                return "\"\(segment)\""
            }
        return segments.isEmpty ? "\"\"" : segments.joined(separator: ", ")
    }

    private func appendModel(name: String, fields: [OpenAPISchemaField], to definitions: inout [String], emitted: inout Set<String>) {
        guard emitted.insert(name).inserted else {
            return
        }

        var lines: [String] = [
            "\(accessLevel) struct \(name): Codable, Sendable {"
        ]

        if fields.isEmpty {
            lines.append("    // Schema fields were not available in the parsed OpenAPI document.")
        } else {
            for field in fields {
                let optional = field.isRequired ? "" : "?"
                lines.append("    \(accessLevel) var \(variableName(field.name)): \(swiftType(for: field))\(optional)")
            }
        }

        lines.append("}")
        definitions.append(lines.joined(separator: "\n"))
        definitions.append("")
    }

    private func swiftType(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        if type.contains("boolean") { return "Bool" }
        if type.contains("int64") { return "Int64" }
        if type.contains("integer") { return "Int" }
        if type.contains("float") { return "Float" }
        if type.contains("number") || type.contains("double") { return "Double" }
        if type.contains("array") || type.hasPrefix("[") { return "[String]" }
        if type.contains("object") { return "[String: String]" }
        if type.contains("date") {
            switch options.dateStrategy {
            case .date:
                return "Date"
            case .string:
                return "String"
            }
        }
        return "String"
    }

    private func exampleValue(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        let name = field.name.lowercased()

        if type.contains("boolean") { return "true" }
        if type.contains("integer") || type.contains("int64") { return "0" }
        if type.contains("float") { return "0.0" }
        if type.contains("number") || type.contains("double") { return "0.0" }
        if type.contains("array") || type.hasPrefix("[") { return "[]" }
        if type.contains("object") { return "[:]" }
        if type.contains("date") || name.contains("date") || name.contains("time") {
            switch options.dateStrategy {
            case .date:
                return "Date(timeIntervalSince1970: 0)"
            case .string:
                return "\"2026-05-05T00:00:00Z\""
            }
        }
        return "\"\(field.name)\""
    }

    private func typeName(_ value: String) -> String {
        let words = value.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let joined = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return joined.isEmpty ? "OpenAPI" : (joined.first?.isNumber == true ? "OpenAPI\(joined)" : joined)
    }

    private func variableName(_ value: String) -> String {
        let type = typeName(value)
        let proposed = type.prefix(1).lowercased() + type.dropFirst()
        if ["class", "struct", "enum", "protocol", "extension", "func", "let", "var", "import", "return"].contains(proposed) {
            return "`\(proposed)`"
        }
        return proposed
    }
}
