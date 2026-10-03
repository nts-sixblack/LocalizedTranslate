//
//  QuickCommandPalette.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 5 on 10/4/26.
//

import SwiftUI

public struct CommandPaletteItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let icon: String
    public let shortcut: String?
    public let action: () -> Void
}

public struct QuickCommandPalette: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var query: String = ""
    @Binding var isPresented: Bool

    public init(viewModel: WorkspaceViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
    }

    private var allCommands: [CommandPaletteItem] {
        [
            CommandPaletteItem(
                title: "Translate All Missing Strings (All Languages)",
                subtitle: "Primary: Batch translate missing strings across all target languages",
                icon: "sparkles",
                shortcut: "⌘⇧T",
                action: {
                    Task { await viewModel.translateAllMissing(allLanguages: true) }
                }
            ),
            CommandPaletteItem(
                title: "Translate Missing Strings (\(viewModel.selectedLanguage.uppercased()) only)",
                subtitle: "Uses active AI engine for currently selected target language",
                icon: "character.bubble",
                shortcut: nil,
                action: {
                    Task { await viewModel.translateAllMissing(allLanguages: false) }
                }
            ),
            CommandPaletteItem(
                title: "Fix QA Issues (All Languages)",
                subtitle: "Re-translate strings flagged with QA errors across all languages",
                icon: "globe",
                shortcut: nil,
                action: {
                    Task { await viewModel.retranslateQAIssues(allLanguages: true) }
                }
            ),
            CommandPaletteItem(
                title: "Fix QA Issues (\(viewModel.selectedLanguage.uppercased()) only)",
                subtitle: "Re-translate QA issues for currently selected language",
                icon: "wand.and.stars",
                shortcut: nil,
                action: {
                    Task { await viewModel.retranslateQAIssues(allLanguages: false) }
                }
            ),
            CommandPaletteItem(
                title: "Run QA Guardian Inspection",
                subtitle: "Scan all keys for broken placeholders & specifiers",
                icon: "shield.checkerboard",
                shortcut: "⌘R",
                action: {
                    viewModel.refreshQA()
                }
            ),
            CommandPaletteItem(
                title: "Save Catalog & Backup",
                subtitle: "Writes changes to .xcstrings with automatic backup snapshot",
                icon: "square.and.arrow.down",
                shortcut: "⌘S",
                action: {
                    viewModel.saveCatalog()
                }
            ),
            CommandPaletteItem(
                title: "Filter: Show Untranslated Only",
                subtitle: "Isolate strings pending translation",
                icon: "line.3.horizontal.decrease.circle",
                shortcut: nil,
                action: {
                    viewModel.filterMode = .untranslated
                }
            ),
            CommandPaletteItem(
                title: "Filter: Show QA Issues Only",
                subtitle: "Isolate entries with placeholder or length warnings",
                icon: "exclamationmark.triangle",
                shortcut: nil,
                action: {
                    viewModel.filterMode = .hasIssues
                }
            ),
            CommandPaletteItem(
                title: "Switch AI Provider: OpenAI",
                subtitle: "Use GPT-4o / GPT-4o-mini",
                icon: "cpu",
                shortcut: nil,
                action: {
                    viewModel.selectedProviderType = .openAI
                }
            ),
            CommandPaletteItem(
                title: "Switch AI Provider: Anthropic Claude",
                subtitle: "Use Claude 3.5 Sonnet",
                icon: "sparkle",
                shortcut: nil,
                action: {
                    viewModel.selectedProviderType = .anthropicClaude
                }
            ),
            CommandPaletteItem(
                title: "Switch AI Provider: Ollama (Offline / Private)",
                subtitle: "100% Local LLM on localhost:11434",
                icon: "lock.shield",
                shortcut: nil,
                action: {
                    viewModel.selectedProviderType = .ollama
                }
            ),
            CommandPaletteItem(
                title: "Open Preferences & API Keys",
                subtitle: "Configure credentials in Apple Keychain",
                icon: "gearshape",
                shortcut: "⌘,",
                action: {
                    viewModel.showSettings = true
                }
            )
        ]
    }

    private var filteredCommands: [CommandPaletteItem] {
        if query.isEmpty { return allCommands }
        return allCommands.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(RaycastTheme.mute)
                TextField("Type a command or search actions...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(RaycastTheme.ink)
                KeycapBadge("ESC")
            }
            .padding(14)
            .background(RaycastTheme.surfaceCard)

            Divider().background(RaycastTheme.hairline)

            // Command Items
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCommands) { cmd in
                        Button {
                            isPresented = false
                            cmd.action()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: cmd.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(RaycastTheme.accentBlue)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(RaycastTheme.ink)
                                    Text(cmd.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(RaycastTheme.mute)
                                }

                                Spacer()

                                if let shortcut = cmd.shortcut {
                                    KeycapBadge(shortcut)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 540, height: 380)
        .background(RaycastTheme.surfaceElevated)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RaycastTheme.hairlineStrong, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 25, y: 10)
    }
}
