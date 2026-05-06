import Foundation
import JavaScriptCore

public enum SwiftyAPIJavaScriptGeneratorError: Error, Equatable, Sendable {
    case contextCreationFailed
    case evaluationFailed(String)
    case missingFunction(String)
    case invalidPayload(String)
    case invalidResult(String)
}

public final class SwiftyAPIJavaScriptCoreGenerator: SwiftyAPICodeGenerator, @unchecked Sendable {
    public let name: String
    public let description: String
    public let language: String
    public let variation: String
    public let type: String
    public let author: String
    public let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind>

    private let source: String

    public init(
        manifest: SwiftyAPIJavaScriptGeneratorManifest,
        source: String
    ) {
        self.name = manifest.name
        self.description = manifest.description
        self.language = manifest.language
        self.variation = manifest.variation
        self.type = manifest.type
        self.author = manifest.author
        self.supportedOutputs = manifest.supportedOutputs
        self.source = source
    }

    public func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        let payload = try jsonString([
            "document": documentPayload(document),
            "options": optionsPayload(options)
        ])
        let value = try call(functionName: "generateFull", payload: payload)
        return try parseFullResult(value)
    }

    public func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        let payload = try jsonString([
            "context": methodContextPayload(context),
            "options": optionsPayload(options)
        ])
        let value = try call(functionName: "generateMethod", payload: payload)
        return try parseMethodResult(value)
    }

    private func call(functionName: String, payload: String) throws -> JSValue {
        guard let context = JSContext() else {
            throw SwiftyAPIJavaScriptGeneratorError.contextCreationFailed
        }

        var exceptionMessage: String?
        context.exceptionHandler = { _, exception in
            exceptionMessage = exception?.toString()
        }

        context.evaluateScript(source)

        if let exceptionMessage {
            throw SwiftyAPIJavaScriptGeneratorError.evaluationFailed(exceptionMessage)
        }

        guard let function = context.objectForKeyedSubscript(functionName), !function.isUndefined else {
            throw SwiftyAPIJavaScriptGeneratorError.missingFunction(functionName)
        }

        let result = function.call(withArguments: [payload])

        if let exceptionMessage {
            throw SwiftyAPIJavaScriptGeneratorError.evaluationFailed(exceptionMessage)
        }

        guard let result else {
            throw SwiftyAPIJavaScriptGeneratorError.invalidResult("The JavaScript function returned no value.")
        }

        return result
    }

    private func parseFullResult(_ value: JSValue) throws -> SwiftyAPIGeneratorResult {
        let object = try resultObject(from: value)
        let files = try resultFiles(from: object["files"])
        let diagnostics = try resultDiagnostics(from: object["diagnostics"])
        return SwiftyAPIGeneratorResult(files: files, diagnostics: diagnostics)
    }

    private func parseMethodResult(_ value: JSValue) throws -> SwiftyAPIMethodGeneratorResult {
        let object = try resultObject(from: value)
        return SwiftyAPIMethodGeneratorResult(
            requestExample: object["requestExample"] as? String ?? "",
            responseExample: object["responseExample"] as? String ?? "",
            diagnostics: try resultDiagnostics(from: object["diagnostics"])
        )
    }

    private func resultObject(from value: JSValue) throws -> [String: Any] {
        if let json = value.toString(),
           let data = json.data(using: .utf8),
           let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }

        if let object = value.toObject() as? [String: Any] {
            return object
        }

        throw SwiftyAPIJavaScriptGeneratorError.invalidResult("Expected a JSON string or object.")
    }

    private func resultFiles(from value: Any?) throws -> [SwiftyAPIGeneratedFile] {
        guard let objects = value as? [[String: Any]] else {
            return []
        }

        return try objects.map { object in
            guard let path = object["path"] as? String,
                  let kindValue = object["kind"] as? String,
                  let kind = SwiftyAPIGeneratedFile.Kind(rawValue: kindValue),
                  let contents = object["contents"] as? String else {
                throw SwiftyAPIJavaScriptGeneratorError.invalidResult("Generated files must include path, kind, and contents.")
            }

            return SwiftyAPIGeneratedFile(path: path, kind: kind, contents: contents)
        }
    }

    private func resultDiagnostics(from value: Any?) throws -> [SwiftyAPIGeneratorDiagnostic] {
        guard let objects = value as? [[String: Any]] else {
            return []
        }

        return try objects.map { object in
            guard let severityValue = object["severity"] as? String,
                  let severity = SwiftyAPIGeneratorDiagnostic.Severity(rawValue: severityValue),
                  let message = object["message"] as? String else {
                throw SwiftyAPIJavaScriptGeneratorError.invalidResult("Diagnostics must include severity and message.")
            }

            return SwiftyAPIGeneratorDiagnostic(
                severity: severity,
                message: message,
                sourcePath: object["sourcePath"] as? String
            )
        }
    }

    private func documentPayload(_ document: OpenAPIDocument) -> [String: Any] {
        [
            "format": document.format.rawValue,
            "source": document.source,
            "summary": [
                "openAPIVersion": document.summary.openAPIVersion,
                "title": document.summary.title,
                "version": document.summary.version,
                "servers": document.summary.servers,
                "operations": document.summary.operations.map(operationPayload)
            ]
        ]
    }

    private func methodContextPayload(_ context: SwiftyAPIMethodGenerationContext) -> [String: Any] {
        [
            "title": context.title,
            "version": context.version,
            "serverURL": jsonOptional(context.serverURL),
            "operation": operationPayload(context.operation)
        ]
    }

    private func operationPayload(_ operation: OpenAPIOperation) -> [String: Any] {
        [
            "id": operation.id,
            "method": operation.method.rawValue,
            "path": operation.path,
            "operationID": jsonOptional(operation.operationID),
            "summary": jsonOptional(operation.summary),
            "description": jsonOptional(operation.description),
            "parameters": operation.parameters.map(parameterPayload),
            "requestBody": operation.requestBody.map(requestBodyPayload) ?? NSNull(),
            "responses": operation.responses.map(responsePayload)
        ]
    }

    private func parameterPayload(_ parameter: OpenAPIParameter) -> [String: Any] {
        [
            "name": parameter.name,
            "location": parameter.location,
            "isRequired": parameter.isRequired,
            "type": jsonOptional(parameter.type),
            "description": jsonOptional(parameter.description)
        ]
    }

    private func requestBodyPayload(_ body: OpenAPIRequestBody) -> [String: Any] {
        [
            "isRequired": body.isRequired,
            "contentTypes": body.contentTypes,
            "description": jsonOptional(body.description),
            "schemaName": jsonOptional(body.schemaName),
            "schemaFields": body.schemaFields.map(schemaFieldPayload)
        ]
    }

    private func responsePayload(_ response: OpenAPIResponse) -> [String: Any] {
        [
            "statusCode": response.statusCode,
            "description": jsonOptional(response.description),
            "contentTypes": response.contentTypes,
            "schemaName": jsonOptional(response.schemaName),
            "schemaFields": response.schemaFields.map(schemaFieldPayload)
        ]
    }

    private func schemaFieldPayload(_ field: OpenAPISchemaField) -> [String: Any] {
        [
            "name": field.name,
            "type": field.type,
            "isRequired": field.isRequired,
            "description": jsonOptional(field.description)
        ]
    }

    private func optionsPayload(_ options: SwiftyAPIGeneratorOptions) -> [String: Any] {
        [
            "accessLevel": options.accessLevel.rawValue,
            "moduleName": jsonOptional(options.moduleName),
            "includedOutputs": options.includedOutputs.map(\.rawValue).sorted(),
            "dateStrategy": options.dateStrategy.rawValue,
            "unknownObjectStrategy": options.unknownObjectStrategy.rawValue
        ]
    }

    private func jsonString(_ object: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw SwiftyAPIJavaScriptGeneratorError.invalidPayload("Payload contains values that cannot be serialized to JSON.")
        }

        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw SwiftyAPIJavaScriptGeneratorError.invalidPayload("Payload could not be encoded as UTF-8.")
        }

        return string
    }

    private func jsonOptional(_ value: String?) -> Any {
        value ?? NSNull()
    }
}
