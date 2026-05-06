import Testing
@testable import SwiftyAPI

@Test
func generatorOptionsDefaultToAllOutputs() {
    let options = SwiftyAPIGeneratorOptions()

    #expect(options.accessLevel == .public)
    #expect(options.moduleName == nil)
    #expect(options.includedOutputs == Set(SwiftyAPIGeneratedFile.Kind.allCases))
    #expect(options.dateStrategy == .date)
    #expect(options.unknownObjectStrategy == .jsonValue)
}

@Test
func codeGeneratorProtocolReturnsGeneratedFilesAndDiagnostics() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)
    let generator = StubCodeGenerator()
    let result = try generator.generateFull(
        from: document,
        options: SwiftyAPIGeneratorOptions(includedOutputs: [.endpoints])
    )

    #expect(generator.name == "Stub")
    #expect(generator.description == "Test generator.")
    #expect(generator.language == "Swift")
    #expect(generator.variation == "Endpoints")
    #expect(generator.type == "client")
    #expect(generator.author == "builtin")
    #expect(generator.registryKey == "client.swift.stub.endpoints.builtin")
    #expect(generator.supportedOutputs == [.endpoints])
    #expect(result.files == [
        SwiftyAPIGeneratedFile(
            path: "Endpoints.swift",
            kind: .endpoints,
            contents: "Example API"
        )
    ])
    #expect(result.diagnostics == [
        SwiftyAPIGeneratorDiagnostic(
            severity: .info,
            message: "Generated endpoint file.",
            sourcePath: "paths"
        )
    ])
}

@Test
func codeGeneratorProtocolReturnsMethodExamples() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)
    let operation = try #require(document.summary.operations.first)
    let generator = StubCodeGenerator()
    let result = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            serverURL: document.summary.servers.first,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )

    #expect(result.requestExample == "GET /pets request")
    #expect(result.responseExample == "GET /pets response")
    #expect(result.diagnostics == [])
}

@Test
func generatorRegistryRegistersAndFindsRuntimeGenerators() throws {
    let swiftGenerator = StubCodeGenerator()
    let javaScriptGenerator = JavaScriptStubCodeGenerator()
    let registry = try SwiftyAPICodeGeneratorRegistry(generators: [swiftGenerator])

    try registry.register(javaScriptGenerator)

    #expect(registry.generator(key: "client.swift.stub.endpoints.builtin")?.type == "client")
    #expect(registry.generator(key: "Client.Swift.JavaScript Stub.Models")?.type == nil)
    #expect(registry.generator(key: "client.swift.javascript stub.models.example")?.type == "client")
    #expect(registry.allGenerators().map(\.registryKey) == [
        "client.swift.javascript stub.models.example",
        "client.swift.stub.endpoints.builtin"
    ])
}

@Test
func generatorRegistryRejectsDuplicateIDs() throws {
    let registry = try SwiftyAPICodeGeneratorRegistry(generators: [StubCodeGenerator()])

    #expect(throws: SwiftyAPICodeGeneratorRegistryError.duplicateGenerator("client.swift.stub.endpoints.builtin")) {
        try registry.register(StubCodeGenerator())
    }
}

@Test
func javaScriptGeneratorManifestDescribesRuntimeExtension() {
    let manifest = SwiftyAPIJavaScriptGeneratorManifest(
        name: "JavaScript Models",
        description: "Generates Swift models from JavaScript.",
        language: "Swift",
        variation: "Models",
        type: "client",
        author: "Example",
        version: "1.0.0",
        entryPoint: "index.js",
        supportedOutputs: [.model, .support]
    )

    #expect(manifest.name == "JavaScript Models")
    #expect(manifest.description == "Generates Swift models from JavaScript.")
    #expect(manifest.language == "Swift")
    #expect(manifest.variation == "Models")
    #expect(manifest.type == "client")
    #expect(manifest.author == "Example")
    #expect(manifest.entryPoint == "index.js")
    #expect(manifest.supportedOutputs == [.model, .support])
}

private struct StubCodeGenerator: SwiftyAPICodeGenerator {
    let name = "Stub"
    let description = "Test generator."
    let language = "Swift"
    let variation = "Endpoints"
    let type = "client"
    let author = "builtin"
    let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.endpoints]

    func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        SwiftyAPIGeneratorResult(
            files: [
                SwiftyAPIGeneratedFile(
                    path: "Endpoints.swift",
                    kind: .endpoints,
                    contents: document.summary.title
                )
            ],
            diagnostics: [
                SwiftyAPIGeneratorDiagnostic(
                    severity: .info,
                    message: "Generated endpoint file.",
                    sourcePath: "paths"
                )
            ]
        )
    }

    func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        SwiftyAPIMethodGeneratorResult(
            requestExample: "\(context.operation.id) request",
            responseExample: "\(context.operation.id) response"
        )
    }
}

private struct JavaScriptStubCodeGenerator: SwiftyAPICodeGenerator {
    let name = "JavaScript Stub"
    let description = "Test JavaScript generator."
    let language = "Swift"
    let variation = "Models"
    let type = "client"
    let author = "Example"
    let supportedOutputs: Set<SwiftyAPIGeneratedFile.Kind> = [.model]

    func generateFull(
        from document: OpenAPIDocument,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIGeneratorResult {
        SwiftyAPIGeneratorResult()
    }

    func generateMethod(
        from context: SwiftyAPIMethodGenerationContext,
        options: SwiftyAPIGeneratorOptions
    ) throws -> SwiftyAPIMethodGeneratorResult {
        SwiftyAPIMethodGeneratorResult()
    }
}
