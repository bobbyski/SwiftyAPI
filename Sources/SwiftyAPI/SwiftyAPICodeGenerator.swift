import Foundation

public protocol SwiftyAPICodeGenerator: Sendable {
    var name: String { get }
    var description: String { get }
    var language: String { get }
    var variation: String { get }
    var type: String { get }
    var author: String { get }
    var supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> { get }

    func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult

    func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult
}

public extension SwiftyAPICodeGenerator {
    var registryKey: String {
        [
            type,
            language,
            name,
            variation,
            author
        ]
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
                .lowercased()
        }
        .joined(separator: ".")
    }
}

public enum SwiftyAPICodeGeneratorRegistryError: Error, Equatable, Sendable {
    case duplicateGenerator(String)
}

public final class SwiftyAPICodeGeneratorRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var generators: [String: any SwiftyAPICodeGenerator]

    public init(generators: [any SwiftyAPICodeGenerator] = []) throws {
        self.generators = [:]

        for generator in generators {
            try register(generator)
        }
    }

    public func register(_ generator: any SwiftyAPICodeGenerator) throws {
        lock.lock()
        defer { lock.unlock() }

        let key = generator.registryKey

        if generators[key] != nil {
            throw SwiftyAPICodeGeneratorRegistryError.duplicateGenerator(key)
        }

        generators[key] = generator
    }

    public func unregister(key: String) {
        lock.lock()
        defer { lock.unlock() }

        generators.removeValue(forKey: key)
    }

    public func generator(key: String) -> (any SwiftyAPICodeGenerator)? {
        lock.lock()
        defer { lock.unlock() }

        return generators[key]
    }

    public func allGenerators() -> [any SwiftyAPICodeGenerator] {
        lock.lock()
        defer { lock.unlock() }

        return generators.values.sorted { lhs, rhs in
            lhs.registryKey < rhs.registryKey
        }
    }
}

public struct SwiftyAPIJavaScriptGeneratorManifest: Equatable, Sendable {
    public var name: String
    public var description: String
    public var language: String
    public var variation: String
    public var type: String
    public var author: String
    public var version: String?
    public var entryPoint: String
    public var supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind>

    public init(
        name: String,
        description: String,
        language: String,
        variation: String,
        type: String,
        author: String,
        version: String? = nil,
        entryPoint: String,
        supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind>
    ) {
        self.name = name
        self.description = description
        self.language = language
        self.variation = variation
        self.type = type
        self.author = author
        self.version = version
        self.entryPoint = entryPoint
        self.supportedOutputs = supportedOutputs
    }
}

public struct SwiftyAPIMethodGenerationContext: Equatable, Sendable {
    public var title: String
    public var version: String
    public var serverURL: String?
    public var operation: OpenAPIOperation

    public init(
        title: String,
        version: String,
        serverURL: String? = nil,
        operation: OpenAPIOperation
    ) {
        self.title = title
        self.version = version
        self.serverURL = serverURL
        self.operation = operation
    }
}

public struct SwiftyAPIMethodGeneratorResult: Equatable, Sendable {
    public var requestExample: String
    public var responseExample: String
    public var diagnostics: [SwiftyAPIGeneratorDiagnostic]

    public init(
        requestExample: String = "",
        responseExample: String = "",
        diagnostics: [SwiftyAPIGeneratorDiagnostic] = []
    ) {
        self.requestExample = requestExample
        self.responseExample = responseExample
        self.diagnostics = diagnostics
    }
}

public struct SwiftyAPIGeneratorOptions: Equatable, Sendable {
    public var accessLevel: SwiftyAPIAccessLevel
    public var moduleName: String?
    public var includedOutputs: Set<SwiftyAPIGeneratedFile.Kind>
    public var dateStrategy: SwiftyAPIDateStrategy
    public var unknownObjectStrategy: SwiftyAPIUnknownObjectStrategy

    public init(
        accessLevel: SwiftyAPIAccessLevel = .public,
        moduleName: String? = nil,
        includedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = Set(SwiftyAPIGeneratedFile.Kind.allCases),
        dateStrategy: SwiftyAPIDateStrategy = .date,
        unknownObjectStrategy: SwiftyAPIUnknownObjectStrategy = .jsonValue
    ) {
        self.accessLevel = accessLevel
        self.moduleName = moduleName
        self.includedOutputs = includedOutputs
        self.dateStrategy = dateStrategy
        self.unknownObjectStrategy = unknownObjectStrategy
    }
}

public enum SwiftyAPIAccessLevel: String, CaseIterable, Sendable {
    case `public`
    case `internal`
    case package
}

public enum SwiftyAPIDateStrategy: String, CaseIterable, Sendable {
    case date
    case string
}

public enum SwiftyAPIUnknownObjectStrategy: String, CaseIterable, Sendable {
    case dictionary
    case jsonValue
    case omit
}

public struct SwiftyAPIGeneratorResult: Equatable, Sendable {
    public var files: [SwiftyAPIGeneratedFile]
    public var diagnostics: [SwiftyAPIGeneratorDiagnostic]

    public init(
        files: [SwiftyAPIGeneratedFile] = [],
        diagnostics: [SwiftyAPIGeneratorDiagnostic] = []
    ) {
        self.files = files
        self.diagnostics = diagnostics
    }
}

public struct SwiftyAPIGeneratedFile: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case endpoints
        case model
        case request
        case client
        case mock
        case support
    }

    public var path: String
    public var kind: Kind
    public var contents: String

    public init(path: String, kind: Kind, contents: String) {
        self.path = path
        self.kind = kind
        self.contents = contents
    }
}

public struct SwiftyAPIGeneratorDiagnostic: Equatable, Sendable {
    public enum Severity: String, CaseIterable, Sendable {
        case info
        case warning
        case error
    }

    public var severity: Severity
    public var message: String
    public var sourcePath: String?

    public init(
        severity: Severity,
        message: String,
        sourcePath: String? = nil
    ) {
        self.severity = severity
        self.message = message
        self.sourcePath = sourcePath
    }
}
