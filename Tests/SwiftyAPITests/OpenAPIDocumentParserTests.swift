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
func parsesJSONRequestAndResponseDetails() throws {
    let source = """
    {
      "openapi": "3.1.0",
      "info": { "title": "Detailed API", "version": "1.0.0" },
      "components": {
        "parameters": {
          "Limit": {
            "name": "limit",
            "in": "query",
            "required": true,
            "description": "Maximum number of records.",
            "schema": { "type": "integer" }
          }
        },
        "responses": {
          "NotFound": {
            "description": "The item was not found.",
            "content": { "application/json": { "schema": { "type": "object" } } }
          }
        }
      },
      "paths": {
        "/items": {
          "get": {
            "summary": "List items",
            "description": "Returns available items.",
            "parameters": [{ "$ref": "#/components/parameters/Limit" }],
            "responses": {
              "200": {
                "description": "Successful response.",
                "content": { "application/json": { "schema": { "type": "array" } } }
              },
              "404": { "$ref": "#/components/responses/NotFound" }
            }
          },
          "post": {
            "summary": "Create item",
            "requestBody": {
              "required": true,
              "description": "Item payload.",
              "content": { "application/json": { "schema": { "type": "object" } } }
            },
            "responses": {
              "201": { "description": "Created." }
            }
          }
        }
      }
    }
    """

    let document = try OpenAPIDocument(source: source, format: .json)
    let listItems = try #require(document.summary.operations.first { $0.id == "GET /items" })
    let createItem = try #require(document.summary.operations.first { $0.id == "POST /items" })

    #expect(listItems.description == "Returns available items.")
    #expect(listItems.parameters.first?.name == "limit")
    #expect(listItems.parameters.first?.location == "query")
    #expect(listItems.parameters.first?.isRequired == true)
    #expect(listItems.parameters.first?.type == "integer")
    #expect(listItems.responses.map(\.statusCode) == ["200", "404"])
    #expect(listItems.responses.last?.description == "The item was not found.")
    #expect(listItems.responses.first?.contentTypes == ["application/json"])
    #expect(createItem.requestBody?.isRequired == true)
    #expect(createItem.requestBody?.contentTypes == ["application/json"])
}

@Test
func parsesYAMLSummaryAndOperations() throws {
    let document = try OpenAPIDocument(source: OpenAPITemplates.minimalYAML, format: .yaml)

    #expect(document.summary.openAPIVersion == "3.1.0")
    #expect(document.summary.servers == ["https://api.example.com"])
    #expect(document.summary.operations.map(\.id) == ["GET /pets", "POST /pets"])
}

@Test
func parsesYAMLRequestAndResponseDetails() throws {
    let source = """
    openapi: 3.1.0
    info:
      title: Detailed YAML API
      version: 1.0.0
    components:
      parameters:
        Page:
          name: page
          in: query
          required: true
          description: Page number.
          schema:
            type: integer
      responses:
        BadRequest:
          description: Bad request.
          content:
            application/json:
              schema:
                type: object
    paths:
      /events:
        get:
          summary: List events
          description: Returns upcoming events.
          parameters:
            - $ref: '#/components/parameters/Page'
          responses:
            '200':
              description: Success.
              content:
                application/json:
                  schema:
                    type: object
            '400':
              $ref: '#/components/responses/BadRequest'
        post:
          summary: Create event
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  type: object
          responses:
            '201':
              description: Created.
    """

    let document = try OpenAPIDocument(source: source, format: .yaml)
    let listEvents = try #require(document.summary.operations.first { $0.id == "GET /events" })
    let createEvent = try #require(document.summary.operations.first { $0.id == "POST /events" })

    #expect(listEvents.description == "Returns upcoming events.")
    #expect(listEvents.parameters.first?.name == "page")
    #expect(listEvents.parameters.first?.isRequired == true)
    #expect(listEvents.parameters.first?.type == "integer")
    #expect(listEvents.responses.map(\.statusCode) == ["200", "400"])
    #expect(listEvents.responses.last?.description == "Bad request.")
    #expect(createEvent.requestBody?.isRequired == true)
    #expect(createEvent.requestBody?.contentTypes == ["application/json"])
}

@Test
func parsesYAMLReferencedRequestBodySchemaFields() throws {
    let source = """
    openapi: 3.0.3
    info:
      title: Client Tracker API
      version: 1.0.0
    servers:
      - url: /
    paths:
      /tracking/init-data:
        post:
          summary: Initialize click data tracking
          operationId: initData
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/InitData'
          responses:
            '200':
              description: Init data stored
      /tracking/event-info:
        post:
          summary: Store event tracking information
          operationId: eventTracking
          parameters:
            - in: header
              name: User-Agent
              required: true
              schema:
                type: string
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/ClickTrackEventsRequestDto'
          responses:
            '204':
              description: No content
    components:
      schemas:
        InitData:
          type: object
          properties:
            timeStamp:
              type: string
              format: date-time
            insightData:
              $ref: '#/components/schemas/InsightData'
            cookies:
              type: boolean
          additionalProperties: true
        ClickTrackEventsRequestDto:
          type: object
          description: Single click track event request.
          properties:
            elementIdentifier:
              type: string
            eventType:
              type: string
            timestamp:
              type: string
              format: date-time
              description: ZonedDateTime in ISO-8601 format
          required:
            - elementIdentifier
            - eventType
            - timestamp
          additionalProperties: false
    """

    let document = try OpenAPIDocument(source: source, format: .yaml)
    let initData = try #require(document.summary.operations.first { $0.id == "POST /tracking/init-data" })
    let eventInfo = try #require(document.summary.operations.first { $0.id == "POST /tracking/event-info" })

    #expect(initData.requestBody?.schemaName == "InitData")
    #expect(initData.requestBody?.schemaFields.map(\.name) == ["timeStamp", "insightData", "cookies"])
    #expect(initData.requestBody?.schemaFields.first { $0.name == "insightData" }?.type == "InsightData")
    #expect(eventInfo.parameters.first?.name == "User-Agent")
    #expect(eventInfo.parameters.first?.location == "header")
    #expect(eventInfo.parameters.first?.isRequired == true)
    #expect(eventInfo.requestBody?.schemaName == "ClickTrackEventsRequestDto")
    #expect(eventInfo.requestBody?.schemaFields.filter(\.isRequired).map(\.name) == ["elementIdentifier", "eventType", "timestamp"])
    #expect(eventInfo.requestBody?.schemaFields.first { $0.name == "timestamp" }?.description == "ZonedDateTime in ISO-8601 format")
    #expect(eventInfo.responses.first?.statusCode == "204")
    #expect(eventInfo.responses.first?.description == "No content")
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
