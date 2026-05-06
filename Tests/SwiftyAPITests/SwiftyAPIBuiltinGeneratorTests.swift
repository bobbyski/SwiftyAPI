import Testing
@testable import SwiftyAPI

@Test
func builtinGeneratorCatalogIncludesInitialPairings() throws {
    let generators = SwiftyAPIBuiltinGenerators.all

    #expect(generators.map(\.registryKey).sorted() == [
        "client.curl.curl examples.request and response examples.builtin",
        "client.c#.net httpclient client.httpclient + system.text.json.builtin",
        "client.python.python httpx client.httpx + pydantic.builtin",
        "client.swift.swift urlsession client.urlsession.builtin",
        "client.typescript.typescript axios client.axios.builtin",
        "server.c#.net asp.net core server.asp.net core minimal api.builtin",
        "server.python.python fastapi server.fastapi + pydantic.builtin",
        "server.swift.swift vapor server.vapor.builtin",
        "server.typescript.typescript node server.node.builtin"
    ].sorted())

    let registry = try SwiftyAPIBuiltinGenerators.registry()
    #expect(registry.allGenerators().count == 9)
}

@Test
func curlExampleGeneratorProducesDesignMethodExamples() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let result = try SwiftyAPICurlExampleGenerator().generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            serverURL: document.summary.servers.first,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )

    #expect(result.requestExample.contains("curl --location --request POST 'https://api.example.com/pets'"))
    #expect(result.requestExample.contains("--header 'Content-Type: application/json'"))
    #expect(result.requestExample.contains("\"name\": \"name\""))
    #expect(result.responseExample.contains("\"id\": 0"))
    #expect(result.responseExample.contains("\"name\": \"name\""))
}

@Test
func swiftURLSessionGeneratorProducesClientAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPIURLSessionClientGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "Generated/Models.swift" })
    let client = try #require(full.files.first { $0.path == "Generated/APIClient.swift" })

    #expect(models.contents.contains("public struct CreatePetRequest: Codable, Sendable"))
    #expect(models.contents.contains("public var name: String?"))
    #expect(models.contents.contains("public var age: Int?"))
    #expect(models.contents.contains("public struct CreatePetResponse: Codable, Sendable"))
    #expect(client.contents.contains("public struct ExampleAPIClient"))
    #expect(client.contents.contains("public func createPet(body: CreatePetRequest) async throws -> CreatePetResponse"))
    #expect(client.contents.contains("request.httpMethod = \"POST\""))
    #expect(client.contents.contains("request.httpBody = try encoder.encode(body)"))
    #expect(client.contents.contains("return try decoder.decode(CreatePetResponse.self, from: data)"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            serverURL: document.summary.servers.first,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("let client = ExampleAPIClient(baseURL: URL(string: \"https://api.example.com\")!)"))
    #expect(method.requestExample.contains("let response = try await client.createPet(body: CreatePetRequest(/* TODO */))"))
    #expect(method.requestExample.contains("// Referenced models"))
    #expect(method.requestExample.contains("public struct CreatePetRequest: Codable, Sendable"))
    #expect(method.requestExample.contains("public struct CreatePetResponse: Codable, Sendable"))
    #expect(method.responseExample == "let decoded: CreatePetResponse")
}

@Test
func swiftVaporGeneratorProducesRoutesAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPIVaporServerGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "Generated/VaporModels.swift" })
    let routes = try #require(full.files.first { $0.path == "Generated/VaporRoutes.swift" })

    #expect(models.contents.contains("import Vapor"))
    #expect(models.contents.contains("public struct CreatePetRequest: Codable, Sendable"))
    #expect(routes.contents.contains("public protocol ExampleAPIServerHandlers"))
    #expect(routes.contents.contains("public func registerExampleAPIServerRoutes"))
    #expect(routes.contents.contains("app.post(\"pets\")"))
    #expect(routes.contents.contains("func createPet(_ request: Request) async throws -> CreatePetResponse"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("app.post(\"pets\")"))
    #expect(method.requestExample.contains("try await handlers.createPet(request)"))
    #expect(method.requestExample.contains("// Referenced models"))
    #expect(method.requestExample.contains("public struct CreatePetRequest: Codable, Sendable"))
    #expect(method.requestExample.contains("public struct CreatePetResponse: Codable, Sendable"))
    #expect(method.responseExample == "return CreatePetResponse(/* TODO */)")
}

@Test
func javaScriptCoreGeneratorRunsFullAndMethodGeneration() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPIJavaScriptCoreGenerator(
        manifest: SwiftyAPIJavaScriptGeneratorManifest(
            name: "JavaScript Axios Client",
            description: "Example plugin.",
            language: "JavaScript",
            variation: "axios",
            type: "client",
            author: "Example",
            entryPoint: "plugin.js",
            supportedOutputs: [.client, .support]
        ),
        source: """
        function generateFull(payloadJSON) {
            const payload = JSON.parse(payloadJSON);
            return JSON.stringify({
                files: [{
                    path: "Client.js",
                    kind: "client",
                    contents: "// " + payload.document.summary.title
                }],
                diagnostics: [{
                    severity: "info",
                    message: "Generated by JavaScriptCore."
                }]
            });
        }

        function generateMethod(payloadJSON) {
            const payload = JSON.parse(payloadJSON);
            const operation = payload.context.operation;
            return JSON.stringify({
                requestExample: operation.method.toUpperCase() + " " + operation.path,
                responseExample: "handle " + operation.id,
                diagnostics: []
            });
        }
        """
    )

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    #expect(full.files == [
        SwiftyAPIGeneratedFile(
            path: "Client.js",
            kind: .client,
            contents: "// Example API"
        )
    ])
    #expect(full.diagnostics.first?.message == "Generated by JavaScriptCore.")

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample == "GET /pets")
    #expect(method.responseExample == "handle GET /pets")
}

private func makeGeneratorDocument() throws -> OpenAPIDocument {
    try OpenAPIDocument(
        source: """
        openapi: 3.0.3
        info:
          title: Example API
          version: 1.0.0
        servers:
          - url: https://api.example.com
        paths:
          /pets:
            post:
              summary: Create pet
              operationId: createPet
              requestBody:
                required: true
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        name:
                          type: string
                        age:
                          type: integer
              responses:
                '200':
                  description: Created
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          id:
                            type: integer
                          name:
                            type: string
        """,
        format: .yaml
    )
}
