import Foundation

public enum OpenAPIFormat: String, CaseIterable, Sendable {
    case json
    case yaml

    public var displayName: String {
        switch self {
        case .json: "JSON"
        case .yaml: "YAML"
        }
    }

    public static func infer(from path: String) -> OpenAPIFormat {
        let lowercased = path.lowercased()
        if lowercased.hasSuffix(".json") {
            return .json
        }
        return .yaml
    }
}

public enum OpenAPIParseError: Error, Equatable, LocalizedError {
    case invalidJSON(String)
    case emptyDocument
    case missingOpenAPIVersion

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .emptyDocument:
            return "The document is empty."
        case .missingOpenAPIVersion:
            return "The document does not declare an OpenAPI or Swagger version."
        }
    }
}

public struct OpenAPIDocument: Equatable, Sendable {
    public var source: String
    public var format: OpenAPIFormat
    public var summary: OpenAPISummary

    public init(source: String, format: OpenAPIFormat) throws {
        self.source = source
        self.format = format
        self.summary = try OpenAPIDocumentParser.parse(source: source, format: format)
    }

    public mutating func updateSource(_ newSource: String, format newFormat: OpenAPIFormat? = nil) throws {
        let resolvedFormat = newFormat ?? format
        source = newSource
        format = resolvedFormat
        summary = try OpenAPIDocumentParser.parse(source: newSource, format: resolvedFormat)
    }
}

public struct OpenAPISummary: Equatable, Sendable {
    public var openAPIVersion: String
    public var title: String
    public var version: String
    public var servers: [String]
    public var operations: [OpenAPIOperation]

    public init(
        openAPIVersion: String,
        title: String,
        version: String,
        servers: [String] = [],
        operations: [OpenAPIOperation] = []
    ) {
        self.openAPIVersion = openAPIVersion
        self.title = title
        self.version = version
        self.servers = servers
        self.operations = operations
    }
}

public struct OpenAPIOperation: Identifiable, Equatable, Sendable {
    public var id: String { "\(method.rawValue.uppercased()) \(path)" }
    public var method: OpenAPIHTTPMethod
    public var path: String
    public var operationID: String?
    public var summary: String?
    public var description: String?
    public var parameters: [OpenAPIParameter]
    public var requestBody: OpenAPIRequestBody?
    public var responses: [OpenAPIResponse]

    public init(
        method: OpenAPIHTTPMethod,
        path: String,
        operationID: String? = nil,
        summary: String? = nil,
        description: String? = nil,
        parameters: [OpenAPIParameter] = [],
        requestBody: OpenAPIRequestBody? = nil,
        responses: [OpenAPIResponse] = []
    ) {
        self.method = method
        self.path = path
        self.operationID = operationID
        self.summary = summary
        self.description = description
        self.parameters = parameters
        self.requestBody = requestBody
        self.responses = responses
    }
}

public struct OpenAPIParameter: Equatable, Sendable {
    public var name: String
    public var location: String
    public var isRequired: Bool
    public var type: String?
    public var description: String?

    public init(
        name: String,
        location: String,
        isRequired: Bool = false,
        type: String? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.location = location
        self.isRequired = isRequired
        self.type = type
        self.description = description
    }
}

public struct OpenAPIRequestBody: Equatable, Sendable {
    public var isRequired: Bool
    public var contentTypes: [String]
    public var description: String?
    public var schemaName: String?
    public var schemaFields: [OpenAPISchemaField]

    public init(
        isRequired: Bool = false,
        contentTypes: [String] = [],
        description: String? = nil,
        schemaName: String? = nil,
        schemaFields: [OpenAPISchemaField] = []
    ) {
        self.isRequired = isRequired
        self.contentTypes = contentTypes
        self.description = description
        self.schemaName = schemaName
        self.schemaFields = schemaFields
    }
}

public struct OpenAPISchemaField: Equatable, Sendable {
    public var name: String
    public var type: String
    public var isRequired: Bool
    public var description: String?

    public init(name: String, type: String, isRequired: Bool = false, description: String? = nil) {
        self.name = name
        self.type = type
        self.isRequired = isRequired
        self.description = description
    }
}

public struct OpenAPIResponse: Equatable, Sendable {
    public var statusCode: String
    public var description: String?
    public var contentTypes: [String]

    public init(statusCode: String, description: String? = nil, contentTypes: [String] = []) {
        self.statusCode = statusCode
        self.description = description
        self.contentTypes = contentTypes
    }
}

public enum OpenAPIHTTPMethod: String, CaseIterable, Sendable {
    case get
    case put
    case post
    case delete
    case options
    case head
    case patch
    case trace
}
