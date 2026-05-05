import Testing
@testable import SwiftyAPI

@Test
func parsesJSONSummaryAndOperations() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalJSON, format: .json)

    #expect(document.summary.openAPIVersion == "3.1.0")
    #expect(document.summary.title == "Example API")
    #expect(document.summary.operations.count == 1)
    #expect(document.summary.operations.first?.id == "GET /pets")
}

@Test
func parsesYAMLSummaryAndOperations() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)

    #expect(document.summary.openAPIVersion == "3.1.0")
    #expect(document.summary.servers == ["https://api.example.com"])
    #expect(document.summary.operations.map(\.id) == ["GET /pets", "POST /pets"])
}

@Test
func generatorCreatesSwiftCases() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)
    let generated = SwiftEndpointGenerator.generate(document: document)

    #expect(generated.contains("public enum ExampleAPIEndpoint"))
    #expect(generated.contains("case listPets = \"GET /pets\""))
    #expect(generated.contains("case createPet = \"POST /pets\""))
}

@Test
func convertsJSONToYAML() throws {
    let yaml = try OpenAPIFormatTranslator.convert(
        source: OpenAPITemplates.minimalJSON,
        from: .json,
        to: .yaml
    )

    #expect(yaml.contains("openapi: 3.1.0"))
    #expect(yaml.contains("title: Example API"))
    #expect(try OpenAPIDocument(source: yaml, format: .yaml).summary.operations.count == 1)
}

@Test
func convertsYAMLToJSON() throws {
    let json = try OpenAPIFormatTranslator.convert(
        source: OpenAPITemplates.minimalYAML,
        from: .yaml,
        to: .json
    )

    #expect(json.contains("\"openapi\" : \"3.1.0\""))
    #expect(try OpenAPIDocument(source: json, format: .json).summary.operations.count == 2)
}
