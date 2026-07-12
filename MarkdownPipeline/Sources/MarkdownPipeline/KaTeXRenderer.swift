import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif

final class KaTeXRenderer {
    #if canImport(JavaScriptCore)
    private let context: JSContext
    private let isReady: Bool
    #else
    private let isReady = false
    #endif

    init() {
        #if canImport(JavaScriptCore)
        let context = JSContext()!
        var ready = false
        context.exceptionHandler = { _, _ in }
        if let script = try? ResourceLoader.stringResource("katex.min.js") {
            context.evaluateScript(script)
            ready = context.objectForKeyedSubscript("katex") != nil
        }
        self.context = context
        self.isReady = ready
        #endif
    }

    func render(_ source: String, displayMode: Bool) -> String? {
        guard isReady else { return nil }
        #if canImport(JavaScriptCore)
        guard let katex = context.objectForKeyedSubscript("katex") else { return nil }
        let options: [String: Any] = [
            "displayMode": displayMode,
            "output": "htmlAndMathml",
            "throwOnError": true,
            "trust": false,
        ]
        guard let result = katex.invokeMethod("renderToString", withArguments: [source, options]),
              result.isUndefined == false,
              result.isNull == false else {
            context.exception = nil
            return nil
        }
        return result.toString()
        #else
        return nil
        #endif
    }
}
