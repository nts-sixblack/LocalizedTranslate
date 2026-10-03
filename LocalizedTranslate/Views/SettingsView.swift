//
//  SettingsView.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 5 on 10/4/26.
//

import SwiftUI
import AppKit
import Combine

public enum SettingsTab: String, CaseIterable, Identifiable {
    case providers = "AI Providers"
    case context = "App Context"
    case glossary = "Brand Glossary"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .providers: return "cpu"
        case .context: return "text.bubble"
        case .glossary: return "character.book.closed"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentTab: SettingsTab = .providers
    @State private var selectedProvider: AIProviderType = .openAI

    // Credentials State
    @State private var openAIKey: String = ""
    @State private var claudeKey: String = ""
    @State private var geminiKey: String = ""
    @State private var deepSeekKey: String = ""
    @State private var ollamaHost: String = "http://localhost:11434"

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(RaycastTheme.accentBlue)
                    Text("Preferences")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RaycastTheme.ink)
                }

                Spacer()

                // Tab Switcher
                HStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        tabPill(tab)
                    }
                }

                Spacer()

                Button("Done") {
                    saveAll()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RaycastTheme.surfaceCard)

            Divider().background(RaycastTheme.hairline)

            // Content Area
            Group {
                switch currentTab {
                case .providers:
                    SettingsProvidersSection(
                        viewModel: viewModel,
                        selectedProvider: $selectedProvider,
                        openAIKey: $openAIKey,
                        claudeKey: $claudeKey,
                        geminiKey: $geminiKey,
                        deepSeekKey: $deepSeekKey,
                        ollamaHost: $ollamaHost,
                        onSaveAll: { saveAll() }
                    )
                case .context:
                    SettingsContextSection(viewModel: viewModel)
                case .glossary:
                    SettingsGlossarySection(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 480)
        .background(RaycastTheme.canvas)
        .onAppear {
            loadCredentials()
            selectedProvider = viewModel.selectedProviderType
        }
        .onDisappear {
            saveAll()
        }
    }

    private func tabPill(_ tab: SettingsTab) -> some View {
        let isSelected = currentTab == tab
        return Button {
            currentTab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? RaycastTheme.ink : RaycastTheme.mute)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? RaycastTheme.surfaceCard : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? RaycastTheme.hairlineStrong : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func loadCredentials() {
        let keyMgr = KeychainManager.shared
        openAIKey = keyMgr.retrieve(account: AIProviderType.openAI.keychainAccountKey) ?? ""
        claudeKey = keyMgr.retrieve(account: AIProviderType.anthropicClaude.keychainAccountKey) ?? ""
        geminiKey = keyMgr.retrieve(account: AIProviderType.googleGemini.keychainAccountKey) ?? ""
        deepSeekKey = keyMgr.retrieve(account: AIProviderType.deepSeek.keychainAccountKey) ?? ""
        ollamaHost = keyMgr.retrieve(account: AIProviderType.ollama.keychainAccountKey) ?? "http://localhost:11434"
    }

    private func saveAll() {
        let keyMgr = KeychainManager.shared
        try? keyMgr.save(key: openAIKey, account: AIProviderType.openAI.keychainAccountKey)
        try? keyMgr.save(key: claudeKey, account: AIProviderType.anthropicClaude.keychainAccountKey)
        try? keyMgr.save(key: geminiKey, account: AIProviderType.googleGemini.keychainAccountKey)
        try? keyMgr.save(key: deepSeekKey, account: AIProviderType.deepSeek.keychainAccountKey)
        try? keyMgr.save(key: ollamaHost, account: AIProviderType.ollama.keychainAccountKey)

        // If current active provider has no key, but the currently inspected or another provider does, auto-activate it
        let activeKey = keyMgr.retrieve(account: viewModel.selectedProviderType.keychainAccountKey) ?? ""
        if activeKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.selectedProviderType != .ollama {
            let candidateKey = keyMgr.retrieve(account: selectedProvider.keychainAccountKey) ?? ""
            if !candidateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.selectedProviderType = selectedProvider
            } else if let valid = AIProviderType.allCases.first(where: {
                let retrievedKey = keyMgr.retrieve(account: $0.keychainAccountKey) ?? ""
                return !retrievedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
                viewModel.selectedProviderType = valid
            }
        }
        viewModel.objectWillChange.send()
    }
}

// MARK: - Providers Section Component
struct SettingsProvidersSection: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Binding var selectedProvider: AIProviderType
    @Binding var openAIKey: String
    @Binding var claudeKey: String
    @Binding var geminiKey: String
    @Binding var deepSeekKey: String
    @Binding var ollamaHost: String
    let onSaveAll: () -> Void

    @State private var showKeyPlaintext: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testResultStatus: String?
    @State private var testResultIsSuccess: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Left List
            VStack(alignment: .leading, spacing: 6) {
                Text("ENGINES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(RaycastTheme.ash)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(AIProviderType.allCases) { type in
                            providerRow(type)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .frame(width: 230)
            .background(RaycastTheme.surface)

            Divider().background(RaycastTheme.hairline)

            // Right Detail Config
            VStack(alignment: .leading, spacing: 18) {
                providerHeaderView

                Divider().background(RaycastTheme.hairline)

                credentialInputField

                testActionView

                Spacer()
            }
            .padding(20)
            .background(RaycastTheme.canvas)
        }
    }

    private func providerRow(_ type: AIProviderType) -> some View {
        let isSelected = selectedProvider == type
        let isActive = viewModel.selectedProviderType == type
        let hasKey = hasCredential(for: type)

        return Button {
            selectedProvider = type
            testResultStatus = nil
        } label: {
            HStack(spacing: 10) {
                ProviderIconView(type: type)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(shortName(for: type))
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(RaycastTheme.ink)
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(RaycastTheme.accentGreen)
                        }
                    }
                    Text(type.defaultModel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(RaycastTheme.mute)
                }
                Spacer()
                Circle()
                    .fill(hasKey ? RaycastTheme.accentGreen : RaycastTheme.ash.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? RaycastTheme.surfaceCard : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? RaycastTheme.hairlineStrong : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var providerHeaderView: some View {
        HStack(alignment: .center, spacing: 12) {
            ProviderIconView(type: selectedProvider)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedProvider.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RaycastTheme.ink)
                Text("Default Model: \(selectedProvider.defaultModel)")
                    .font(.system(size: 11))
                    .foregroundStyle(RaycastTheme.mute)
            }
            Spacer()
            if viewModel.selectedProviderType == selectedProvider {
                StatusPill(title: "ACTIVE ENGINE", color: RaycastTheme.accentGreen)
            } else {
                Button {
                    viewModel.selectedProviderType = selectedProvider
                    onSaveAll()
                } label: {
                    Label("Use as Active Engine", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var credentialInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedProvider == .ollama ? "OLLAMA ENDPOINT" : "API KEY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(RaycastTheme.ash)
                Spacer()
                if selectedProvider != .ollama {
                    Button {
                        showKeyPlaintext.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showKeyPlaintext ? "eye.slash" : "eye")
                            Text(showKeyPlaintext ? "Hide" : "Reveal")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(RaycastTheme.mute)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                if selectedProvider == .ollama {
                    TextField("http://localhost:11434", text: $ollamaHost)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(RaycastTheme.ink)
                        .padding(8)
                        .background(RaycastTheme.surfaceCard)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                } else {
                    Group {
                        if showKeyPlaintext {
                            TextField(keyPlaceholder, text: currentKeyBinding)
                        } else {
                            SecureField(keyPlaceholder, text: currentKeyBinding)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(RaycastTheme.ink)
                    .padding(8)
                    .background(RaycastTheme.surfaceCard)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                }

                Button {
                    if let clip = NSPasteboard.general.string(forType: .string) {
                        currentKeyBinding.wrappedValue = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                        .foregroundStyle(RaycastTheme.mute)
                }
                .buttonStyle(.bordered)
            }

            Text(providerHelpText)
                .font(.system(size: 11))
                .foregroundStyle(RaycastTheme.mute)
        }
    }

    private var testActionView: some View {
        HStack(spacing: 10) {
            Button {
                testConnection()
            } label: {
                HStack(spacing: 6) {
                    if isTestingConnection {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "network")
                    }
                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .disabled(isTestingConnection)

            if let status = testResultStatus {
                HStack(spacing: 4) {
                    Image(systemName: testResultIsSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(testResultIsSuccess ? RaycastTheme.accentGreen : RaycastTheme.accentRed)
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(testResultIsSuccess ? RaycastTheme.accentGreen : RaycastTheme.accentRed)
                }
            }
        }
    }

    private var currentKeyBinding: Binding<String> {
        switch selectedProvider {
        case .openAI: return $openAIKey
        case .anthropicClaude: return $claudeKey
        case .googleGemini: return $geminiKey
        case .deepSeek: return $deepSeekKey
        case .ollama: return $ollamaHost
        }
    }

    private func hasCredential(for type: AIProviderType) -> Bool {
        switch type {
        case .openAI: return !openAIKey.isEmpty
        case .anthropicClaude: return !claudeKey.isEmpty
        case .googleGemini: return !geminiKey.isEmpty
        case .deepSeek: return !deepSeekKey.isEmpty
        case .ollama: return !ollamaHost.isEmpty
        }
    }

    private func shortName(for type: AIProviderType) -> String {
        switch type {
        case .openAI: return "OpenAI"
        case .anthropicClaude: return "Anthropic"
        case .googleGemini: return "Gemini"
        case .deepSeek: return "DeepSeek"
        case .ollama: return "Ollama (Offline)"
        }
    }

    private var keyPlaceholder: String {
        switch selectedProvider {
        case .openAI: return "sk-proj-..."
        case .anthropicClaude: return "sk-ant-api03-..."
        case .googleGemini: return "AIzaSy..."
        case .deepSeek: return "sk-..."
        case .ollama: return "http://localhost:11434"
        }
    }

    private var providerHelpText: String {
        switch selectedProvider {
        case .openAI: return "Enter OpenAI API key (from platform.openai.com)"
        case .anthropicClaude: return "Enter Anthropic API key (from console.anthropic.com)"
        case .googleGemini: return "Enter Google Gemini API key (from aistudio.google.com)"
        case .deepSeek: return "Enter DeepSeek API key (from platform.deepseek.com)"
        case .ollama: return "Ensure local Ollama service is running (default: http://localhost:11434)"
        }
    }

    private func testConnection() {
        let key = currentKeyBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedProvider != .ollama && key.isEmpty {
            testResultStatus = "Please enter an API key first."
            testResultIsSuccess = false
            return
        }

        onSaveAll()
        isTestingConnection = true
        testResultStatus = nil

        Task {
            let provider = AIProviderFactory.create(
                type: selectedProvider,
                apiKey: key,
                customHost: selectedProvider == .ollama ? ollamaHost : nil
            )

            do {
                _ = try await provider.testConnection()
                await MainActor.run {
                    self.isTestingConnection = false
                    self.testResultIsSuccess = true
                    self.testResultStatus = "Connected successfully!"
                }
            } catch {
                await MainActor.run {
                    self.isTestingConnection = false
                    self.testResultIsSuccess = false
                    self.testResultStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Context Section Component
struct SettingsContextSection: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("APPLICATION CONTEXT & VOICE GUIDELINES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RaycastTheme.ash)
                    Text("AI uses this context to choose natural terminology, button lengths, and tonal style.")
                        .font(.system(size: 12))
                        .foregroundStyle(RaycastTheme.mute)
                }

                TextEditor(text: $viewModel.appPersonaContext)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .frame(height: 140)
                    .padding(10)
                    .background(RaycastTheme.surfaceCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(RaycastTheme.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    Text("QUICK PRESETS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RaycastTheme.ash)

                    HStack(spacing: 8) {
                        presetButton(
                            title: "macOS Utility",
                            prompt: "Modern macOS developer tool. Keep UI strings concise and professional."
                        )
                        presetButton(
                            title: "Consumer App",
                            prompt: "Friendly mobile application. Natural and engaging tone."
                        )
                        presetButton(
                            title: "Enterprise",
                            prompt: "Formal enterprise software. Precise technical terminology."
                        )
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }

    private func presetButton(title: String, prompt: String) -> some View {
        Button {
            viewModel.appPersonaContext = prompt
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RaycastTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(RaycastTheme.surfaceCard)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glossary Section Component
struct SettingsGlossarySection: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var newTermInput: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DO NOT TRANSLATE GLOSSARY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RaycastTheme.ash)
                    Text("Add trademarked terms, feature names, or acronyms that must remain untranslated.")
                        .font(.system(size: 12))
                        .foregroundStyle(RaycastTheme.mute)
                }

                HStack {
                    TextField("Enter term (e.g. Pro, AirDrop, Face ID)...", text: $newTermInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(RaycastTheme.surfaceCard)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))

                    Button("Add Term") {
                        let trimmed = newTermInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !viewModel.glossaryKeywords.contains(trimmed) {
                            viewModel.glossaryKeywords.append(trimmed)
                            newTermInput = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE GLOSSARY TERMS (\(viewModel.glossaryKeywords.count))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RaycastTheme.ash)

                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.glossaryKeywords, id: \.self) { term in
                            glossaryChip(term)
                        }
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }

    private func glossaryChip(_ term: String) -> some View {
        HStack(spacing: 6) {
            Text(term)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RaycastTheme.ink)

            Button {
                viewModel.glossaryKeywords.removeAll { $0 == term }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(RaycastTheme.mute)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(RaycastTheme.surfaceCard)
                .overlay(Capsule().stroke(RaycastTheme.hairline, lineWidth: 1))
        )
    }
}

// MARK: - Provider Icon Helper View
struct ProviderIconView: View {
    let type: AIProviderType

    var body: some View {
        switch type {
        case .openAI:
            Image(systemName: "sparkles")
                .foregroundStyle(Color.green)
        case .anthropicClaude:
            Image(systemName: "brain.head.profile")
                .foregroundStyle(Color.orange)
        case .googleGemini:
            Image(systemName: "globe.americas.fill")
                .foregroundStyle(Color.blue)
        case .deepSeek:
            Image(systemName: "bolt.fill")
                .foregroundStyle(Color.cyan)
        case .ollama:
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Color.purple)
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var totalHeight: CGFloat = 0
        var currentX: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                totalHeight += rowHeight + spacing
                currentX = 0
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentY += rowHeight + spacing
                currentX = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
