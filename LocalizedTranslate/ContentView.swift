//
//  ContentView.swift
//  LocalizedTranslate
//
//  Created by SixBlack on 3/10/26.
//  Upgraded by Coordinator & Sub-Agents on 10/4/26.
//

import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Persistent Error / Alert Banner
                if let err = viewModel.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(RaycastTheme.accentRed)
                        Text(err)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RaycastTheme.ink)
                            .lineLimit(2)
                        Spacer()
                        if err.contains("API key") || err.contains("Preferences") {
                            Button("Preferences...") {
                                viewModel.showSettings = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        Button {
                            viewModel.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RaycastTheme.accentRed.opacity(0.12))
                    .overlay(
                        Rectangle().frame(height: 1).foregroundStyle(RaycastTheme.accentRed.opacity(0.3)),
                        alignment: .bottom
                    )
                }

                NavigationSplitView(columnVisibility: $columnVisibility) {
                    WorkspaceSidebarView(viewModel: viewModel)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
                } content: {
                    StringCatalogListView(viewModel: viewModel)
                        .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 500)
                } detail: {
                    DetailEditorView(viewModel: viewModel)
                }
            }
            .navigationTitle(viewModel.fileURL?.lastPathComponent ?? "L10n Studio Pro")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    // Active AI Engine Switcher Menu
                    Menu {
                        Section("Active AI Engine") {
                            ForEach(AIProviderType.allCases) { type in
                                Button {
                                    viewModel.selectedProviderType = type
                                } label: {
                                    HStack {
                                        Text(type.rawValue)
                                        if viewModel.selectedProviderType == type {
                                            Image(systemName: "checkmark")
                                        }
                                        if viewModel.hasCredential(for: type) {
                                            Text("• Ready")
                                        } else {
                                            Text("• No Key")
                                        }
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("Configure AI Keys...") {
                            viewModel.showSettings = true
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(viewModel.activeProviderHasKey ? RaycastTheme.accentGreen : RaycastTheme.accentRed)
                                .frame(width: 7, height: 7)
                            Text(viewModel.selectedProviderType.shortName)
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(RaycastTheme.surfaceCard)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .help("Active AI Engine: \(viewModel.selectedProviderType.rawValue)")

                    // Translation Progress Bar
                    if viewModel.translationManager.isTranslating {
                        HStack(spacing: 8) {
                            ProgressView(value: viewModel.translationManager.progress)
                                .progressViewStyle(.linear)
                                .frame(width: 100)
                            Text(viewModel.translationManager.statusMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(RaycastTheme.mute)
                                .lineLimit(1)
                            Button("Cancel") {
                                viewModel.translationManager.cancel()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }

                    // Primary Button: Translate All Missing across All Languages
                    RaycastPillButton(
                        title: viewModel.translationManager.isTranslating ? "Translating..." : "Translate All Missing",
                        icon: viewModel.translationManager.isTranslating ? "arrow.triangle.2.circlepath" : "sparkles"
                    ) {
                        Task {
                            await viewModel.translateAllMissing(allLanguages: true)
                        }
                    }
                    .disabled(viewModel.catalog == nil || viewModel.translationManager.isTranslating)
                    .help("Primary: Translate all missing strings across ALL target languages (\(viewModel.targetLanguages.count))")

                    // Secondary Action: Translate Missing for Selected Language Only
                    Menu {
                        Button {
                            Task {
                                await viewModel.translateAllMissing(allLanguages: false)
                            }
                        } label: {
                            Label("Translate Missing for \(viewModel.selectedLanguage.uppercased()) only", systemImage: "character.bubble")
                        }
                        Divider()
                        Button {
                            Task {
                                await viewModel.translateAllMissing(allLanguages: true)
                            }
                        } label: {
                            Label("Translate Missing for ALL Languages (\(viewModel.targetLanguages.count))", systemImage: "globe")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "character.bubble")
                                .font(.system(size: 11))
                            Text(viewModel.selectedLanguage.isEmpty ? "1 Lang" : viewModel.selectedLanguage.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .foregroundStyle(RaycastTheme.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(RaycastTheme.surfaceElevated)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(viewModel.catalog == nil || viewModel.translationManager.isTranslating)
                    .help("Translate missing strings for selected language (\(viewModel.selectedLanguage.uppercased()))")

                    let staleCount = viewModel.staleTranslationsCount(allLanguages: true)
                    Menu {
                        Button(role: .destructive) {
                            viewModel.clearStaleTranslations(allLanguages: true)
                        } label: {
                            Label("Delete ALL stale items (\(staleCount))", systemImage: "trash")
                        }
                        .disabled(staleCount == 0)

                        Button(role: .destructive) {
                            viewModel.clearStaleTranslations(allLanguages: false)
                        } label: {
                            Label("Delete stale items in \(viewModel.selectedLanguage.uppercased())", systemImage: "trash.circle")
                        }
                        .disabled(viewModel.selectedLanguage.isEmpty || viewModel.staleTranslationsCount(allLanguages: false) == 0)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.badge.xmark")
                                .font(.system(size: 11))
                                .foregroundStyle(staleCount > 0 ? RaycastTheme.accentYellow : RaycastTheme.mute)
                            Text("Delete Stale")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(RaycastTheme.ink)
                            Text("\(staleCount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(staleCount > 0 ? RaycastTheme.onPrimaryBlack : RaycastTheme.mute)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(staleCount > 0 ? RaycastTheme.accentYellow : RaycastTheme.surfaceCard))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(RaycastTheme.surfaceElevated)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(staleCount > 0 ? RaycastTheme.accentYellow.opacity(0.4) : RaycastTheme.hairline, lineWidth: 1))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(viewModel.catalog == nil || viewModel.translationManager.isTranslating)
                    .help("Delete stale string catalog rows because they are no longer used")

                    // Re-translate QA Issues Menu (Supports All Languages or Single Language)
                    Menu {
                        Section("Fix QA Issues with AI") {
                            Button {
                                Task {
                                    await viewModel.retranslateQAIssues(allLanguages: true)
                                }
                            } label: {
                                Label(
                                    "Fix QA in ALL Languages (\(viewModel.totalQAIssuesCount) issues)",
                                    systemImage: "globe"
                                )
                            }
                            .disabled(viewModel.totalQAIssuesCount == 0)

                            Button {
                                Task {
                                    await viewModel.retranslateQAIssues(allLanguages: false)
                                }
                            } label: {
                                Label(
                                    "Fix QA in \(viewModel.selectedLanguage.uppercased()) (\(viewModel.qaIssues.count) issues)",
                                    systemImage: "character.bubble"
                                )
                            }
                            .disabled(viewModel.qaIssues.isEmpty)
                        }

                        Divider()

                        Button {
                            viewModel.refreshQA()
                        } label: {
                            Label("Run QA Check (⌘R)", systemImage: "shield.checkerboard")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                                .foregroundStyle(viewModel.totalQAIssuesCount > 0 ? RaycastTheme.accentYellow : RaycastTheme.mute)
                            Text("Fix QA")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(RaycastTheme.ink)
                            if viewModel.totalQAIssuesCount > 0 {
                                Text("\(viewModel.totalQAIssuesCount)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RaycastTheme.onPrimaryBlack)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(RaycastTheme.accentYellow))
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(RaycastTheme.surfaceElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(viewModel.totalQAIssuesCount > 0 ? RaycastTheme.accentYellow.opacity(0.4) : RaycastTheme.hairline, lineWidth: 1)
                                )
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(viewModel.catalog == nil || viewModel.translationManager.isTranslating)
                    .help("Re-translate QA Issues (Format specifiers, tags, brand voice)")

                    // Run QA Inspection
                    Button {
                        viewModel.refreshQA()
                    } label: {
                        Label("QA Check", systemImage: "shield.checkerboard")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Inspect catalog for formatting & placeholder errors (⌘R)")

                    // Command Palette Trigger
                    Button {
                        viewModel.showCommandPalette.toggle()
                    } label: {
                        Label("Commands", systemImage: "command")
                    }
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Open Raycast Command Palette (⌘K)")

                    // Preferences
                    Button {
                        viewModel.showSettings.toggle()
                    } label: {
                        Label("Preferences", systemImage: "gearshape")
                    }
                    .keyboardShortcut(",", modifiers: .command)
                    .help("Settings & API Keys (⌘,)")

                    // Save Catalog & Status Indicator
                    if let saveMsg = viewModel.saveStatusMessage {
                        Text(saveMsg)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(RaycastTheme.mute)
                    }

                    Button {
                        viewModel.saveCatalog()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(viewModel.catalog == nil)
                    .help("Save catalog to disk (⌘S)")
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url, url.pathExtension == "xcstrings" {
                        DispatchQueue.main.async {
                            viewModel.openFile(url: url)
                        }
                    }
                }
                return true
            }

            // Raycast Floating Command Palette Modal
            if viewModel.showCommandPalette {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.showCommandPalette = false
                    }

                QuickCommandPalette(
                    viewModel: viewModel,
                    isPresented: $viewModel.showCommandPalette
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
