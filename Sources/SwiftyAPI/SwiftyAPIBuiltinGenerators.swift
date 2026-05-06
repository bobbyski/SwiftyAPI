import Foundation

public enum SwiftyAPIBuiltinGenerators {
    public static var all: [any SwiftyAPICodeGenerator] {
        [
            SwiftyAPICurlExampleGenerator(),
            SwiftyAPIURLSessionClientGenerator(),
            SwiftyAPIVaporServerGenerator(),
            SwiftyAPITemplateCodeGenerator(
                name: "TypeScript Axios Client",
                description: "Generates a TypeScript client that uses axios for HTTP transport, typed request parameters, typed response payloads, and operation functions.",
                language: "TypeScript",
                variation: "axios",
                type: "client",
                supportedOutputs: [.client, .model, .request, .support]
            ),
            SwiftyAPITemplateCodeGenerator(
                name: "TypeScript Node Server",
                description: "Generates TypeScript server scaffolding for Node.js, including route declarations, typed handler signatures, and request/response model types.",
                language: "TypeScript",
                variation: "node",
                type: "server",
                supportedOutputs: [.model, .request, .support]
            ),
            SwiftyAPITemplateCodeGenerator(
                name: "Python httpx Client",
                description: "Generates a Python client that uses httpx for sync or async HTTP transport and Pydantic models for typed request and response payloads.",
                language: "Python",
                variation: "httpx + Pydantic",
                type: "client",
                supportedOutputs: [.client, .model, .request, .support]
            ),
            SwiftyAPITemplateCodeGenerator(
                name: "Python FastAPI Server",
                description: "Generates Python server scaffolding for FastAPI, including routers, Pydantic request and response models, and handler stubs for each operation.",
                language: "Python",
                variation: "FastAPI + Pydantic",
                type: "server",
                supportedOutputs: [.model, .request, .support]
            ),
            SwiftyAPITemplateCodeGenerator(
                name: ".NET HttpClient Client",
                description: "Generates a C# client that uses HttpClient, System.Text.Json models, and task-based async methods for each OpenAPI operation.",
                language: "C#",
                variation: "HttpClient + System.Text.Json",
                type: "client",
                supportedOutputs: [.client, .model, .request, .support]
            ),
            SwiftyAPITemplateCodeGenerator(
                name: ".NET ASP.NET Core Server",
                description: "Generates C# server scaffolding for ASP.NET Core Minimal APIs, including endpoint mapping, request records, response records, and handler stubs.",
                language: "C#",
                variation: "ASP.NET Core Minimal API",
                type: "server",
                supportedOutputs: [.model, .request, .support]
            )
        ]
    }

    public static func registry() throws -> SwiftyAPICodeGeneratorRegistry {
        try SwiftyAPICodeGeneratorRegistry(generators: all)
    }
}

public struct SwiftyAPICurlExampleGenerator: SwiftyAPICodeGenerator {
    public let name = "cURL Examples"
    public let description = "Generates cURL request examples and JSON-like response examples for the selected operation in the design view."
    public let language = "cURL"
    public let variation = "Request and response examples"
    public let type = "client"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.support]

    public init() {}

    public func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        let examples = document.summary.operations.map { operation in
            let context = SwiftyAPIMethodGenerationContext(
                title: document.summary.title,
                version: document.summary.version,
                serverURL: document.summary.servers.first,
                operation: operation
            )
            let result = (try? generateMethod(from: context, options: options)) ?? SwiftyAPIMethodGeneratorResult()

            return """
            ## \(operation.id)

            ### Request

            ```bash
            \(result.requestExample)
            ```

            ### Response

            ```json
            \(result.responseExample)
            ```
            """
        }

        return SwiftyAPIGeneratorResult(
            files: [
                SwiftyAPIGeneratedFile(
                    path: "Examples/curl.md",
                    kind: .support,
                    contents: examples.joined(separator: "\n\n")
                )
            ]
        )
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        SwiftyAPIMethodGeneratorResult(
            requestExample: requestExample(for: context.operation, serverURL: context.serverURL),
            responseExample: responseExample(for: context.operation)
        )
    }

    private func requestExample(for operation: OpenAPIOperation, serverURL: String?) -> String {
        let baseURL = serverURL ?? "{{BASE_URL}}"
        let queryParameters = operation.parameters.filter { $0.location == "query" }
        let queryString = queryParameters.isEmpty ? "" : "?" + queryParameters.map { "\($0.name)={\($0.name)}" }.joined(separator: "&")
        let contentType = operation.requestBody?.contentTypes.first
        let bodyLine = operation.requestBody.map { " \\\n--data-raw '\(requestBodyExample(for: $0))'" } ?? ""
        let headerLine = contentType.map { " \\\n--header 'Content-Type: \($0)'" } ?? ""

        return """
        curl --location --request \(operation.method.rawValue.uppercased()) '\(baseURL)\(operation.path)\(queryString)'\(headerLine)\(bodyLine)
        """
    }

    private func requestBodyExample(for requestBody: OpenAPIRequestBody) -> String {
        guard requestBody.schemaFields.isEmpty == false else {
            return "{}"
        }

        let lines = requestBody.schemaFields.map { field in
            "  \"\(field.name)\": \(exampleValue(for: field))"
        }

        return """
        {
        \(lines.joined(separator: ",\n"))
        }
        """
    }

    private func responseExample(for operation: OpenAPIOperation) -> String {
        guard let response = operation.responses.first else {
            return "{}"
        }

        if response.statusCode == "204" || response.contentTypes.isEmpty {
            return "HTTP \(response.statusCode) \(response.description ?? "No Content")"
        }

        guard response.schemaFields.isEmpty == false else {
            return """
            {
              "status": "\(response.statusCode)",
              "description": "\(response.description ?? "Response")"
            }
            """
        }

        let lines = response.schemaFields.map { field in
            "  \"\(field.name)\": \(exampleValue(for: field))"
        }

        return """
        {
        \(lines.joined(separator: ",\n"))
        }
        """
    }

    private func exampleValue(for field: OpenAPISchemaField) -> String {
        let lowercasedName = field.name.lowercased()
        let lowercasedType = field.type.lowercased()

        if lowercasedType.hasPrefix("[") {
            return "[]"
        }

        if lowercasedType.contains("boolean") {
            return "true"
        }

        if lowercasedType.contains("integer") || lowercasedType.contains("number") {
            return "0"
        }

        if lowercasedType.contains("object") || lowercasedType.first?.isUppercase == true {
            return "{}"
        }

        if lowercasedName.contains("timestamp") || lowercasedName.contains("time") || lowercasedName.contains("date") {
            return "\"2026-05-05T00:00:00Z\""
        }

        return "\"\(field.name)\""
    }
}

public struct SwiftyAPITemplateCodeGenerator: SwiftyAPICodeGenerator {
    public var name: String
    public var description: String
    public var language: String
    public var variation: String
    public var type: String
    public var author: String
    public var supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind>

    public init(
        name: String,
        description: String,
        language: String,
        variation: String,
        type: String,
        author: String = "builtin",
        supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind>
    ) {
        self.name = name
        self.description = description
        self.language = language
        self.variation = variation
        self.type = type
        self.author = author
        self.supportedOutputs = supportedOutputs
    }

    public func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        SwiftyAPIGeneratorResult(
            files: [
                SwiftyAPIGeneratedFile(
                    path: "\(safePathComponent(name))/README.md",
                    kind: .support,
                    contents: """
                    # \(name)

                    \(description)

                    API: \(document.summary.title)
                    Version: \(document.summary.version)
                    Operations: \(document.summary.operations.count)

                    This generator is registered for selection, but its full code emitter has not been implemented yet.
                    """
                )
            ],
            diagnostics: [
                SwiftyAPIGeneratorDiagnostic(
                    severity: .info,
                    message: "\(name) is available in the catalog; full code generation is not implemented yet."
                )
            ]
        )
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let operation = context.operation
        let methodLine = "\(operation.method.rawValue.uppercased()) \(operation.path)"

        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            // \(name)
            // Request example placeholder for \(methodLine).
            """,
            responseExample: """
            // \(name)
            // Response example placeholder for \(methodLine).
            """,
            diagnostics: [
                SwiftyAPIGeneratorDiagnostic(
                    severity: .info,
                    message: "\(name) method examples are not implemented yet.",
                    sourcePath: "paths.\(operation.path).\(operation.method.rawValue)"
                )
            ]
        )
    }

    private func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
    }
}
