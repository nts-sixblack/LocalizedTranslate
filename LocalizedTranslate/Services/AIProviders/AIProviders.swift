//
//  AIProviders.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 2 on 10/4/26.
//

import Foundation
import Combine

// MARK: - AI Provider Types & Protocols
public enum AIProviderType: String, CaseIterable, Identifiable, Codable, Sendable {
    case openAI = "OpenAI (GPT-4o / mini)"
    case anthropicClaude = "Anthropic Claude (3.5 Sonnet)"
    case googleGemini = "Google Gemini (2.0 Flash)"
    case deepSeek = "DeepSeek (V3 / R1)"
    case ollama = "Ollama (Local / Offline)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropicClaude: return "Claude"
        case .googleGemini: return "Gemini"
        case .deepSeek: return "DeepSeek"
        case .ollama: return "Ollama"
        }
    }

    public var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropicClaude: return "claude-3-5-sonnet-latest"
        case .googleGemini: return "gemini-2.0-flash"
        case .deepSeek: return "deepseek-chat"
        case .ollama: return "llama3.2"
        }
    }

    public var keychainAccountKey: String {
        switch self {
        case .openAI: return "apiKey_openai"
        case .anthropicClaude: return "apiKey_claude"
        case .googleGemini: return "apiKey_gemini"
        case .deepSeek: return "apiKey_deepseek"
        case .ollama: return "endpoint_ollama"
        }
    }
}

public struct BatchTranslationInput: Codable, Sendable {
    public let id: Int
    public let text: String
    public let context: String?

    public init(id: Int, text: String, context: String? = nil) {
        self.id = id
        self.text = text
        self.context = context
    }
}

public struct BatchTranslationResponsePayload: Codable, Sendable {
    public let translations: [String]
}

public protocol AIProvider: Sendable {
    var type: AIProviderType { get }
    var model: String { get }
    func translateBatch(
        inputs: [BatchTranslationInput],
        sourceLanguage: String,
        targetLanguage: String,
        appContext: String?
    ) async throws -> [String]
    func testConnection() async throws -> Bool
}

public enum AIProviderError: LocalizedError {
    case missingAPIKey(AIProviderType)
    case invalidResponse(String)
    case networkError(String)
    case rateLimited
    case serverError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let type):
            return "Missing API key for \(type.rawValue). Please configure in Settings."
        case .invalidResponse(let msg):
            return "Invalid AI response: \(msg)"
        case .networkError(let msg):
            return "Network connection error: \(msg)"
        case .rateLimited:
            return "Rate limited by AI provider (HTTP 429). Please wait a moment."
        case .serverError(let code, let msg):
            return "Server returned error \(code): \(msg)"
        }
    }
}

// MARK: - Error & JSON Parsers
public struct ErrorResponseParser {
    public static func extractMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let dict = obj as? [String: Any] {
            return parseDict(dict)
        }
        if let list = obj as? [[String: Any]], let first = list.first {
            return parseDict(first)
        }
        return nil
    }

    private static func parseDict(_ dict: [String: Any]) -> String? {
        if let errObj = dict["error"] as? [String: Any], let msg = errObj["message"] as? String {
            return msg
        }
        if let errMsg = dict["error"] as? String {
            return errMsg
        }
        if let msg = dict["message"] as? String {
            return msg
        }
        return nil
    }
}

public struct JSONResponseParser {
    public static func cleanAndDecode(from text: String, expectedCount: Int) throws -> [String] {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown backticks ```json ... ``` or ``` ... ```
        if raw.contains("```") {
            if let startRange = raw.range(of: "```json") {
                raw = String(raw[startRange.upperBound...])
            } else if let startRange = raw.range(of: "```") {
                raw = String(raw[startRange.upperBound...])
            }
            if let endRange = raw.range(of: "```", options: .backwards) {
                raw = String(raw[..<endRange.lowerBound])
            }
            raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try extracting outermost JSON object or array
        var jsonSnippet = raw
        if let firstBrace = raw.firstIndex(of: "{"),
           let lastBrace = raw.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            jsonSnippet = String(raw[firstBrace...lastBrace])
        } else if let firstBracket = raw.firstIndex(of: "["),
                  let lastBracket = raw.lastIndex(of: "]"),
                  firstBracket <= lastBracket {
            jsonSnippet = String(raw[firstBracket...lastBracket])
        }

        guard let data = jsonSnippet.data(using: .utf8) else {
            throw AIProviderError.invalidResponse("Could not convert response text to UTF-8 data")
        }

        // 1. Try decoding { "translations": [...] }
        if let decoded = try? JSONDecoder().decode(BatchTranslationResponsePayload.self, from: data) {
            return decoded.translations
        }

        // 2. Try decoding direct array [ "...", "..." ]
        if let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }

        // 3. Try generic JSON dictionary
        if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let list = dict["translations"] as? [String] {
                return list
            }
            // If dictionary has numeric keys "0", "1", ...
            let sortedKeys = dict.keys.sorted { (Int($0) ?? 999) < (Int($1) ?? 999) }
            let values = sortedKeys.compactMap { dict[$0] as? String }
            if !values.isEmpty {
                return values
            }
        }

        throw AIProviderError.invalidResponse("Could not parse JSON translations from model response: \(raw.prefix(120))...")
    }
}

// MARK: - Prompt Builder
public struct AIPromptBuilder {
    public static func systemPrompt(sourceLang: String, targetLang: String, appContext: String?) -> String {
        var base = """
        You are an expert native localization engine translating software UI strings.
        Target Language: \(targetLang)
        Source Language: \(sourceLang)

        CRITICAL RULES:
        1. Preserve all placeholders and format specifiers EXACTLY (e.g. %@, %d, %ld, %1$@, %2$f, \\n, HTML tags).
        2. Keep technical brand acronyms and terms untranslated (e.g. URL, ID, API, Wi-Fi, AirDrop, Face ID, etc.).
        3. Match the natural tone of modern macOS/iOS apps: concise, polished, native UI terminology.
        4. Return ONLY a valid JSON object matching this schema:
           {
             "translations": ["translated_string_0", "translated_string_1", ...]
           }
        The array of translations MUST strictly correspond 1-to-1 with the order of input entries.
        """
        if let context = appContext, !context.isEmpty {
            base += "\nApplication & Screen Context: \(context)"
        }
        return base
    }

    public static func userPrompt(inputs: [BatchTranslationInput]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = (try? encoder.encode(inputs)) ?? Data()
        let jsonStr = String(data: data, encoding: .utf8) ?? "[]"
        return "Translate the following entries:\n\(jsonStr)"
    }
}

// MARK: - OpenAI / DeepSeek Provider
public final class OpenAICompatibleProvider: AIProvider, @unchecked Sendable {
    public let type: AIProviderType
    public let model: String
    private let apiKey: String
    private let endpoint: URL

    public init(
        type: AIProviderType,
        apiKey: String,
        model: String? = nil,
        endpointURL: URL? = nil
    ) {
        self.type = type
        self.apiKey = apiKey
        self.model = model ?? type.defaultModel
        if let custom = endpointURL {
            self.endpoint = custom
        } else if type == .deepSeek {
            self.endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
        } else {
            self.endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        }
    }

    public func translateBatch(
        inputs: [BatchTranslationInput],
        sourceLanguage: String,
        targetLanguage: String,
        appContext: String?
    ) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey(type) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if type == .googleGemini {
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        }
        request.timeoutInterval = 60

        let systemMsg = AIPromptBuilder.systemPrompt(
            sourceLang: sourceLanguage,
            targetLang: targetLanguage,
            appContext: appContext
        )
        let userMsg = AIPromptBuilder.userPrompt(inputs: inputs)

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemMsg],
                ["role": "user", "content": userMsg]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.networkError("No HTTP response")
        }

        if httpResponse.statusCode == 429 {
            throw AIProviderError.rateLimited
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = ErrorResponseParser.extractMessage(from: data) ?? (String(data: data, encoding: .utf8) ?? "Unknown server error")
            throw AIProviderError.serverError(httpResponse.statusCode, errorMsg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProviderError.invalidResponse("Could not parse response message")
        }

        return try JSONResponseParser.cleanAndDecode(from: content, expectedCount: inputs.count)
    }

    public func testConnection() async throws -> Bool {
        let dummy = [BatchTranslationInput(id: 0, text: "Hello", context: "greeting")]
        _ = try await translateBatch(inputs: dummy, sourceLanguage: "en", targetLanguage: "vi", appContext: nil)
        return true
    }
}

// MARK: - Anthropic Claude Provider
public final class ClaudeProvider: AIProvider, @unchecked Sendable {
    public let type: AIProviderType = .anthropicClaude
    public let model: String
    private let apiKey: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(apiKey: String, model: String? = nil) {
        self.apiKey = apiKey
        self.model = model ?? AIProviderType.anthropicClaude.defaultModel
    }

    public func translateBatch(
        inputs: [BatchTranslationInput],
        sourceLanguage: String,
        targetLanguage: String,
        appContext: String?
    ) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey(type) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let systemMsg = AIPromptBuilder.systemPrompt(
            sourceLang: sourceLanguage,
            targetLang: targetLanguage,
            appContext: appContext
        )
        let userMsg = AIPromptBuilder.userPrompt(inputs: inputs)

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemMsg,
            "messages": [
                ["role": "user", "content": userMsg]
            ],
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.networkError("No HTTP response")
        }

        if httpResponse.statusCode == 429 {
            throw AIProviderError.rateLimited
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = ErrorResponseParser.extractMessage(from: data) ?? (String(data: data, encoding: .utf8) ?? "Unknown server error")
            throw AIProviderError.serverError(httpResponse.statusCode, errorMsg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let contentList = json?["content"] as? [[String: Any]],
              let first = contentList.first,
              let text = first["text"] as? String else {
            throw AIProviderError.invalidResponse("Could not parse Claude response text")
        }

        return try JSONResponseParser.cleanAndDecode(from: text, expectedCount: inputs.count)
    }

    public func testConnection() async throws -> Bool {
        let dummy = [BatchTranslationInput(id: 0, text: "Hello", context: "greeting")]
        _ = try await translateBatch(inputs: dummy, sourceLanguage: "en", targetLanguage: "vi", appContext: nil)
        return true
    }
}

// MARK: - Local Ollama Provider (100% Offline)
public final class OllamaProvider: AIProvider, @unchecked Sendable {
    public let type: AIProviderType = .ollama
    public let model: String
    private let hostURL: URL

    public init(model: String? = nil, host: String? = nil) {
        self.model = model ?? AIProviderType.ollama.defaultModel
        let rawHost = (host ?? "http://localhost:11434").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.hostURL = URL(string: "\(rawHost)/api/chat") ?? URL(string: "http://localhost:11434/api/chat")!
    }

    public func translateBatch(
        inputs: [BatchTranslationInput],
        sourceLanguage: String,
        targetLanguage: String,
        appContext: String?
    ) async throws -> [String] {
        var request = URLRequest(url: hostURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let systemMsg = AIPromptBuilder.systemPrompt(
            sourceLang: sourceLanguage,
            targetLang: targetLanguage,
            appContext: appContext
        )
        let userMsg = AIPromptBuilder.userPrompt(inputs: inputs)

        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "format": "json",
            "messages": [
                ["role": "system", "content": systemMsg],
                ["role": "user", "content": userMsg]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AIProviderError.networkError("Ollama is not running. Start with 'ollama serve'")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let message = json?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProviderError.invalidResponse("Ollama returned non-JSON structure")
        }
        return try JSONResponseParser.cleanAndDecode(from: content, expectedCount: inputs.count)
    }

    public func testConnection() async throws -> Bool {
        let dummy = [BatchTranslationInput(id: 0, text: "Ping")]
        _ = try await translateBatch(inputs: dummy, sourceLanguage: "en", targetLanguage: "vi", appContext: nil)
        return true
    }
}

// MARK: - AI Provider Factory
public struct AIProviderFactory {
    public static func create(
        type: AIProviderType,
        apiKey: String? = nil,
        model: String? = nil,
        customHost: String? = nil,
        keyRetriever: ((String) -> String?)? = nil
    ) -> AIProvider {
        let rawKey = apiKey ?? keyRetriever?(type.keychainAccountKey) ?? ""
        let resolvedKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .openAI:
            return OpenAICompatibleProvider(type: .openAI, apiKey: resolvedKey, model: model)
        case .deepSeek:
            return OpenAICompatibleProvider(type: .deepSeek, apiKey: resolvedKey, model: model)
        case .anthropicClaude:
            return ClaudeProvider(apiKey: resolvedKey, model: model)
        case .googleGemini:
            let geminiURL = URL(
                string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
            )
            return OpenAICompatibleProvider(
                type: .googleGemini,
                apiKey: resolvedKey,
                model: model ?? type.defaultModel,
                endpointURL: geminiURL
            )
        case .ollama:
            let resolvedHost = customHost ?? keyRetriever?(type.keychainAccountKey)
            return OllamaProvider(model: model, host: resolvedHost)
        }
    }
}

// MARK: - Translation Pipeline Manager
public struct TranslationWorkItem: Identifiable, Sendable {
    public let id: String
    public let key: String
    public let sourceText: String
    public let context: String?
    public let targetLanguage: String

    public init(
        key: String,
        sourceText: String,
        context: String? = nil,
        targetLanguage: String
    ) {
        self.id = "\(key)_\(targetLanguage)"
        self.key = key
        self.sourceText = sourceText
        self.context = context
        self.targetLanguage = targetLanguage
    }
}

public struct TranslationBatchResult: Sendable {
    public let item: TranslationWorkItem
    public let translatedText: String?
    public let error: String?
}

@MainActor
public final class TranslationManager: ObservableObject {
    @Published public var isTranslating = false
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var completedCount: Int = 0
    @Published public var successCount: Int = 0
    @Published public var errorCount: Int = 0
    @Published public var lastErrorMessage: String?
    @Published public var totalCount: Int = 0
    @Published public var activeLanguage: String = ""

    private var currentTask: Task<Void, Never>?
    private let batchSize = 15

    public init() {}

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isTranslating = false
        statusMessage = "Translation cancelled by user."
    }

    public func translateWorkItems(
        items: [TranslationWorkItem],
        sourceLanguage: String,
        provider: AIProvider,
        appContext: String?,
        onBatchCompleted: @escaping @MainActor (TranslationBatchResult) -> Void
    ) async {
        guard !items.isEmpty else {
            statusMessage = "No untranslated items found."
            return
        }

        isTranslating = true
        progress = 0.0
        completedCount = 0
        successCount = 0
        errorCount = 0
        lastErrorMessage = nil
        totalCount = items.count
        statusMessage = "Translating \(totalCount) items with \(provider.type.rawValue)..."

        let byLanguage = Dictionary(grouping: items, by: \.targetLanguage)

        currentTask = Task { [weak self] in
            guard let self = self else { return }

            for (targetLang, langItems) in byLanguage {
                if Task.isCancelled { break }
                self.activeLanguage = targetLang
                let chunks = langItems.chunked(into: self.batchSize)

                for chunk in chunks {
                    if Task.isCancelled { break }
                    self.statusMessage = "Translating batch for [\(targetLang)]..."

                    let inputs = chunk.enumerated().map { idx, item in
                        BatchTranslationInput(id: idx, text: item.sourceText, context: item.context)
                    }

                    do {
                        let translations = try await provider.translateBatch(
                            inputs: inputs,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLang,
                            appContext: appContext
                        )

                        for (idx, item) in chunk.enumerated() {
                            let translated = idx < translations.count ? translations[idx] : nil
                            let res = TranslationBatchResult(item: item, translatedText: translated, error: nil)
                            onBatchCompleted(res)
                            self.completedCount += 1
                            if translated != nil {
                                self.successCount += 1
                            } else {
                                self.errorCount += 1
                            }
                        }
                    } catch {
                        self.lastErrorMessage = error.localizedDescription
                        for item in chunk {
                            let res = TranslationBatchResult(
                                item: item,
                                translatedText: nil,
                                error: error.localizedDescription
                            )
                            onBatchCompleted(res)
                            self.completedCount += 1
                            self.errorCount += 1
                        }
                    }

                    self.progress = Double(self.completedCount) / Double(max(self.totalCount, 1))
                }
            }

            self.isTranslating = false
            if Task.isCancelled {
                self.statusMessage = "Translation stopped."
            } else if self.errorCount > 0 && self.successCount == 0 {
                self.statusMessage = "Failed: \(self.lastErrorMessage ?? "Unable to translate")"
            } else if self.errorCount > 0 {
                self.statusMessage = "Completed \(self.successCount), failed \(self.errorCount)."
            } else {
                self.statusMessage = "Successfully translated \(self.successCount) item(s)."
            }
            self.currentTask = nil
        }

        await currentTask?.value
    }
}

// MARK: - Array Chunk Helper
extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
