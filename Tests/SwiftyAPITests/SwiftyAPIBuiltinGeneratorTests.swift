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
    #expect(method.responseExample.contains("let response = CreatePetResponse("))
    #expect(method.responseExample.contains("id: 0"))
    #expect(method.responseExample.contains("name: \"name\""))
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
    #expect(method.responseExample.contains("return CreatePetResponse("))
    #expect(method.responseExample.contains("id: 0"))
    #expect(method.responseExample.contains("name: \"name\""))
}

@Test
func typeScriptAxiosGeneratorProducesClientAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPITypeScriptAxiosClientGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "generated/models.ts" })
    let client = try #require(full.files.first { $0.path == "generated/client.ts" })

    #expect(models.contents.contains("export interface CreatePetRequest"))
    #expect(models.contents.contains("name?: string;"))
    #expect(models.contents.contains("age?: number;"))
    #expect(models.contents.contains("export interface CreatePetResponse"))
    #expect(client.contents.contains("import axios, { AxiosInstance } from \"axios\";"))
    #expect(client.contents.contains("export class ExampleAPIClient"))
    #expect(client.contents.contains("async createPet(body: CreatePetRequest): Promise<CreatePetResponse>"))
    #expect(client.contents.contains("const response = await this.http.post<CreatePetResponse>(path, body"))
    #expect(client.contents.contains("return response.data;"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            serverURL: document.summary.servers.first,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("const client = new ExampleAPIClient(\"https://api.example.com\");"))
    #expect(method.requestExample.contains("const response = await client.createPet({"))
    #expect(method.requestExample.contains("satisfies CreatePetRequest"))
    #expect(method.requestExample.contains("// Referenced models"))
    #expect(method.requestExample.contains("export interface CreatePetRequest"))
    #expect(method.requestExample.contains("export interface CreatePetResponse"))
    #expect(method.responseExample.contains("const response = {"))
    #expect(method.responseExample.contains("id: 0"))
    #expect(method.responseExample.contains("name: \"name\""))
    #expect(method.responseExample.contains("satisfies CreatePetResponse"))
}

@Test
func typeScriptNodeGeneratorProducesServerAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPITypeScriptNodeServerGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "generated/models.ts" })
    let server = try #require(full.files.first { $0.path == "generated/server.ts" })

    #expect(models.contents.contains("export interface CreatePetRequest"))
    #expect(models.contents.contains("export interface CreatePetResponse"))
    #expect(server.contents.contains("import { createServer, IncomingMessage } from \"node:http\";"))
    #expect(server.contents.contains("export interface ExampleAPIServerHandlers"))
    #expect(server.contents.contains("createPet(request: NodeAPIRequest): Promise<NodeAPIResponse<CreatePetResponse>>;"))
    #expect(server.contents.contains("{ method: \"POST\", path: \"/pets\", handler: handlers.createPet.bind(handlers) },"))
    #expect(server.contents.contains("async function readJSONBody"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("method: \"POST\""))
    #expect(method.requestExample.contains("path: \"/pets\""))
    #expect(method.requestExample.contains("handler: handlers.createPet"))
    #expect(method.requestExample.contains("// Referenced models"))
    #expect(method.requestExample.contains("export interface CreatePetRequest"))
    #expect(method.requestExample.contains("export interface CreatePetResponse"))
    #expect(method.responseExample.contains("return {"))
    #expect(method.responseExample.contains("id: 0"))
    #expect(method.responseExample.contains("name: \"name\""))
    #expect(method.responseExample.contains("satisfies CreatePetResponse"))
}

@Test
func pythonHTTPXGeneratorProducesClientAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPIPythonHTTPXClientGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "generated/models.py" })
    let client = try #require(full.files.first { $0.path == "generated/client.py" })

    #expect(models.contents.contains("class CreatePetRequest(BaseModel):"))
    #expect(models.contents.contains("name: str | None = None"))
    #expect(models.contents.contains("age: int | None = None"))
    #expect(models.contents.contains("class CreatePetResponse(BaseModel):"))
    #expect(client.contents.contains("import httpx"))
    #expect(client.contents.contains("class ExampleAPIClient:"))
    #expect(client.contents.contains("async def create_pet(self, body: CreatePetRequest) -> CreatePetResponse:"))
    #expect(client.contents.contains("response = await self._client.post(\"/pets\", json=body.model_dump(exclude_none=True))"))
    #expect(client.contents.contains("return CreatePetResponse.model_validate(response.json())"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            serverURL: document.summary.servers.first,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("client = ExampleAPIClient(base_url=\"https://api.example.com\")"))
    #expect(method.requestExample.contains("response = await client.create_pet(body=CreatePetRequest(name=\"name\", age=0))"))
    #expect(method.requestExample.contains("# Referenced models"))
    #expect(method.requestExample.contains("class CreatePetRequest(BaseModel):"))
    #expect(method.requestExample.contains("class CreatePetResponse(BaseModel):"))
    #expect(method.responseExample.contains("response = CreatePetResponse(id=0, name=\"name\")"))
}

@Test
func pythonFastAPIGeneratorProducesServerAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPIPythonFastAPIServerGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "generated/models.py" })
    let server = try #require(full.files.first { $0.path == "generated/server.py" })

    #expect(models.contents.contains("class CreatePetRequest(BaseModel):"))
    #expect(models.contents.contains("class CreatePetResponse(BaseModel):"))
    #expect(server.contents.contains("from fastapi import APIRouter, Response"))
    #expect(server.contents.contains("router = APIRouter()"))
    #expect(server.contents.contains("@router.post(\"/pets\", response_model=CreatePetResponse)"))
    #expect(server.contents.contains("async def create_pet(body: CreatePetRequest) -> CreatePetResponse:"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("@router.post(\"/pets\", response_model=CreatePetResponse)"))
    #expect(method.requestExample.contains("async def create_pet(body: CreatePetRequest) -> CreatePetResponse:"))
    #expect(method.requestExample.contains("# Referenced models"))
    #expect(method.requestExample.contains("class CreatePetRequest(BaseModel):"))
    #expect(method.responseExample.contains("return CreatePetResponse(id=0, name=\"name\")"))
}

@Test
func dotNetHTTPClientGeneratorProducesClientAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPIDotNetHTTPClientGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "Generated/Models.cs" })
    let client = try #require(full.files.first { $0.path == "Generated/ApiClient.cs" })

    #expect(models.contents.contains("public sealed record CreatePetRequest(string Name, int Age);"))
    #expect(models.contents.contains("public sealed record CreatePetResponse(int Id, string Name);"))
    #expect(client.contents.contains("using System.Net.Http.Json;"))
    #expect(client.contents.contains("public sealed class ExampleAPIClient"))
    #expect(client.contents.contains("public async Task<CreatePetResponse> CreatePetAsync(CreatePetRequest body)"))
    #expect(client.contents.contains("var response = await _http.PostAsJsonAsync(\"/pets\", body);"))
    #expect(client.contents.contains("return result ?? throw new InvalidOperationException"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            serverURL: document.summary.servers.first,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("var client = new ExampleAPIClient(new HttpClient { BaseAddress = new Uri(\"https://api.example.com\") });"))
    #expect(method.requestExample.contains("var response = await client.CreatePetAsync(new CreatePetRequest(\"name\", 0));"))
    #expect(method.requestExample.contains("// Referenced models"))
    #expect(method.requestExample.contains("public sealed record CreatePetRequest(string Name, int Age);"))
    #expect(method.responseExample.contains("var response = new CreatePetResponse(0, \"name\");"))
}

@Test
func dotNetMinimalAPIGeneratorProducesServerAndModels() throws {
    let document = try makeGeneratorDocument()
    let operation = try #require(document.summary.operations.first)
    let generator = SwiftyAPIDotNetMinimalAPIServerGenerator()

    let full = try generator.generateFull(from: document, options: SwiftyAPIGeneratorOptions())
    let models = try #require(full.files.first { $0.path == "Generated/Models.cs" })
    let endpoints = try #require(full.files.first { $0.path == "Generated/Endpoints.cs" })

    #expect(models.contents.contains("public sealed record CreatePetRequest(string Name, int Age);"))
    #expect(models.contents.contains("public sealed record CreatePetResponse(int Id, string Name);"))
    #expect(endpoints.contents.contains("public interface IExampleAPIServerHandlers"))
    #expect(endpoints.contents.contains("Task<CreatePetResponse> CreatePetAsync(CreatePetRequest body);"))
    #expect(endpoints.contents.contains("app.MapPost(\"/pets\", async (CreatePetRequest body, IExampleAPIServerHandlers handlers) =>"))
    #expect(endpoints.contents.contains("Results.Ok(await handlers.CreatePetAsync(body)))"))

    let method = try generator.generateMethod(
        from: SwiftyAPIMethodGenerationContext(
            title: document.summary.title,
            version: document.summary.version,
            operation: operation
        ),
        options: SwiftyAPIGeneratorOptions()
    )
    #expect(method.requestExample.contains("app.MapPost(\"/pets\", async (CreatePetRequest body, IExampleAPIServerHandlers handlers) =>"))
    #expect(method.requestExample.contains("Results.Ok(await handlers.CreatePetAsync(body)))"))
    #expect(method.requestExample.contains("// Referenced models"))
    #expect(method.requestExample.contains("public sealed record CreatePetResponse(int Id, string Name);"))
    #expect(method.responseExample.contains("return new CreatePetResponse(0, \"name\");"))
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
