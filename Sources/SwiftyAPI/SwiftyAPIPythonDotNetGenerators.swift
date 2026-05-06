import Foundation

public struct SwiftyAPIPythonHTTPXClientGenerator: SwiftyAPICodeGenerator {
    public let name = "Python httpx Client"
    public let description = "Generates a Python client that uses httpx for sync or async HTTP transport and Pydantic models for typed request and response payloads."
    public let language = "Python"
    public let variation = "httpx + Pydantic"
    public let type = "client"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.client, .model, .request, .support]

    public init() {}

    public func generateFull(from document: OpenAPIDocument, options: SwiftyAPIGeneratorOptions) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPIPythonGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(files: [
            SwiftyAPIGeneratedFile(path: "generated/models.py", kind: .model, contents: helper.modelsSource()),
            SwiftyAPIGeneratedFile(path: "generated/client.py", kind: .client, contents: clientSource(helper: helper))
        ])
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPIPythonGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation
        let responsePrefix = helper.responseTypeName(for: operation) == nil ? "" : "response = "
        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            client = \(helper.clientTypeName)(base_url="\(context.serverURL ?? "https://api.example.com")")
            \(responsePrefix)await client.\(helper.methodName(for: operation))(\(helper.methodCallArguments(for: operation)))
            \(helper.methodReferencedModelsSource())
            """,
            responseExample: helper.responseObjectExample(for: operation, prefix: "response = ") ?? "HTTP 204 / empty response"
        )
    }

    private func clientSource(helper: SwiftyAPIPythonGeneratorHelper) -> String {
        var lines = [
            "import httpx",
            "from .models import \(helper.modelTypeNames().joined(separator: ", "))",
            "",
            "",
            "class \(helper.clientTypeName):",
            "    def __init__(self, base_url: str, client: httpx.AsyncClient | None = None) -> None:",
            "        self._client = client or httpx.AsyncClient(base_url=base_url)",
            ""
        ]

        if helper.operations.isEmpty {
            lines.append("    # No operations were found in this OpenAPI document.")
        }

        for operation in helper.operations {
            lines.append(methodSource(operation: operation, helper: helper))
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func methodSource(operation: OpenAPIOperation, helper: SwiftyAPIPythonGeneratorHelper) -> String {
        let returnType = helper.responseTypeName(for: operation) ?? "None"
        let bodyArgument = operation.requestBody == nil ? "" : ", json=body.model_dump(exclude_none=True)"
        let parameters = helper.methodParameters(for: operation)
        let signatureParameters = parameters.isEmpty ? "self" : "self, \(parameters)"
        var lines = [
            "    async def \(helper.methodName(for: operation))(\(signatureParameters)) -> \(returnType):",
            "        response = await self._client.\(operation.method.rawValue)(\"\(operation.path)\"\(bodyArgument))",
            "        response.raise_for_status()"
        ]

        if let responseType = helper.responseTypeName(for: operation) {
            lines.append("        return \(responseType).model_validate(response.json())")
        }

        return lines.joined(separator: "\n")
    }
}

public struct SwiftyAPIPythonFastAPIServerGenerator: SwiftyAPICodeGenerator {
    public let name = "Python FastAPI Server"
    public let description = "Generates Python server scaffolding for FastAPI, including routers, Pydantic request and response models, and handler stubs for each operation."
    public let language = "Python"
    public let variation = "FastAPI + Pydantic"
    public let type = "server"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.model, .request, .support]

    public init() {}

    public func generateFull(from document: OpenAPIDocument, options: SwiftyAPIGeneratorOptions) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPIPythonGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(files: [
            SwiftyAPIGeneratedFile(path: "generated/models.py", kind: .model, contents: helper.modelsSource()),
            SwiftyAPIGeneratedFile(path: "generated/server.py", kind: .support, contents: serverSource(helper: helper))
        ])
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPIPythonGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation
        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            @router.\(operation.method.rawValue)("\(operation.path)", response_model=\(helper.responseTypeName(for: operation) ?? "None"))
            async def \(helper.methodName(for: operation))(\(helper.methodParameters(for: operation))) -> \(helper.responseTypeName(for: operation) ?? "None"):
                raise NotImplementedError()
            \(helper.methodReferencedModelsSource())
            """,
            responseExample: helper.responseObjectExample(for: operation, prefix: "return ") ?? "return Response(status_code=204)"
        )
    }

    private func serverSource(helper: SwiftyAPIPythonGeneratorHelper) -> String {
        var lines = [
            "from fastapi import APIRouter, Response",
            "from .models import \(helper.modelTypeNames().joined(separator: ", "))",
            "",
            "router = APIRouter()",
            ""
        ]

        if helper.operations.isEmpty {
            lines.append("# No operations were found in this OpenAPI document.")
        }

        for operation in helper.operations {
            let responseModel = helper.responseTypeName(for: operation) ?? "None"
            lines += [
                "@router.\(operation.method.rawValue)(\"\(operation.path)\", response_model=\(responseModel))",
                "async def \(helper.methodName(for: operation))(\(helper.methodParameters(for: operation))) -> \(responseModel):",
                "    raise NotImplementedError()",
                ""
            ]
        }

        return lines.joined(separator: "\n")
    }
}

public struct SwiftyAPIDotNetHTTPClientGenerator: SwiftyAPICodeGenerator {
    public let name = ".NET HttpClient Client"
    public let description = "Generates a C# client that uses HttpClient, System.Text.Json models, and task-based async methods for each OpenAPI operation."
    public let language = "C#"
    public let variation = "HttpClient + System.Text.Json"
    public let type = "client"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.client, .model, .request, .support]

    public init() {}

    public func generateFull(from document: OpenAPIDocument, options: SwiftyAPIGeneratorOptions) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPIDotNetGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(files: [
            SwiftyAPIGeneratedFile(path: "Generated/Models.cs", kind: .model, contents: helper.modelsSource()),
            SwiftyAPIGeneratedFile(path: "Generated/ApiClient.cs", kind: .client, contents: clientSource(helper: helper))
        ])
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPIDotNetGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation
        let responsePrefix = helper.responseTypeName(for: operation) == nil ? "" : "var response = "
        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            var client = new \(helper.clientTypeName)(new HttpClient { BaseAddress = new Uri("\(context.serverURL ?? "https://api.example.com")") });
            \(responsePrefix)await client.\(helper.methodName(for: operation))Async(\(helper.methodCallArguments(for: operation)));
            \(helper.methodReferencedModelsSource())
            """,
            responseExample: helper.responseObjectExample(for: operation, prefix: "var response = ") ?? "HTTP 204 / empty response"
        )
    }

    private func clientSource(helper: SwiftyAPIDotNetGeneratorHelper) -> String {
        var lines = [
            "using System.Net.Http.Json;",
            "",
            "public sealed class \(helper.clientTypeName)",
            "{",
            "    private readonly HttpClient _http;",
            "",
            "    public \(helper.clientTypeName)(HttpClient http)",
            "    {",
            "        _http = http;",
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

        lines += ["}", ""]
        return lines.joined(separator: "\n")
    }

    private func methodSource(operation: OpenAPIOperation, helper: SwiftyAPIDotNetGeneratorHelper) -> String {
        let responseType = helper.responseTypeName(for: operation)
        let returnType = responseType.map { "Task<\($0)>" } ?? "Task"
        let method = operation.method.rawValue.capitalized
        var lines = [
            "    public async \(returnType) \(helper.methodName(for: operation))Async(\(helper.methodParameters(for: operation)))",
            "    {"
        ]

        if let responseType {
            if operation.requestBody == nil {
                lines.append("        var result = await _http.GetFromJsonAsync<\(responseType)>(\"\(operation.path)\");")
            } else {
                lines.append("        var response = await _http.\(method)AsJsonAsync(\"\(operation.path)\", body);")
                lines.append("        response.EnsureSuccessStatusCode();")
                lines.append("        var result = await response.Content.ReadFromJsonAsync<\(responseType)>();")
            }
            lines.append("        return result ?? throw new InvalidOperationException(\"The API returned an empty response body.\");")
        } else if operation.requestBody == nil {
            lines.append("        using var response = await _http.\(method)Async(\"\(operation.path)\");")
            lines.append("        response.EnsureSuccessStatusCode();")
        } else {
            lines.append("        using var response = await _http.\(method)AsJsonAsync(\"\(operation.path)\", body);")
            lines.append("        response.EnsureSuccessStatusCode();")
        }

        lines.append("    }")
        return lines.joined(separator: "\n")
    }
}

public struct SwiftyAPIDotNetMinimalAPIServerGenerator: SwiftyAPICodeGenerator {
    public let name = ".NET ASP.NET Core Server"
    public let description = "Generates C# server scaffolding for ASP.NET Core Minimal APIs, including endpoint mapping, request records, response records, and handler stubs."
    public let language = "C#"
    public let variation = "ASP.NET Core Minimal API"
    public let type = "server"
    public let author = "builtin"
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.model, .request, .support]

    public init() {}

    public func generateFull(from document: OpenAPIDocument, options: SwiftyAPIGeneratorOptions) throws -> SwiftyAPIGeneratorResult {
        let helper = SwiftyAPIDotNetGeneratorHelper(document: document, options: options)
        return SwiftyAPIGeneratorResult(files: [
            SwiftyAPIGeneratedFile(path: "Generated/Models.cs", kind: .model, contents: helper.modelsSource()),
            SwiftyAPIGeneratedFile(path: "Generated/Endpoints.cs", kind: .support, contents: endpointsSource(helper: helper))
        ])
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let helper = SwiftyAPIDotNetGeneratorHelper(title: context.title, operations: [context.operation], options: options)
        let operation = context.operation
        return SwiftyAPIMethodGeneratorResult(
            requestExample: """
            app.Map\(operation.method.rawValue.capitalized)("\(operation.path)", async (\(helper.lambdaParameters(for: operation))I\(helper.serverTypeName)Handlers handlers) =>
                Results.Ok(await handlers.\(helper.methodName(for: operation))Async(\(helper.handlerCallArguments(for: operation)))));
            \(helper.methodReferencedModelsSource())
            """,
            responseExample: helper.responseObjectExample(for: operation, prefix: "return ") ?? "return Results.NoContent();"
        )
    }

    private func endpointsSource(helper: SwiftyAPIDotNetGeneratorHelper) -> String {
        var lines = [
            "using Microsoft.AspNetCore.Builder;",
            "using Microsoft.AspNetCore.Http;",
            "",
            "public interface I\(helper.serverTypeName)Handlers",
            "{"
        ]

        if helper.operations.isEmpty {
            lines.append("    // No operations were found in this OpenAPI document.")
        } else {
            for operation in helper.operations {
                let returnType = helper.responseTypeName(for: operation) ?? "IResult"
                lines.append("    Task<\(returnType)> \(helper.methodName(for: operation))Async(\(helper.methodParameters(for: operation)));")
            }
        }

        lines += [
            "}",
            "",
            "public static class \(helper.serverTypeName)Endpoints",
            "{",
            "    public static void Map\(helper.serverTypeName)Endpoints(this WebApplication app)",
            "    {"
        ]

        for operation in helper.operations {
            lines.append("        app.Map\(operation.method.rawValue.capitalized)(\"\(operation.path)\", async (\(helper.lambdaParameters(for: operation))I\(helper.serverTypeName)Handlers handlers) =>")
            lines.append("            Results.Ok(await handlers.\(helper.methodName(for: operation))Async(\(helper.handlerCallArguments(for: operation)))));")
        }

        lines += [
            "    }",
            "}",
            ""
        ]
        return lines.joined(separator: "\n")
    }
}

private struct SwiftyAPIPythonGeneratorHelper {
    var title: String
    var operations: [OpenAPIOperation]
    var options: SwiftyAPIGeneratorOptions

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

    var clientTypeName: String { "\(typeName(title))Client" }

    func modelsSource() -> String {
        let models = modelDefinitions()
        guard models.isEmpty == false else { return "from pydantic import BaseModel\n\n" }
        return (["from pydantic import BaseModel", ""] + models).joined(separator: "\n")
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
            if operation.requestBody != nil, emitted.insert(requestTypeName(for: operation)).inserted {
                names.append(requestTypeName(for: operation))
            }
            if let responseName = responseTypeName(for: operation), emitted.insert(responseName).inserted {
                names.append(responseName)
            }
        }
        return names.isEmpty ? ["BaseModel"] : names
    }

    func methodReferencedModelsSource() -> String {
        let definitions = modelDefinitions().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
        guard definitions.isEmpty == false else { return "" }
        return "\n# Referenced models\n\(definitions.joined(separator: "\n\n"))"
    }

    func methodName(for operation: OpenAPIOperation) -> String {
        snakeName(operation.operationID ?? "\(operation.method.rawValue) \(operation.path)")
    }

    func requestTypeName(for operation: OpenAPIOperation) -> String {
        "\(typeName(methodName(for: operation)))Request"
    }

    func responseTypeName(for operation: OpenAPIOperation) -> String? {
        guard operation.responses.contains(where: { $0.schemaFields.isEmpty == false }) else { return nil }
        return "\(typeName(methodName(for: operation)))Response"
    }

    func methodParameters(for operation: OpenAPIOperation) -> String {
        var parameters = operation.parameters.map { "\($0.name): \(pythonType(for: OpenAPISchemaField(name: $0.name, type: $0.type ?? "string")))" }
        if operation.requestBody != nil {
            parameters.append("body: \(requestTypeName(for: operation))")
        }
        return parameters.joined(separator: ", ")
    }

    func methodCallArguments(for operation: OpenAPIOperation) -> String {
        var arguments = operation.parameters.map { "\($0.name)=\(exampleValue(for: OpenAPISchemaField(name: $0.name, type: $0.type ?? "string")))" }
        if let body = operation.requestBody {
            arguments.append("body=\(exampleObject(typeName: requestTypeName(for: operation), fields: body.schemaFields))")
        }
        return arguments.joined(separator: ", ")
    }

    func responseObjectExample(for operation: OpenAPIOperation, prefix: String) -> String? {
        guard let response = operation.responses.first(where: { $0.schemaFields.isEmpty == false }),
              let responseType = responseTypeName(for: operation) else { return nil }
        return "\(prefix)\(exampleObject(typeName: responseType, fields: response.schemaFields))"
    }

    private func appendModel(name: String, fields: [OpenAPISchemaField], to definitions: inout [String], emitted: inout Set<String>) {
        guard emitted.insert(name).inserted else { return }
        var lines = ["class \(name)(BaseModel):"]
        if fields.isEmpty {
            lines.append("    pass")
        } else {
            for field in fields {
                let optional = field.isRequired ? "" : " | None = None"
                lines.append("    \(snakeName(field.name)): \(pythonType(for: field))\(optional)")
            }
        }
        definitions.append(lines.joined(separator: "\n"))
        definitions.append("")
    }

    private func exampleObject(typeName: String, fields: [OpenAPISchemaField]) -> String {
        guard fields.isEmpty == false else { return "\(typeName)()" }
        let values = fields.map { "\(snakeName($0.name))=\(exampleValue(for: $0))" }.joined(separator: ", ")
        return "\(typeName)(\(values))"
    }

    private func pythonType(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        if type.contains("boolean") { return "bool" }
        if type.contains("integer") { return "int" }
        if type.contains("number") || type.contains("float") || type.contains("double") { return "float" }
        if type.contains("array") || type.hasPrefix("[") { return "list[object]" }
        if type.contains("object") { return "dict[str, object]" }
        return "str"
    }

    private func exampleValue(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        let name = field.name.lowercased()
        if type.contains("boolean") { return "True" }
        if type.contains("integer") || type.contains("number") || type.contains("float") || type.contains("double") { return "0" }
        if type.contains("array") || type.hasPrefix("[") { return "[]" }
        if type.contains("object") { return "{}" }
        if type.contains("date") || name.contains("date") || name.contains("time") { return "\"2026-05-05T00:00:00Z\"" }
        return "\"\(field.name)\""
    }
}

private struct SwiftyAPIDotNetGeneratorHelper {
    var title: String
    var operations: [OpenAPIOperation]
    var options: SwiftyAPIGeneratorOptions

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

    var clientTypeName: String { "\(typeName(title))Client" }
    var serverTypeName: String { "\(typeName(title))Server" }

    func modelsSource() -> String {
        let models = modelDefinitions()
        guard models.isEmpty == false else { return "// No request or response models were found in this OpenAPI document.\n" }
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

    func methodReferencedModelsSource() -> String {
        let definitions = modelDefinitions().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
        guard definitions.isEmpty == false else { return "" }
        return "\n// Referenced models\n\(definitions.joined(separator: "\n\n"))"
    }

    func methodName(for operation: OpenAPIOperation) -> String {
        typeName(operation.operationID ?? "\(operation.method.rawValue) \(operation.path)")
    }

    func requestTypeName(for operation: OpenAPIOperation) -> String {
        "\(methodName(for: operation))Request"
    }

    func responseTypeName(for operation: OpenAPIOperation) -> String? {
        guard operation.responses.contains(where: { $0.schemaFields.isEmpty == false }) else { return nil }
        return "\(methodName(for: operation))Response"
    }

    func methodParameters(for operation: OpenAPIOperation) -> String {
        var parameters = operation.parameters.map { "\(csharpType(for: OpenAPISchemaField(name: $0.name, type: $0.type ?? "string"))) \(camelName($0.name))" }
        if operation.requestBody != nil {
            parameters.append("\(requestTypeName(for: operation)) body")
        }
        return parameters.joined(separator: ", ")
    }

    func lambdaParameters(for operation: OpenAPIOperation) -> String {
        let parameters = methodParameters(for: operation)
        return parameters.isEmpty ? "" : "\(parameters), "
    }

    func handlerCallArguments(for operation: OpenAPIOperation) -> String {
        var arguments = operation.parameters.map { camelName($0.name) }
        if operation.requestBody != nil {
            arguments.append("body")
        }
        return arguments.joined(separator: ", ")
    }

    func methodCallArguments(for operation: OpenAPIOperation) -> String {
        var arguments = operation.parameters.map { exampleValue(for: OpenAPISchemaField(name: $0.name, type: $0.type ?? "string")) }
        if let body = operation.requestBody {
            arguments.append(exampleObject(typeName: requestTypeName(for: operation), fields: body.schemaFields))
        }
        return arguments.joined(separator: ", ")
    }

    func responseObjectExample(for operation: OpenAPIOperation, prefix: String) -> String? {
        guard let response = operation.responses.first(where: { $0.schemaFields.isEmpty == false }),
              let responseType = responseTypeName(for: operation) else { return nil }
        return "\(prefix)\(exampleObject(typeName: responseType, fields: response.schemaFields));"
    }

    private func appendModel(name: String, fields: [OpenAPISchemaField], to definitions: inout [String], emitted: inout Set<String>) {
        guard emitted.insert(name).inserted else { return }
        let parameters = fields.map { "\(csharpType(for: $0)) \(typeName($0.name))" }.joined(separator: ", ")
        definitions.append("public sealed record \(name)(\(parameters));")
        definitions.append("")
    }

    private func exampleObject(typeName: String, fields: [OpenAPISchemaField]) -> String {
        guard fields.isEmpty == false else { return "new \(typeName)()" }
        let values = fields.map(exampleValue).joined(separator: ", ")
        return "new \(typeName)(\(values))"
    }

    private func csharpType(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        if type.contains("boolean") { return "bool" }
        if type.contains("int64") { return "long" }
        if type.contains("integer") { return "int" }
        if type.contains("number") || type.contains("float") || type.contains("double") { return "double" }
        if type.contains("array") || type.hasPrefix("[") { return "IReadOnlyList<object>" }
        if type.contains("object") { return "Dictionary<string, object>" }
        return "string"
    }

    private func exampleValue(for field: OpenAPISchemaField) -> String {
        let type = field.type.lowercased()
        let name = field.name.lowercased()
        if type.contains("boolean") { return "true" }
        if type.contains("integer") || type.contains("number") || type.contains("float") || type.contains("double") { return "0" }
        if type.contains("array") || type.hasPrefix("[") { return "[]" }
        if type.contains("object") { return "[]" }
        if type.contains("date") || name.contains("date") || name.contains("time") { return "\"2026-05-05T00:00:00Z\"" }
        return "\"\(field.name)\""
    }
}

private func typeName(_ value: String) -> String {
    let words = nameWords(value)
    let joined = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    return joined.isEmpty ? "OpenAPI" : (joined.first?.isNumber == true ? "OpenAPI\(joined)" : joined)
}

private func camelName(_ value: String) -> String {
    let type = typeName(value)
    return type.prefix(1).lowercased() + type.dropFirst()
}

private func snakeName(_ value: String) -> String {
    let words = nameWords(value).map { $0.lowercased() }
    let name = words.joined(separator: "_")
    return name.isEmpty ? "value" : name
}

private func nameWords(_ value: String) -> [String] {
    let normalized = value.reduce(into: "") { partialResult, character in
        if character.isLetter || character.isNumber {
            if let last = partialResult.last,
               last.isLowercase,
               character.isUppercase {
                partialResult.append(" ")
            }
            partialResult.append(character)
        } else {
            partialResult.append(" ")
        }
    }
    return normalized.split(separator: " ").map(String.init)
}
