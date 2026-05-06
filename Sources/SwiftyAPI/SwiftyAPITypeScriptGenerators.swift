import Foundation

public struct SwiftyAPITypeScriptAxiosClientGenerator: SwiftyAPICodeGenerator {
    public let name = "TypeScript Axios Client"
    public let description = "Generates a TypeScript client that uses axios for HTTP transport, typed request parameters, typed response payloads, and operation functions."
    public let language = "TypeScript"
    public let variation = "axios"
    public let type = "client"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.client, .model, .request, .support]

    public init() {}

    public func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPITypeScriptGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(
            files: [
                SwiftyAPIGeneratedFile(path: "generated/models.ts", kind: .model, contents: helper.modelsSource()),
                SwiftyAPIGeneratedFile(path: "generated/client.ts", kind: .client, contents: clientSource(helper: helper))
            ],
            diagnostics: helper.diagnostics
        )
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPITypeScriptGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation
        let responsePrefix = helper.responseTypeName(for: operation) == nil ? "" : "const response = "

        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            const client = new \(helper.clientTypeName)("\(context.serverURL ?? "https://api.example.com")");
            \(responsePrefix)await client.\(helper.methodName(for: operation))(\(helper.methodCallArguments(for: operation)));
            \(helper.methodReferencedModelsSource())
            """,
            responseExample: helper.responseObjectExample(for: operation, prefix: "const response = ") ?? "HTTP 204 / empty response"
        )
    }

    private func clientSource(helper: SwiftyAPITypeScriptGeneratorHelper) -> String {
        var lines: [String] = [
            "import axios, { AxiosInstance } from \"axios\";",
            "import type { \(helper.modelTypeNames().joined(separator: ", ")) } from \"./models\";",
            "",
            "export class \(helper.clientTypeName) {",
            "  private readonly http: AxiosInstance;",
            "",
            "  constructor(baseURL: string, http?: AxiosInstance) {",
            "    this.http = http ?? axios.create({ baseURL });",
            "  }",
            ""
        ]

        if helper.operations.isEmpty {
            lines.append("  // No operations were found in this OpenAPI document.")
        }

        for operation in helper.operations {
            lines.append(methodSource(operation: operation, helper: helper))
            lines.append("")
        }

        lines += [
            "}",
            ""
        ]

        return lines.joined(separator: "\n")
    }

    private func methodSource(operation: OpenAPIOperation, helper: SwiftyAPITypeScriptGeneratorHelper) -> String {
        let responseType = helper.responseTypeName(for: operation)
        let returnType = responseType.map { "Promise<\($0)>" } ?? "Promise<void>"
        let bodyArgument = operation.requestBody == nil ? "" : ", body"
        let configArgument = helper.axiosConfigArgument(for: operation)

        var lines: [String] = [
            "  async \(helper.methodName(for: operation))(\(helper.methodParameters(for: operation))): \(returnType) {",
            "    const path = \(helper.pathExpression(for: operation));"
        ]

        if let responseType {
            lines.append("    const response = await this.http.\(operation.method.rawValue)<\(responseType)>(path\(bodyArgument)\(configArgument));")
            lines.append("    return response.data;")
        } else {
            lines.append("    await this.http.\(operation.method.rawValue)(path\(bodyArgument)\(configArgument));")
        }

        lines.append("  }")
        return lines.joined(separator: "\n")
    }
}

public struct SwiftyAPITypeScriptNodeServerGenerator: SwiftyAPICodeGenerator {
    public let name = "TypeScript Node Server"
    public let description = "Generates TypeScript server scaffolding for Node.js, including route declarations, typed handler signatures, and request/response model types."
    public let language = "TypeScript"
    public let variation = "node"
    public let type = "server"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.model, .request, .support]

    public init() {}

    public func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPITypeScriptGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(
            files: [
                SwiftyAPIGeneratedFile(path: "generated/models.ts", kind: .model, contents: helper.modelsSource()),
                SwiftyAPIGeneratedFile(path: "generated/server.ts", kind: .support, contents: serverSource(helper: helper))
            ],
            diagnostics: helper.diagnostics
        )
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPITypeScriptGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation

        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            routes.push({
              method: "\(operation.method.rawValue.uppercased())",
              path: "\(operation.path)",
              handler: handlers.\(helper.methodName(for: operation))
            });
            \(helper.methodReferencedModelsSource())
            """,
            responseExample: helper.responseObjectExample(for: operation, prefix: "return ") ?? "return { status: 204 };"
        )
    }

    private func serverSource(helper: SwiftyAPITypeScriptGeneratorHelper) -> String {
        var lines: [String] = [
            "import { createServer, IncomingMessage } from \"node:http\";",
            "import type { \(helper.modelTypeNames().joined(separator: ", ")) } from \"./models\";",
            "",
            "export type NodeAPIRequest = IncomingMessage & { body?: unknown; params: Record<string, string>; query: URLSearchParams };",
            "export type NodeAPIResponse<T = unknown> = { status?: number; body?: T };",
            "",
            "export interface \(helper.serverTypeName)Handlers {"
        ]

        if helper.operations.isEmpty {
            lines.append("  // No operations were found in this OpenAPI document.")
        } else {
            for operation in helper.operations {
                lines.append("  \(helper.methodName(for: operation))(request: NodeAPIRequest): Promise<NodeAPIResponse<\(helper.responseTypeName(for: operation) ?? "void")>>;")
            }
        }

        lines += [
            "}",
            "",
            "type Route = { method: string; path: string; handler: (request: NodeAPIRequest) => Promise<NodeAPIResponse> };",
            "",
            "export function create\(helper.serverTypeName)(handlers: \(helper.serverTypeName)Handlers) {",
            "  const routes: Route[] = ["
        ]

        for operation in helper.operations {
            lines += [
                "    { method: \"\(operation.method.rawValue.uppercased())\", path: \"\(operation.path)\", handler: handlers.\(helper.methodName(for: operation)).bind(handlers) },"
            ]
        }

        lines += [
            "  ];",
            "",
            "  return createServer(async (request, response) => {",
            "    const url = new URL(request.url ?? \"/\", \"http://localhost\");",
            "    const route = routes.find(candidate => candidate.method === request.method && candidate.path === url.pathname);",
            "",
            "    if (!route) {",
            "      response.writeHead(404, { \"content-type\": \"application/json\" });",
            "      response.end(JSON.stringify({ error: \"Not found\" }));",
            "      return;",
            "    }",
            "",
            "    const apiRequest = request as NodeAPIRequest;",
            "    apiRequest.params = {};",
            "    apiRequest.query = url.searchParams;",
            "    apiRequest.body = await readJSONBody(request);",
            "",
            "    const result = await route.handler(apiRequest);",
            "    response.writeHead(result.status ?? 200, { \"content-type\": \"application/json\" });",
            "    response.end(result.body === undefined ? \"\" : JSON.stringify(result.body));",
            "  });",
            "}",
            "",
            "async function readJSONBody(request: IncomingMessage): Promise<unknown> {",
            "  const chunks: Buffer[] = [];",
            "  for await (const chunk of request) {",
            "    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));",
            "  }",
            "  const text = Buffer.concat(chunks).toString(\"utf8\").trim();",
            "  return text.length === 0 ? undefined : JSON.parse(text);",
            "}",
            ""
        ]

        return lines.joined(separator: "\n")
    }
}

private struct SwiftyAPITypeScriptGeneratorHelper {
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

    var clientTypeName: String {
        "\(typeName(title))Client"
    }

    var serverTypeName: String {
        "\(typeName(title))Server"
    }

    func modelsSource() -> String {
        let models = modelDefinitions()
        guard models.isEmpty == false else {
            return "// No request or response models were found in this OpenAPI document.\n"
        }

        return models.joined(separator: "\n")
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

    func modelTypeNames() -> [String] {
        var names: [String] = []
        var emitted = Set<String>()

        for operation in operations {
            if operation.requestBody != nil {
                let name = requestTypeName(for: operation)
                if emitted.insert(name).inserted {
                    names.append(name)
                }
            }

            if let name = responseTypeName(for: operation), emitted.insert(name).inserted {
                names.append(name)
            }
        }

        return names.isEmpty ? ["Record<string, unknown>"] : names
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

    func methodParameters(for operation: OpenAPIOperation) -> String {
        var parameters: [String] = []
        let pathFields = operation.parameters.filter { $0.location == "path" }.map(schemaField)
        let queryFields = operation.parameters.filter { $0.location == "query" }.map(schemaField)

        if pathFields.isEmpty == false {
            parameters.append("pathParams: \(inlineObjectType(fields: pathFields))")
        }

        if queryFields.isEmpty == false {
            parameters.append("query: \(inlineObjectType(fields: queryFields))")
        }

        if operation.requestBody != nil {
            parameters.append("body: \(requestTypeName(for: operation))")
        }

        return parameters.joined(separator: ", ")
    }

    func methodCallArguments(for operation: OpenAPIOperation) -> String {
        var arguments: [String] = []
        let pathFields = operation.parameters.filter { $0.location == "path" }.map(schemaField)
        let queryFields = operation.parameters.filter { $0.location == "query" }.map(schemaField)

        if pathFields.isEmpty == false {
            arguments.append(exampleObject(fields: pathFields))
        }

        if queryFields.isEmpty == false {
            arguments.append(exampleObject(fields: queryFields))
        }

        if let requestBody = operation.requestBody {
            arguments.append(exampleObject(typeName: requestTypeName(for: operation), fields: requestBody.schemaFields))
        }

        return arguments.joined(separator: ", ")
    }

    func axiosConfigArgument(for operation: OpenAPIOperation) -> String {
        let queryFields = operation.parameters.filter { $0.location == "query" }
        guard queryFields.isEmpty == false else {
            return ""
        }

        return operation.requestBody == nil ? ", { params: query }" : ", { params: query }"
    }

    func pathExpression(for operation: OpenAPIOperation) -> String {
        let pathParameters = operation.parameters.filter { $0.location == "path" }
        guard pathParameters.isEmpty == false else {
            return "\"\(operation.path)\""
        }

        var replacements = ["let path = \"\(operation.path)\";"]
        for parameter in pathParameters {
            replacements.append("path = path.replace(\"{\(parameter.name)}\", encodeURIComponent(String(pathParams.\(variableName(parameter.name)))));")
        }
        return "(() => { \(replacements.joined(separator: " ")) return path; })()"
    }

    func responseObjectExample(for operation: OpenAPIOperation, prefix: String) -> String? {
        guard let response = operation.responses.first(where: { $0.schemaFields.isEmpty == false }) else {
            return nil
        }

        return "\(prefix)\(exampleObject(typeName: responseTypeName(for: operation), fields: response.schemaFields));"
    }

    private func appendModel(name: String, fields: [OpenAPISchemaField], to definitions: inout [String], emitted: inout Set<String>) {
        guard emitted.insert(name).inserted else {
            return
        }

        var lines = ["export interface \(name) {"]
        if fields.isEmpty {
            lines.append("  [key: string]: unknown;")
        } else {
            for field in fields {
                let optional = field.isRequired ? "" : "?"
                lines.append("  \(propertyName(field.name))\(optional): \(typescriptType(for: field));")
            }
        }
        lines.append("}")
        definitions.append(lines.joined(separator: "\n"))
        definitions.append("")
    }

    private func inlineObjectType(fields: [OpenAPISchemaField]) -> String {
        let properties = fields.map { "\(propertyName($0.name))\($0.isRequired ? "" : "?"): \(typescriptType(for: $0))" }
        return "{ \(properties.joined(separator: "; ")) }"
    }

    private func exampleObject(typeName: String? = nil, fields: [OpenAPISchemaField]) -> String {
        if fields.isEmpty {
            return "{}"
        }

        let lines = fields.map { field in
            "  \(propertyName(field.name)): \(exampleValue(for: field))"
        }
        let body = "{\n\(lines.joined(separator: ",\n"))\n}"

        guard let typeName else {
            return body
        }

        return "\(body) satisfies \(typeName)"
    }

    private func schemaField(for parameter: OpenAPIParameter) -> OpenAPISchemaField {
        OpenAPISchemaField(
            name: parameter.name,
            type: parameter.type ?? "string",
            isRequired: parameter.isRequired,
            description: parameter.description
        )
    }

    private func typescriptType(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        if type.contains("boolean") { return "boolean" }
        if type.contains("integer") || type.contains("number") || type.contains("float") || type.contains("double") { return "number" }
        if type.contains("array") || type.hasPrefix("[") { return "unknown[]" }
        if type.contains("object") { return "Record<string, unknown>" }
        return "string"
    }

    private func exampleValue(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        let name = field.name.lowercased()

        if type.contains("boolean") { return "true" }
        if type.contains("integer") || type.contains("number") || type.contains("float") || type.contains("double") { return "0" }
        if type.contains("array") || type.hasPrefix("[") { return "[]" }
        if type.contains("object") { return "{}" }
        if type.contains("date") || name.contains("date") || name.contains("time") {
            return "\"2026-05-05T00:00:00Z\""
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
        if ["class", "function", "interface", "const", "let", "var", "return", "import", "export", "default"].contains(proposed) {
            return "_\(proposed)"
        }
        return proposed
    }

    private func propertyName(_ value: String) -> String {
        let validIdentifier = value.first?.isLetter == true && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        return validIdentifier ? value : "\"\(value)\""
    }
}
