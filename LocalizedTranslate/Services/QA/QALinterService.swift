//
//  QALinterService.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 3 on 10/4/26.
//

import Foundation

// MARK: - QA Data Models
public enum QASeverity: String, Codable, Sendable, Comparable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    private var rank: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        }
    }

    public static func < (lhs: QASeverity, rhs: QASeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum QACategory: String, Codable, Sendable {
    case formatSpecifiers = "Format Specifiers"
    case htmlTags = "HTML / XML Tags"
    case lengthDiscrepancy = "UI Length Warning"
    case brandVoice = "Brand & Glossary"
    case untranslated = "Missing Translation"

    public var shortBadgeTitle: String {
        switch self {
        case .formatSpecifiers:
            return "FORMAT"
        case .lengthDiscrepancy:
            return "LENGTH"
        case .htmlTags:
            return "HTML"
        case .brandVoice:
            return "BRAND"
        case .untranslated:
            return "EMPTY"
        }
    }

    public var systemIcon: String {
        switch self {
        case .formatSpecifiers:
            return "percent"
        case .lengthDiscrepancy:
            return "arrow.left.and.right"
        case .htmlTags:
            return "chevron.left.forwardslash.chevron.right"
        case .brandVoice:
            return "bookmark.fill"
        case .untranslated:
            return "circle.dashed"
        }
    }
}

public struct QAIssue: Identifiable, Codable, Sendable {
    public let id: UUID
    public let key: String
    public let language: String
    public let severity: QASeverity
    public let category: QACategory
    public let message: String
    public let sourceText: String
    public let translatedText: String
    public let suggestedFix: String?

    public init(
        id: UUID = UUID(),
        key: String,
        language: String,
        severity: QASeverity,
        category: QACategory,
        message: String,
        sourceText: String,
        translatedText: String,
        suggestedFix: String? = nil
    ) {
        self.id = id
        self.key = key
        self.language = language
        self.severity = severity
        self.category = category
        self.message = message
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.suggestedFix = suggestedFix
    }
}

// MARK: - Lintable Entry Protocol for Decoupled Analysis
public struct LintTargetItem: Sendable {
    public let key: String
    public let source: String
    public let translation: String
    public let language: String

    public init(key: String, source: String, translation: String, language: String) {
        self.key = key
        self.source = source
        self.translation = translation
        self.language = language
    }
}

// MARK: - QA Linter Service Engine
public struct QALinterService: Sendable {
    private static let specifierPattern = #"%(\d+\$)?[+-]?(?:0|\s)?(?:\d+)?(?:\.\d+)?[hl]{0,2}[@dDuUxXoOfeEgGcCsSp]"#
    private static let htmlTagPattern = #"<\/?([a-zA-Z0-9]+)(\s+[^>]*)?>"#

    public init() {}

    /// Inspect a single translation unit against its source string
    public func lint(
        key: String,
        source: String,
        translation: String,
        language: String,
        glossaryDoNotTranslate: [String] = []
    ) -> [QAIssue] {
        var issues: [QAIssue] = []

        // 1. Missing Translation Check
        if let emptyIssue = checkEmptyTranslation(key: key, source: source, translation: translation, language: language) {
            return [emptyIssue]
        }

        // 2. Format Specifiers AST Validation
        issues.append(contentsOf: checkFormatSpecifiers(key: key, source: source, translation: translation, language: language))

        // 3. HTML / XML Tags Consistency
        if let htmlIssue = checkHTMLTags(key: key, source: source, translation: translation, language: language) {
            issues.append(htmlIssue)
        }

        // 4. UI Length Warning
        if let lengthIssue = checkLengthDiscrepancy(key: key, source: source, translation: translation, language: language) {
            issues.append(lengthIssue)
        }

        // 5. Brand & Do-Not-Translate Glossary Enforcement
        issues.append(contentsOf: checkGlossary(key: key, source: source, translation: translation, language: language, glossary: glossaryDoNotTranslate))

        return issues
    }

    /// Lints a collection of items decoupled from raw JSON/Catalog implementations
    public func lintItems(
        _ items: [LintTargetItem],
        glossary: [String] = []
    ) -> [QAIssue] {
        var issues: [QAIssue] = []
        for item in items {
            let result = lint(
                key: item.key,
                source: item.source,
                translation: item.translation,
                language: item.language,
                glossaryDoNotTranslate: glossary
            )
            issues.append(contentsOf: result)
        }
        return issues.sorted { $0.severity > $1.severity }
    }

    private func checkEmptyTranslation(
        key: String,
        source: String,
        translation: String,
        language: String
    ) -> QAIssue? {
        let trimmed = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty && !source.isEmpty else { return nil }
        return QAIssue(
            key: key,
            language: language,
            severity: .error,
            category: .untranslated,
            message: "Translation is empty.",
            sourceText: source,
            translatedText: translation
        )
    }

    private func checkFormatSpecifiers(
        key: String,
        source: String,
        translation: String,
        language: String
    ) -> [QAIssue] {
        var issues: [QAIssue] = []
        let sourceSpecifiers = extractSpecifiers(from: source)
        let targetSpecifiers = extractSpecifiers(from: translation)

        if sourceSpecifiers != targetSpecifiers {
            let missing = sourceSpecifiers.filter { !targetSpecifiers.contains($0) }
            let unexpected = targetSpecifiers.filter { !sourceSpecifiers.contains($0) }

            if !missing.isEmpty {
                let missingStr = missing.joined(separator: ", ")
                issues.append(QAIssue(
                    key: key,
                    language: language,
                    severity: .error,
                    category: .formatSpecifiers,
                    message: "Missing format specifier(s): [\(missingStr)]. Risk of runtime crash!",
                    sourceText: source,
                    translatedText: translation,
                    suggestedFix: "Restore placeholders \(missingStr)"
                ))
            }

            if !unexpected.isEmpty {
                let unexpStr = unexpected.joined(separator: ", ")
                issues.append(QAIssue(
                    key: key,
                    language: language,
                    severity: .warning,
                    category: .formatSpecifiers,
                    message: "Unexpected format specifier(s) added: [\(unexpStr)].",
                    sourceText: source,
                    translatedText: translation
                ))
            }
        }

        // Detect malformed placeholders with spaces
        if translation.range(of: #"% \w"#, options: .regularExpression) != nil {
            let fixed = translation.replacingOccurrences(
                of: #"% (\w)"#,
                with: "%$1",
                options: .regularExpression
            )
            issues.append(QAIssue(
                key: key,
                language: language,
                severity: .error,
                category: .formatSpecifiers,
                message: "Malformed placeholder detected with whitespace (e.g., '% @').",
                sourceText: source,
                translatedText: translation,
                suggestedFix: fixed
            ))
        }

        return issues
    }

    private func checkHTMLTags(
        key: String,
        source: String,
        translation: String,
        language: String
    ) -> QAIssue? {
        let sourceTags = extractTags(from: source)
        let targetTags = extractTags(from: translation)
        guard sourceTags != targetTags else { return nil }
        return QAIssue(
            key: key,
            language: language,
            severity: .warning,
            category: .htmlTags,
            message: "HTML/XML tags mismatch. Source: \(sourceTags), Target: \(targetTags)",
            sourceText: source,
            translatedText: translation
        )
    }

    private func checkLengthDiscrepancy(
        key: String,
        source: String,
        translation: String,
        language: String
    ) -> QAIssue? {
        guard source.count > 0 && source.count <= 25,
              Double(translation.count) > Double(source.count) * 1.8 else {
            return nil
        }
        let percentage = Int((Double(translation.count) / Double(source.count)) * 100)
        return QAIssue(
            key: key,
            language: language,
            severity: .warning,
            category: .lengthDiscrepancy,
            message: "Translation is \(translation.count) chars (\(percentage)% of source). May overflow compact UI.",
            sourceText: source,
            translatedText: translation
        )
    }

    private func checkGlossary(
        key: String,
        source: String,
        translation: String,
        language: String,
        glossary: [String]
    ) -> [QAIssue] {
        var issues: [QAIssue] = []
        for term in glossary where !term.isEmpty {
            if source.localizedCaseInsensitiveContains(term) {
                if !translation.localizedCaseInsensitiveContains(term) {
                    issues.append(QAIssue(
                        key: key,
                        language: language,
                        severity: .warning,
                        category: .brandVoice,
                        message: "Brand/Glossary term '\(term)' is missing in translation. Must not be translated.",
                        sourceText: source,
                        translatedText: translation
                    ))
                }
            }
        }
        return issues
    }

    // MARK: - Private Helpers

    private func extractSpecifiers(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: Self.specifierPattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private func extractTags(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: Self.htmlTagPattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }
}
