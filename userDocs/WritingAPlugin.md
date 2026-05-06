# Writing a SwiftyAPI Generator Plugin

SwiftyAPI generators produce code from an OpenAPI document. A generator can be compiled Swift code or a JavaScript plugin executed at runtime through Apple's JavaScriptCore framework.

This guide covers the JavaScript plugin path.

## Plugin Shape

A JavaScript plugin has two parts:

- A manifest that describes the generator for display and selection.
- A JavaScript file that defines `generateFull(payloadJSON)` and `generateMethod(payloadJSON)`.

See the commented example at `Examples/Plugins/javascript-axios-client/plugin.js`.

## Manifest Fields

```json
{
  "name": "JavaScript Axios Client",
  "description": "Generates an Axios client from an OpenAPI document.",
  "language": "JavaScript",
  "variation": "Axios",
  "type": "client",
  "author": "example",
  "version": "1.0.0",
  "entryPoint": "plugin.js",
  "supportedOutputs": ["client", "model", "support"]
}
```

Field meanings:

- `name`: The display name shown in the generator selector.
- `description`: A paragraph explaining what the generator creates.
- `language`: The generated language, such as `JavaScript`, `Swift`, `Python`, or `C#`.
- `variation`: The library, framework, platform, or style used to distinguish similar generators.
- `type`: Either `client` or `server`.
- `author`: The author shown in the generator identity. Built-ins use `builtin`.
- `version`: Optional plugin version text.
- `entryPoint`: The JavaScript file to load.
- `supportedOutputs`: Generated file categories. Supported values are `endpoints`, `model`, `request`, `client`, `mock`, and `support`.

## Required JavaScript Functions

`generateFull(payloadJSON)` creates complete files for the Generated tab.

```javascript
function generateFull(payloadJSON) {
  const payload = JSON.parse(payloadJSON);

  return JSON.stringify({
    files: [
      {
        path: "generated/client.js",
        kind: "client",
        contents: "// " + payload.document.summary.title
      }
    ],
    diagnostics: []
  });
}
```

`generateMethod(payloadJSON)` creates the request and response examples shown in the Design tab for the selected operation.

```javascript
function generateMethod(payloadJSON) {
  const payload = JSON.parse(payloadJSON);
  const operation = payload.context.operation;

  return JSON.stringify({
    requestExample: operation.method.toUpperCase() + " " + operation.path,
    responseExample: "handle " + operation.id,
    diagnostics: []
  });
}
```

Both functions receive a JSON string. They may return a JavaScript object or a JSON string. Returning `JSON.stringify(...)` is recommended because it makes plugin debugging simpler.

## Payload Overview

`generateFull` receives:

```text
payload.document.format
payload.document.source
payload.document.summary.openAPIVersion
payload.document.summary.title
payload.document.summary.version
payload.document.summary.servers
payload.document.summary.operations
payload.options
```

`generateMethod` receives:

```text
payload.context.title
payload.context.version
payload.context.serverURL
payload.context.operation
payload.options
```

Operations include:

```text
id
method
path
operationID
summary
description
parameters
requestBody
responses
```

Request bodies and responses include parsed schema names and schema fields when SwiftyAPI can infer them.

## Result Shape

Full generation returns:

```json
{
  "files": [
    {
      "path": "generated/client.js",
      "kind": "client",
      "contents": "..."
    }
  ],
  "diagnostics": [
    {
      "severity": "info",
      "message": "Generated successfully."
    }
  ]
}
```

Method generation returns:

```json
{
  "requestExample": "...",
  "responseExample": "...",
  "diagnostics": []
}
```

Diagnostics support `info`, `warning`, and `error`.

## Registering a Plugin in an App

Create a `SwiftyAPIJavaScriptCoreGenerator` with a manifest and JavaScript source, then pass it to `SwiftyAPIView` along with the built-in generators.

```swift
import SwiftUI
import SwiftyAPI

struct PluginBackedAPIView: View {
    let pluginGenerator: any SwiftyAPICodeGenerator

    init() {
        let sourceURL = Bundle.main.url(forResource: "plugin", withExtension: "js")!
        let source = try! String(contentsOf: sourceURL, encoding: .utf8)

        let manifest = SwiftyAPIJavaScriptGeneratorManifest(
            name: "JavaScript Axios Client",
            description: "Generates an Axios client from an OpenAPI document.",
            language: "JavaScript",
            variation: "Axios",
            type: "client",
            author: "example",
            version: "1.0.0",
            entryPoint: "plugin.js",
            supportedOutputs: [.client, .model, .support]
        )

        pluginGenerator = SwiftyAPIJavaScriptCoreGenerator(
            manifest: manifest,
            source: source
        )
    }

    var body: some View {
        SwiftyAPIView(
            generators: SwiftyAPIBuiltinGenerators.all + [pluginGenerator]
        )
    }
}
```

If your app lets users install plugins at runtime, load the manifest and JavaScript from your chosen plugin folder, validate the manifest, create the generator, and append it to the generator list you pass into `SwiftyAPIView`.

## Practical Rules

- Keep plugin functions deterministic. They should use only the payload and local helper functions.
- Avoid network calls and filesystem assumptions inside JavaScriptCore plugins.
- Return diagnostics instead of throwing when a document is valid but unsupported.
- Throw only for plugin bugs or unrecoverable conditions.
- Always include stable file paths in `generateFull` results.
- Make `generateMethod` concise; it is shown in the Design tab beside the operation details.
