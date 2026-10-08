//
//  WorkspaceViewModel.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 5 on 10/4/26.
//

import SwiftUI
import AppKit
import Combine

public enum FilterMode: String, CaseIterable, Identifiable {
    case all = "All"
    case untranslated = "Untranslated"
    case hasIssues = "QA Issues"
    case translated = "Translated"

    public var id: String { rawValue }
}

public struct DisplayCatalogItem: Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let sourceText: String
    public let translatedText: String?
    public let comment: String?
    public let state: String
    public let hasIssues: Bool
    public let issues: [QAIssue]
}

public struct LanguageProgressStats: Sendable {
    public let language: String
    public let totalCount: Int
    public let translatedCount: Int
    public let missingCount: Int
    public let issuesCount: Int

    public var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(translatedCount) / Double(totalCount)
    }

    public var percentageInt: Int {
        Int((completionRate * 100).rounded())
    }

    public var percentageString: String {
        "\(percentageInt)%"
    }
}

@MainActor
public final class WorkspaceViewModel: ObservableObject {
    @Published public var catalog: StringCatalog?
    @Published public var fileURL: URL?
    @Published public var targetLanguages: [String] = []
    @Published public var selectedLanguage: String = ""
    @Published public var selectedKey: String?
    @Published public var searchText: String = ""
    @Published public var filterMode: FilterMode = .all

    // QA & Status
    @Published public var qaIssues: [QAIssue] = []
    @Published public var totalQAIssuesCount: Int = 0
    @Published public var selectedProviderType: AIProviderType = .openAI {
        didSet {
            UserDefaults.standard.set(selectedProviderType.rawValue, forKey: "selectedProviderType")
        }
    }
    @Published public var customModel: String = ""
    @Published public var appPersonaContext: String = ""
    @Published public var glossaryKeywords: [String] = ["AirDrop", "Face ID", "Apple Pay"]

    // Modals & UI State
    @Published public var showCommandPalette: Bool = false
    @Published public var showSettings: Bool = false
    @Published public var errorMessage: String?
    @Published public var isTranslatingKey: String?
    @Published public var lastTranslationUpdatedKey: String?
    @Published public var lastTranslationValue: String?
    @Published public var catalogVersion: Int = 0
    @Published public var saveStatusMessage: String?

    public let translationManager = TranslationManager()
    public let qaService = QALinterService()

    var securityScopedURL: URL?
    let cachedBookmarkKey = "cachedOpenedFileBookmark"
    let cachedPathKey = "cachedOpenedFilePath"
    private var cancellables = Set<AnyCancellable>()

    public init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedProviderType"),
           let type = AIProviderType(rawValue: saved) {
            self.selectedProviderType = type
        }

        // Bridge TranslationManager observable changes to WorkspaceViewModel
        translationManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        restoreLastOpenedFile()
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    public func hasCredential(for type: AIProviderType) -> Bool {
        if type == .ollama {
            let host = KeychainManager.shared.retrieve(account: type.keychainAccountKey) ?? "http://localhost:11434"
            return !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard let key = KeychainManager.shared.retrieve(account: type.keychainAccountKey) else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var activeProviderHasKey: Bool {
        hasCredential(for: selectedProviderType)
    }

    public var sourceLanguage: String {
        catalog?.sourceLanguage ?? "en"
    }
}

// MARK: - File I/O & Caching
extension WorkspaceViewModel {
    public func openFile(url: URL, isRestoring: Bool = false) {
        if !isRestoring {
            if let prev = securityScopedURL {
                prev.stopAccessingSecurityScopedResource()
                securityScopedURL = nil
            }
            if url.startAccessingSecurityScopedResource() {
                self.securityScopedURL = url
            }
        }

        do {
            let loadedCatalog = try XCStringsParser.load(from: url)
            self.catalog = loadedCatalog
            self.fileURL = url
            let langs = XCStringsParser.extractLanguages(from: loadedCatalog)
                .filter { $0 != loadedCatalog.sourceLanguage }
            self.targetLanguages = langs
            self.selectedLanguage = langs.first ?? "de"
            self.selectedKey = loadedCatalog.strings.keys.sorted().first
            refreshQA()
            saveBookmark(for: url)
        } catch {
            if isRestoring {
                clearBookmark()
            } else {
                self.errorMessage = "Failed to open file: \(error.localizedDescription)"
            }
        }
    }

    public func closeCurrentFile() {
        if let prev = securityScopedURL {
            prev.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
        self.catalog = nil
        self.fileURL = nil
        self.targetLanguages = []
        self.selectedLanguage = ""
        self.selectedKey = nil
        self.qaIssues = []
        self.totalQAIssuesCount = 0
        clearBookmark()
    }

    func saveBookmark(for url: URL) {
        UserDefaults.standard.set(url.path, forKey: cachedPathKey)
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: cachedBookmarkKey)
        } else if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: cachedBookmarkKey)
        }
    }

    func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: cachedBookmarkKey)
        UserDefaults.standard.removeObject(forKey: cachedPathKey)
    }

    public func restoreLastOpenedFile() {
        if let bookmarkData = UserDefaults.standard.data(forKey: cachedBookmarkKey) {
            var isStale = false
            if let resolvedURL = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    saveBookmark(for: resolvedURL)
                }
                if resolvedURL.startAccessingSecurityScopedResource() {
                    self.securityScopedURL = resolvedURL
                }
                if FileManager.default.fileExists(atPath: resolvedURL.path) {
                    self.openFile(url: resolvedURL, isRestoring: true)
                    return
                }
            } else if let resolvedURL = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if FileManager.default.fileExists(atPath: resolvedURL.path) {
                    self.openFile(url: resolvedURL, isRestoring: true)
                    return
                }
            }
        }

        if let savedPath = UserDefaults.standard.string(forKey: cachedPathKey) {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                self.openFile(url: url, isRestoring: true)
            }
        }
    }

    public func saveCatalog() {
        guard let cat = catalog, let url = fileURL else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            try XCStringsParser.save(cat, to: url, createBackup: true)
            let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.saveStatusMessage = "Saved at \(timeStr)"
            self.catalogVersion += 1
            refreshQA()
        } catch {
            self.errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    public func progressStats(for language: String) -> LanguageProgressStats {
        guard let cat = catalog, !language.isEmpty else {
            return LanguageProgressStats(language: language, totalCount: 0, translatedCount: 0, missingCount: 0, issuesCount: 0)
        }
        let total = cat.strings.count
        var translated = 0
        for group in cat.strings.values {
            if group.localizations?[language]?.hasTranslation == true {
                translated += 1
            }
        }
        let issues = getQAIssues(for: language).count
        return LanguageProgressStats(
            language: language,
            totalCount: total,
            translatedCount: translated,
            missingCount: max(0, total - translated),
            issuesCount: issues
        )
    }

    public func overallProgressStats() -> LanguageProgressStats {
        guard let cat = catalog, !targetLanguages.isEmpty else {
            return LanguageProgressStats(language: "ALL", totalCount: 0, translatedCount: 0, missingCount: 0, issuesCount: 0)
        }
        let totalTargets = cat.strings.count * targetLanguages.count
        var translated = 0
        for lang in targetLanguages {
            for group in cat.strings.values {
                if group.localizations?[lang]?.hasTranslation == true {
                    translated += 1
                }
            }
        }
        return LanguageProgressStats(
            language: "ALL",
            totalCount: totalTargets,
            translatedCount: translated,
            missingCount: max(0, totalTargets - translated),
            issuesCount: totalQAIssuesCount
        )
    }

    public func addTargetLanguage(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !targetLanguages.contains(trimmed) else { return }
        targetLanguages.append(trimmed)
        targetLanguages.sort()
        selectedLanguage = trimmed
    }

    public func staleTranslationsCount(allLanguages: Bool = true) -> Int {
        staleKeys(allLanguages: allLanguages).count
    }

    @discardableResult
    public func clearStaleTranslations(allLanguages: Bool = true) -> Int {
        guard let cat = catalog else { return 0 }
        guard allLanguages || !selectedLanguage.isEmpty else {
            errorMessage = "Please select a target language first."
            return 0
        }

        let keysToDelete = staleKeys(allLanguages: allLanguages)
        guard !keysToDelete.isEmpty else {
            errorMessage = allLanguages ? "No stale items found." : "No stale items found for [\(selectedLanguage.uppercased())]."
            return 0
        }

        for key in keysToDelete {
            cat.strings.removeValue(forKey: key)
        }

        errorMessage = nil
        if let selectedKey, keysToDelete.contains(selectedKey) {
            self.selectedKey = cat.strings.keys.sorted().first
        }
        catalogVersion += 1
        refreshQA()
        saveCatalog()
        saveStatusMessage = allLanguages ? "Deleted \(keysToDelete.count) stale items" : "Deleted \(keysToDelete.count) stale items for \(selectedLanguage.uppercased())"
        return keysToDelete.count
    }

    private func staleKeys(allLanguages: Bool) -> Set<String> {
        guard let cat = catalog else { return [] }
        guard allLanguages || !selectedLanguage.isEmpty else { return [] }

        var keys = Set<String>()
        for (key, group) in cat.strings {
            if group.extractionState?.lowercased() == "stale" {
                keys.insert(key)
                continue
            }

            guard let localizations = group.localizations else { continue }
            if allLanguages {
                if localizations.values.contains(where: Self.localizationContainsStaleState) {
                    keys.insert(key)
                }
            } else if let unit = localizations[selectedLanguage], Self.localizationContainsStaleState(unit) {
                keys.insert(key)
            }
        }
        return keys
    }

    private static func localizationContainsStaleState(_ unit: LocalizationUnit) -> Bool {
        if unit.stringUnit?.state.lowercased() == "stale" { return true }
        if variationsContainStaleState(unit.variations) { return true }
        return unit.substitutions?.values.contains { variationsContainStaleState($0.variations) } == true
    }

    private static func variationsContainStaleState(_ variations: VariationsUnit?) -> Bool {
        guard let variations else { return false }
        if let plural = variations.plural {
            let units = [plural.zero, plural.one, plural.two, plural.few, plural.many, plural.other]
            if units.contains(where: { $0?.stringUnit.state.lowercased() == "stale" }) { return true }
        }
        if let device = variations.device {
            let units = [device.appletv, device.applevision, device.applewatch, device.ipad, device.iphone, device.ipod, device.mac, device.other]
            if units.contains(where: { $0?.stringUnit.state.lowercased() == "stale" }) { return true }
        }
        return false
    }
}

// MARK: - QA Inspection & Display Items
extension WorkspaceViewModel {
    public func getQAIssues(for language: String) -> [QAIssue] {
        guard let cat = catalog, !language.isEmpty else { return [] }
        var itemsToLint: [LintTargetItem] = []
        for (key, group) in cat.strings {
            let src = group.localizations?[cat.sourceLanguage]?.stringUnit?.value ?? key
            let tr = group.localizations?[language]?.stringUnit?.value ?? ""
            itemsToLint.append(LintTargetItem(
                key: key,
                source: src,
                translation: tr,
                language: language
            ))
        }
        return qaService.lintItems(itemsToLint, glossary: glossaryKeywords)
    }

    public func getAllQAIssues() -> [QAIssue] {
        guard catalog != nil else { return [] }
        var allIssues: [QAIssue] = []
        for lang in targetLanguages {
            allIssues.append(contentsOf: getQAIssues(for: lang))
        }
        return allIssues
    }

    public func refreshQA() {
        guard catalog != nil else {
            qaIssues = []
            totalQAIssuesCount = 0
            return
        }

        if !selectedLanguage.isEmpty {
            qaIssues = getQAIssues(for: selectedLanguage)
        } else {
            qaIssues = []
        }

        totalQAIssuesCount = getAllQAIssues().count
    }

    public var filteredItems: [DisplayCatalogItem] {
        guard let cat = catalog else { return [] }
        let srcLang = cat.sourceLanguage
        let targetLang = selectedLanguage

        var items: [DisplayCatalogItem] = []
        let issuesByKey = Dictionary(grouping: qaIssues, by: \.key)

        for key in cat.strings.keys.sorted() {
            guard let group = cat.strings[key] else { continue }
            let srcText = group.localizations?[srcLang]?.stringUnit?.value ?? key
            let targetUnit = group.localizations?[targetLang]
            let trText = targetUnit?.stringUnit?.value
            let state = targetUnit?.stringUnit?.state ?? (trText == nil ? "untranslated" : "translated")

            let keyIssues = issuesByKey[key] ?? []
            let hasIssue = !keyIssues.isEmpty

            // Apply Search Filter
            if !searchText.isEmpty {
                let lowerSearch = searchText.lowercased()
                let matchKey = key.lowercased().contains(lowerSearch)
                let matchSrc = srcText.lowercased().contains(lowerSearch)
                let matchTr = trText?.lowercased().contains(lowerSearch) ?? false
                if !matchKey && !matchSrc && !matchTr {
                    continue
                }
            }

            // Apply Mode Filter
            switch filterMode {
            case .all:
                break
            case .untranslated:
                if targetUnit?.hasTranslation == true { continue }
            case .hasIssues:
                if !hasIssue { continue }
            case .translated:
                if targetUnit?.hasTranslation != true { continue }
            }

            items.append(DisplayCatalogItem(
                key: key,
                sourceText: srcText,
                translatedText: trText,
                comment: group.comment,
                state: state,
                hasIssues: hasIssue,
                issues: keyIssues
            ))
        }
        return items
    }
}

// MARK: - Translation Actions
extension WorkspaceViewModel {
    public func translateKey(_ key: String) async {
        guard let cat = catalog, let group = cat.strings[key] else { return }
        guard !selectedLanguage.isEmpty else {
            errorMessage = "Please select a target language first."
            return
        }

        // Validate API Key / Credentials before proceeding
        if !activeProviderHasKey {
            let availableWithKey = AIProviderType.allCases.first { hasCredential(for: $0) }
            if let alt = availableWithKey {
                errorMessage = "Active engine '\(selectedProviderType.rawValue)' has no API key configured. Switch to '\(alt.rawValue)' in Toolbar or configure in Settings."
            } else {
                errorMessage = "No API key configured for '\(selectedProviderType.rawValue)'. Please open Preferences (⌘,) and configure your API key."
            }
            return
        }

        let srcText = group.localizations?[cat.sourceLanguage]?.stringUnit?.value ?? key
        if srcText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Source text for '\(key)' is empty."
            return
        }

        isTranslatingKey = key
        errorMessage = nil

        let provider = AIProviderFactory.create(
            type: selectedProviderType,
            model: customModel.isEmpty ? nil : customModel,
            customHost: KeychainManager.shared.retrieve(account: AIProviderType.ollama.keychainAccountKey),
            keyRetriever: { KeychainManager.shared.retrieve(account: $0) }
        )

        let workItem = TranslationWorkItem(
            key: key,
            sourceText: srcText,
            context: group.comment,
            targetLanguage: selectedLanguage
        )

        await translationManager.translateWorkItems(
            items: [workItem],
            sourceLanguage: cat.sourceLanguage,
            provider: provider,
            appContext: appPersonaContext
        ) { [weak self] result in
            guard let self = self else { return }
            if let err = result.error {
                self.errorMessage = "Translation failed: \(err)"
            } else if let text = result.translatedText {
                self.catalog?.strings[result.item.key]?.setTranslation(text, for: result.item.targetLanguage)
                self.lastTranslationUpdatedKey = result.item.key
                self.lastTranslationValue = text
                self.catalogVersion += 1
                self.saveCatalog()
            }
        }

        isTranslatingKey = nil
    }

    public func translateAllMissing(allLanguages: Bool = true) async {
        guard let cat = catalog else { return }

        // Validate API Key / Credentials
        if !activeProviderHasKey {
            let availableWithKey = AIProviderType.allCases.first { hasCredential(for: $0) }
            if let alt = availableWithKey {
                errorMessage = "Active engine '\(selectedProviderType.rawValue)' has no API key configured. Switch to '\(alt.rawValue)' in Toolbar or configure in Settings."
            } else {
                errorMessage = "No API key configured for '\(selectedProviderType.rawValue)'. Please open Preferences (⌘,) and configure your API key."
            }
            return
        }

        let languagesToTranslate: [String]
        if allLanguages {
            languagesToTranslate = targetLanguages
            if languagesToTranslate.isEmpty {
                errorMessage = "No target languages configured."
                return
            }
        } else {
            guard !selectedLanguage.isEmpty else {
                errorMessage = "Please select a target language first."
                return
            }
            languagesToTranslate = [selectedLanguage]
        }

        var workItems: [TranslationWorkItem] = []
        for lang in languagesToTranslate {
            for (key, group) in cat.strings {
                let unit = group.localizations?[lang]
                if unit?.hasTranslation == true { continue }
                let srcText = group.localizations?[cat.sourceLanguage]?.stringUnit?.value ?? key
                if srcText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                workItems.append(TranslationWorkItem(
                    key: key,
                    sourceText: srcText,
                    context: group.comment,
                    targetLanguage: lang
                ))
            }
        }

        if workItems.isEmpty {
            if allLanguages {
                errorMessage = "All strings across all languages (\(languagesToTranslate.count)) are already translated."
            } else {
                errorMessage = "All strings for [\(selectedLanguage.uppercased())] are already translated."
            }
            return
        }

        errorMessage = nil

        let provider = AIProviderFactory.create(
            type: selectedProviderType,
            model: customModel.isEmpty ? nil : customModel,
            customHost: KeychainManager.shared.retrieve(account: AIProviderType.ollama.keychainAccountKey),
            keyRetriever: { KeychainManager.shared.retrieve(account: $0) }
        )

        await translationManager.translateWorkItems(
            items: workItems,
            sourceLanguage: cat.sourceLanguage,
            provider: provider,
            appContext: appPersonaContext
        ) { [weak self] result in
            guard let self = self else { return }
            if let err = result.error {
                self.errorMessage = "Batch item error: \(err)"
            } else if let text = result.translatedText {
                self.catalog?.strings[result.item.key]?.setTranslation(text, for: result.item.targetLanguage)
                self.catalogVersion += 1
                if result.item.key == self.selectedKey && result.item.targetLanguage == self.selectedLanguage {
                    self.lastTranslationUpdatedKey = result.item.key
                    self.lastTranslationValue = text
                }
                // Periodic auto-save every 10 items
                if self.translationManager.completedCount % 10 == 0 {
                    self.saveCatalog()
                }
            }
        }

        self.saveCatalog()
        self.catalogVersion += 1
        refreshQA()
    }

    public func retranslateQAIssues(allLanguages: Bool = false) async {
        guard let cat = catalog else { return }

        if !activeProviderHasKey {
            let availableWithKey = AIProviderType.allCases.first { hasCredential(for: $0) }
            if let alt = availableWithKey {
                errorMessage = "Active engine '\(selectedProviderType.rawValue)' has no API key configured. Switch to '\(alt.rawValue)' in Toolbar or configure in Settings."
            } else {
                errorMessage = "No API key configured for '\(selectedProviderType.rawValue)'. Please open Preferences (⌘,) and configure your API key."
            }
            return
        }

        let targetLangs = allLanguages ? targetLanguages : (!selectedLanguage.isEmpty ? [selectedLanguage] : [])
        guard !targetLangs.isEmpty else {
            errorMessage = "No target language selected."
            return
        }

        var workItems: [TranslationWorkItem] = []
        var seenKeys = Set<String>()

        for lang in targetLangs {
            let issues = getQAIssues(for: lang)
            for issue in issues {
                let compound = "\(lang)::\(issue.key)"
                guard !seenKeys.contains(compound) else { continue }
                seenKeys.insert(compound)

                guard let group = cat.strings[issue.key] else { continue }
                let srcText = group.localizations?[cat.sourceLanguage]?.stringUnit?.value ?? issue.key
                if srcText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

                workItems.append(TranslationWorkItem(
                    key: issue.key,
                    sourceText: srcText,
                    context: group.comment,
                    targetLanguage: lang
                ))
            }
        }

        guard !workItems.isEmpty else {
            if allLanguages {
                errorMessage = "No QA issues found across all languages."
            } else {
                errorMessage = "No QA issues found for [\(selectedLanguage.uppercased())]."
            }
            return
        }

        errorMessage = nil

        let provider = AIProviderFactory.create(
            type: selectedProviderType,
            model: customModel.isEmpty ? nil : customModel,
            customHost: KeychainManager.shared.retrieve(account: AIProviderType.ollama.keychainAccountKey),
            keyRetriever: { KeychainManager.shared.retrieve(account: $0) }
        )

        await translationManager.translateWorkItems(
            items: workItems,
            sourceLanguage: cat.sourceLanguage,
            provider: provider,
            appContext: appPersonaContext
        ) { [weak self] result in
            guard let self = self else { return }
            if let err = result.error {
                self.errorMessage = "Error re-translating QA item: \(err)"
            } else if let text = result.translatedText {
                self.catalog?.strings[result.item.key]?.setTranslation(text, for: result.item.targetLanguage)
                self.catalogVersion += 1
                if result.item.key == self.selectedKey && result.item.targetLanguage == self.selectedLanguage {
                    self.lastTranslationUpdatedKey = result.item.key
                    self.lastTranslationValue = text
                }
                if self.translationManager.completedCount % 10 == 0 {
                    self.saveCatalog()
                }
            }
        }

        self.saveCatalog()
        self.catalogVersion += 1
        refreshQA()
    }

    public func translateQAIssues() async {
        await retranslateQAIssues(allLanguages: false)
    }

    public func updateManualTranslation(key: String, newTranslation: String) {
        guard let cat = catalog, !selectedLanguage.isEmpty else { return }
        cat.strings[key]?.setTranslation(newTranslation, for: selectedLanguage, state: "reviewed")
        catalogVersion += 1
        refreshQA()
        saveCatalog()
    }
}
