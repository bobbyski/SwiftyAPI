import SwiftUI

enum SwiftyAPIMonacoTheme: String, Equatable {
    case designBlue = "swiftyapi-design-blue"
    case light = "vs"
    case dark = "vs-dark"
}

struct SwiftyAPIMonacoEditor: View {
    @Binding var text: String

    var language: String
    var theme: SwiftyAPIMonacoTheme
    var showsGutter: Bool
    var isEditable: Bool

    var body: some View {
        Representable(
            text: $text,
            language: language,
            theme: theme,
            showsGutter: showsGutter,
            isEditable: isEditable
        )
    }
}

#if os(macOS)
import WebKit

private extension SwiftyAPIMonacoEditor {
    struct Representable: NSViewRepresentable {
        @Binding var text: String

        var language: String
        var theme: SwiftyAPIMonacoTheme
        var showsGutter: Bool
        var isEditable: Bool

        func makeCoordinator() -> Coordinator {
            Coordinator(text: $text)
        }

        func makeNSView(context: Context) -> WKWebView {
            let contentController = WKUserContentController()
            contentController.add(context.coordinator, name: Coordinator.messageName)

            let configuration = WKWebViewConfiguration()
            configuration.userContentController = contentController

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.setValue(false, forKey: "drawsBackground")
            webView.allowsMagnification = false
            webView.navigationDelegate = context.coordinator
            webView.loadHTMLString(Self.html, baseURL: nil)
            context.coordinator.apply(
                text: text,
                language: language,
                theme: theme,
                showsGutter: showsGutter,
                isEditable: isEditable,
                to: webView
            )
            return webView
        }

        func updateNSView(_ webView: WKWebView, context: Context) {
            context.coordinator.apply(
                text: text,
                language: language,
                theme: theme,
                showsGutter: showsGutter,
                isEditable: isEditable,
                to: webView
            )
        }

        static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
            nsView.navigationDelegate = nil
            nsView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.messageName)
        }

        final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
            static let messageName = "swiftyapiTextChanged"

            private var text: Binding<String>
            private var isPageReady = false
            private var pendingText: String?
            private var pendingOptions: EditorOptions?
            var lastAppliedText: String?
            private var lastAppliedOptions: EditorOptions?

            init(text: Binding<String>) {
                self.text = text
            }

            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                guard let value = message.body as? String, value != text.wrappedValue else {
                    return
                }

                text.wrappedValue = value
                lastAppliedText = value
            }

            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                isPageReady = true
                applyPending(to: webView)
            }

            func apply(
                text: String,
                language: String,
                theme: SwiftyAPIMonacoTheme,
                showsGutter: Bool,
                isEditable: Bool,
                to webView: WKWebView
            ) {
                let options = EditorOptions(
                    language: language,
                    theme: theme.rawValue,
                    showsGutter: showsGutter,
                    isEditable: isEditable
                )

                pendingText = text
                pendingOptions = options
                applyPending(to: webView)
            }

            private func applyPending(to webView: WKWebView) {
                guard isPageReady else {
                    return
                }

                if let options = pendingOptions,
                   lastAppliedOptions != options {
                    webView.evaluateJavaScript("window.swiftyAPISetOptions(\(Self.json(options.dictionary)));")
                    lastAppliedOptions = options
                }

                if let text = pendingText,
                   lastAppliedText != text {
                    webView.evaluateJavaScript("window.swiftyAPISetText(\(Self.json(text)));")
                    lastAppliedText = text
                }
            }

            private static func json(_ value: String) -> String {
                guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                      let json = String(data: data, encoding: .utf8),
                      json.hasPrefix("["),
                      json.hasSuffix("]") else {
                    return "\"\""
                }
                return String(json.dropFirst().dropLast())
            }

            private static func json(_ value: [String: Any]) -> String {
                guard let data = try? JSONSerialization.data(withJSONObject: value),
                      let json = String(data: data, encoding: .utf8) else {
                    return "{}"
                }
                return json
            }
        }

        struct EditorOptions: Equatable {
            var language: String
            var theme: String
            var showsGutter: Bool
            var isEditable: Bool

            var dictionary: [String: Any] {
                [
                    "language": language,
                    "theme": theme,
                    "showsGutter": showsGutter,
                    "isEditable": isEditable
                ]
            }
        }

        static let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body, #editor, #fallback {
              width: 100%;
              height: 100%;
              margin: 0;
              overflow: hidden;
            }

            body {
              background: #0f172a;
            }

            #fallback {
              box-sizing: border-box;
              border: 0;
              outline: 0;
              resize: none;
              padding: 14px;
              white-space: pre;
              overflow: auto;
              color: #9cdcfe;
              background: #0f172a;
              font: 12px/1.55 Menlo, Monaco, Consolas, "Courier New", monospace;
            }

            body.light #fallback {
              color: #1f2937;
              background: #ffffff;
            }

            body.dark #fallback {
              color: #d4d4d4;
              background: #1e1e1e;
            }
          </style>
        </head>
        <body>
          <div id="editor"></div>
          <textarea id="fallback" spellcheck="false"></textarea>
          <script>
            const state = {
              text: "",
              options: {
                language: "plaintext",
                theme: "swiftyapi-design-blue",
                showsGutter: false,
                isEditable: false
              },
              editor: null,
              monacoReady: false,
              suppressChange: false
            };

            const fallback = document.getElementById("fallback");
            fallback.addEventListener("input", () => {
              state.text = fallback.value;
              if (state.options.isEditable && window.webkit?.messageHandlers?.swiftyapiTextChanged) {
                window.webkit.messageHandlers.swiftyapiTextChanged.postMessage(state.text);
              }
            });

            function applyFallback() {
              fallback.value = state.text;
              fallback.readOnly = !state.options.isEditable;
              document.body.classList.toggle("light", state.options.theme === "vs");
              document.body.classList.toggle("dark", state.options.theme === "vs-dark");
            }

            function editorOptions() {
              const gutter = state.options.showsGutter;
              return {
                value: state.text,
                language: state.options.language,
                theme: state.options.theme,
                readOnly: !state.options.isEditable,
                automaticLayout: true,
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                fontFamily: 'Menlo, Monaco, Consolas, "Courier New", monospace',
                fontSize: 12,
                lineHeight: 19,
                wordWrap: "on",
                lineNumbers: gutter ? "on" : "off",
                glyphMargin: false,
                folding: gutter,
                lineDecorationsWidth: gutter ? 10 : 0,
                lineNumbersMinChars: gutter ? 3 : 0,
                overviewRulerLanes: gutter ? 2 : 0,
                renderLineHighlight: gutter ? "line" : "none",
                padding: { top: 12, bottom: 12 },
                scrollbar: {
                  verticalScrollbarSize: 9,
                  horizontalScrollbarSize: 9
                }
              };
            }

            function applyEditorOptions() {
              applyFallback();
              if (!state.editor || !state.monacoReady) {
                return;
              }

              monaco.editor.setTheme(state.options.theme);
              const model = state.editor.getModel();
              if (model) {
                monaco.editor.setModelLanguage(model, state.options.language);
              }
              state.editor.updateOptions(editorOptions());
            }

            window.swiftyAPISetText = function(value) {
              state.text = value ?? "";
              applyFallback();
              if (!state.editor) {
                return;
              }

              if (state.editor.getValue() !== state.text) {
                state.suppressChange = true;
                state.editor.setValue(state.text);
                state.suppressChange = false;
              }
            };

            window.swiftyAPISetOptions = function(options) {
              state.options = Object.assign(state.options, options ?? {});
              applyEditorOptions();
            };

            function createEditor() {
              fallback.style.display = "none";
              monaco.editor.defineTheme("swiftyapi-design-blue", {
                base: "vs-dark",
                inherit: true,
                rules: [
                  { token: "", foreground: "d4e7ff" },
                  { token: "string", foreground: "9cdcfe" },
                  { token: "keyword", foreground: "c586c0" },
                  { token: "number", foreground: "b5cea8" },
                  { token: "comment", foreground: "6a9955" }
                ],
                colors: {
                  "editor.background": "#0f172a",
                  "editor.foreground": "#d4e7ff",
                  "editorCursor.foreground": "#c4b5fd",
                  "editorLineNumber.foreground": "#52627a",
                  "editor.selectionBackground": "#27496d",
                  "editor.inactiveSelectionBackground": "#1f3654"
                }
              });

              state.monacoReady = true;
              state.editor = monaco.editor.create(document.getElementById("editor"), editorOptions());
              state.editor.onDidChangeModelContent(() => {
                if (state.suppressChange) {
                  return;
                }
                state.text = state.editor.getValue();
                applyFallback();
                if (state.options.isEditable && window.webkit?.messageHandlers?.swiftyapiTextChanged) {
                  window.webkit.messageHandlers.swiftyapiTextChanged.postMessage(state.text);
                }
              });
              applyEditorOptions();
            }

            applyFallback();

            const loader = document.createElement("script");
            loader.src = "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs/loader.js";
            loader.onload = () => {
              require.config({ paths: { vs: "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs" } });
              require(["vs/editor/editor.main"], createEditor);
            };
            document.head.appendChild(loader);
          </script>
        </body>
        </html>
        """
    }
}
#else
private extension SwiftyAPIMonacoEditor {
    struct Representable: View {
        @Binding var text: String

        var language: String
        var theme: SwiftyAPIMonacoTheme
        var showsGutter: Bool
        var isEditable: Bool

        var body: some View {
            if isEditable {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
            } else {
                ScrollView {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
    }
}
#endif
