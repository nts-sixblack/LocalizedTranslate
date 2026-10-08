//
//  MainWorkspaceViews.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 5 on 10/4/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Sidebar View (Left Pane)
public struct WorkspaceSidebarView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var newLanguageInput: String = ""
    @State private var showAddLanguagePopover: Bool = false

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Branding Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 30, height: 30)
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("L10n Studio")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RaycastTheme.ink)
                    Text("AI Localization Pro")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(RaycastTheme.mute)
                }
                Spacer()

                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(RaycastTheme.mute)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            // Open / Switch File
            VStack(alignment: .leading, spacing: 8) {
                if let url = viewModel.fileURL {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(RaycastTheme.accentBlue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(RaycastTheme.ink)
                                .lineLimit(1)
                            Text(url.deletingLastPathComponent().path)
                                .font(.system(size: 10))
                                .foregroundStyle(RaycastTheme.mute)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            viewModel.closeCurrentFile()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .buttonStyle(.plain)
                        .help("Close file and clear cache")
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(RaycastTheme.surfaceCard)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                    )
                }

                Button {
                    chooseFile()
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(viewModel.catalog == nil ? "Open .xcstrings File..." : "Switch File...")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RaycastTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(RaycastTheme.surfaceElevated)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)

            Divider().background(RaycastTheme.hairline)

            // Target Languages List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TARGET LANGUAGES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RaycastTheme.ash)
                    Spacer()
                    Button {
                        showAddLanguagePopover.toggle()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(RaycastTheme.accentBlue)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAddLanguagePopover) {
                        VStack(spacing: 8) {
                            Text("Add Language Code (e.g. ja, fr, vi)")
                                .font(.system(size: 11, weight: .medium))
                            TextField("Locale code", text: $newLanguageInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                            Button("Add") {
                                viewModel.addTargetLanguage(newLanguageInput)
                                newLanguageInput = ""
                                showAddLanguagePopover = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, 14)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.targetLanguages, id: \.self) { lang in
                            let isSelected = viewModel.selectedLanguage == lang
                            let stats = viewModel.progressStats(for: lang)
                            Button {
                                viewModel.selectedLanguage = lang
                                viewModel.refreshQA()
                            } label: {
                                HStack {
                                    Text(localeName(for: lang))
                                        .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                        .foregroundStyle(isSelected ? RaycastTheme.ink : RaycastTheme.body)
                                    Spacer()
                                    let staleCount = viewModel.staleTranslationsCount(allLanguages: false)
                                    if isSelected && staleCount > 0 {
                                        Text("\(staleCount) stale")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(RaycastTheme.accentYellow)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(RaycastTheme.accentYellow.opacity(0.12)))
                                    }
                                    Text(stats.percentageString)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(stats.completionRate >= 1.0 ? RaycastTheme.accentGreen : (isSelected ? RaycastTheme.accentBlue : RaycastTheme.mute))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            Capsule()
                                                .fill((stats.completionRate >= 1.0 ? RaycastTheme.accentGreen : RaycastTheme.accentBlue).opacity(0.12))
                                        )
                                    Text(lang.uppercased())
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(RaycastTheme.mute)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
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
                    }
                    .padding(.horizontal, 8)
                }
            }

            Spacer()

            // Quick Stats & Progress Chart Card
            if let cat = viewModel.catalog {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Source:")
                            .font(.system(size: 11))
                            .foregroundStyle(RaycastTheme.mute)
                        Text(cat.sourceLanguage.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(RaycastTheme.ink)
                        Spacer()
                        Text("\(cat.strings.count) keys")
                            .font(.system(size: 11))
                            .foregroundStyle(RaycastTheme.mute)
                    }

                    if !viewModel.selectedLanguage.isEmpty {
                        Divider().background(RaycastTheme.hairline)
                        TranslationSegmentedChartView(stats: viewModel.progressStats(for: viewModel.selectedLanguage))
                    }

                    let staleCount = viewModel.staleTranslationsCount(allLanguages: true)
                    if staleCount > 0 {
                        Divider().background(RaycastTheme.hairline)
                        Button {
                            viewModel.clearStaleTranslations(allLanguages: true)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.xmark")
                                    .font(.system(size: 11))
                                    .foregroundStyle(RaycastTheme.accentYellow)
                                Text("Delete \(staleCount) stale items")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(RaycastTheme.ink)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Delete stale string catalog rows because they are no longer used")
                    }

                    if let saveMsg = viewModel.saveStatusMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(RaycastTheme.accentGreen)
                            Text(saveMsg)
                                .font(.system(size: 10))
                                .foregroundStyle(RaycastTheme.mute)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(RaycastTheme.surfaceCard)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(RaycastTheme.surface)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json, .init(filenameExtension: "xcstrings")].compactMap { $0 }

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.openFile(url: url)
        }
    }

    private func localeName(for code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }
}

// MARK: - Key List View (Center Pane)
public struct StringCatalogListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search and Filters Header
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(RaycastTheme.mute)
                        .font(.system(size: 13))
                    TextField("Search keys or text...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(RaycastTheme.ink)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(RaycastTheme.surfaceElevated)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                )

                // Filter Chips
                HStack(spacing: 6) {
                    ForEach(FilterMode.allCases) { mode in
                        let isSelected = viewModel.filterMode == mode
                        Button {
                            viewModel.filterMode = mode
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? RaycastTheme.ink : RaycastTheme.mute)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? RaycastTheme.surfaceCard : Color.clear)
                                        .overlay(Capsule().stroke(isSelected ? RaycastTheme.hairlineStrong : RaycastTheme.hairline, lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(RaycastTheme.canvas)

            if viewModel.filterMode == .hasIssues {
                let errCount = viewModel.qaIssues.filter { $0.severity == .error }.count
                let warnCount = viewModel.qaIssues.filter { $0.severity == .warning }.count
                HStack(spacing: 8) {
                    Image(systemName: errCount > 0 ? "exclamationmark.triangle.fill" : "shield.lefthalf.filled")
                        .foregroundStyle(errCount > 0 ? RaycastTheme.accentRed : RaycastTheme.accentYellow)
                        .font(.system(size: 12))
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("\(viewModel.qaIssues.count) QA issues in [\(viewModel.selectedLanguage.uppercased())]")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(RaycastTheme.ink)
                            if errCount > 0 || warnCount > 0 {
                                Text("(\(errCount > 0 ? "\(errCount) errors" : "")\(errCount > 0 && warnCount > 0 ? ", " : "")\(warnCount > 0 ? "\(warnCount) warnings" : ""))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(errCount > 0 ? RaycastTheme.accentRed : RaycastTheme.accentYellow)
                            }
                        }
                        Text("\(viewModel.totalQAIssuesCount) total across all languages")
                            .font(.system(size: 10))
                            .foregroundStyle(RaycastTheme.mute)
                    }
                    Spacer()
                    Button("Fix \(viewModel.selectedLanguage.uppercased())") {
                        Task { await viewModel.retranslateQAIssues(allLanguages: false) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.qaIssues.isEmpty || viewModel.translationManager.isTranslating)

                    Button("Fix All Langs") {
                        Task { await viewModel.retranslateQAIssues(allLanguages: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(
                        viewModel.totalQAIssuesCount == 0 || viewModel.translationManager.isTranslating
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(errCount > 0 ? RaycastTheme.accentRed.opacity(0.12) : RaycastTheme.accentYellow.opacity(0.12))
                .overlay(
                    Rectangle().frame(height: 1).foregroundStyle(errCount > 0 ? RaycastTheme.accentRed.opacity(0.25) : RaycastTheme.accentYellow.opacity(0.25)),
                    alignment: .bottom
                )
            }

            // Live Translation Progress Banner when translating
            if viewModel.translationManager.isTranslating {
                TranslationLiveProgressBanner(viewModel: viewModel)
            } else if !viewModel.selectedLanguage.isEmpty && viewModel.catalog != nil {
                // Interactive Progress Summary Bar
                let stats = viewModel.progressStats(for: viewModel.selectedLanguage)
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        let total = max(CGFloat(stats.totalCount), 1)
                        let trW = (CGFloat(stats.translatedCount) / total) * geo.size.width
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(RaycastTheme.surfaceElevated)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(RaycastTheme.accentGreen)
                                .frame(width: max(0, min(trW, geo.size.width)), height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(stats.percentageString) translated (\(stats.translatedCount)/\(stats.totalCount))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(RaycastTheme.mute)

                    if stats.missingCount > 0 {
                        Text("• \(stats.missingCount) missing")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(RaycastTheme.ash)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RaycastTheme.surface)
            }

            Divider().background(RaycastTheme.hairline)

            // Items List
            ScrollView {
                LazyVStack(spacing: 1) {
                    let items = viewModel.filteredItems
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundStyle(RaycastTheme.ash)
                            Text("No strings match filter")
                                .font(.system(size: 13))
                                .foregroundStyle(RaycastTheme.mute)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(items) { item in
                            let isSelected = viewModel.selectedKey == item.key
                            Button {
                                viewModel.selectedKey = item.key
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(item.key)
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundStyle(RaycastTheme.ink)
                                                .lineLimit(1)
                                            Spacer()
                                            if item.hasIssues {
                                                let hasError = item.issues.contains { $0.severity == .error }
                                                Image(systemName: hasError ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                                    .foregroundStyle(hasError ? RaycastTheme.accentRed : RaycastTheme.accentYellow)
                                                    .font(.system(size: 11))
                                                    .help(hasError ? "Critical QA Error: Risk of crash or invalid format" : "QA Warning")
                                            }
                                        }

                                        Text(item.sourceText)
                                            .font(.system(size: 12))
                                            .foregroundStyle(RaycastTheme.body)
                                            .lineLimit(1)

                                        if let tr = item.translatedText, !tr.isEmpty {
                                            Text(tr)
                                                .font(.system(size: 12))
                                                .foregroundStyle(RaycastTheme.mute)
                                                .lineLimit(1)
                                        }
                                    }

                                    statusBadge(for: item)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
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
                    }
                }
                .padding(8)
            }
        }
        .background(RaycastTheme.canvas)
    }

    @ViewBuilder
    private func statusBadge(for item: DisplayCatalogItem) -> some View {
        if item.hasIssues && !item.issues.isEmpty {
            let sortedIssues = item.issues.sorted { $0.severity > $1.severity }
            let primaryIssue = sortedIssues[0]
            let color: Color = {
                if primaryIssue.severity == .error {
                    return RaycastTheme.accentRed
                } else if primaryIssue.category == .brandVoice {
                    return RaycastTheme.accentBlue
                } else {
                    return RaycastTheme.accentYellow
                }
            }()

            let tooltip = sortedIssues.map { issue in
                "[\(issue.severity.rawValue)] \(issue.category.rawValue): \(issue.message)"
            }.joined(separator: "\n")

            HStack(spacing: 4) {
                StatusPill(
                    title: primaryIssue.category.shortBadgeTitle,
                    color: color,
                    icon: primaryIssue.category.systemIcon
                )

                if sortedIssues.count > 1 {
                    StatusPill(
                        title: "+\(sortedIssues.count - 1)",
                        color: RaycastTheme.ash
                    )
                }
            }
            .help(tooltip)
        } else if item.translatedText != nil && !(item.translatedText?.isEmpty ?? true) {
            StatusPill(title: "DONE", color: RaycastTheme.accentGreen)
        } else {
            StatusPill(title: "EMPTY", color: RaycastTheme.ash)
        }
    }
}

// MARK: - Detail Editor View (Right Pane)
public struct DetailEditorView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var editedTranslation: String = ""

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let key = viewModel.selectedKey, let cat = viewModel.catalog, let group = cat.strings[key] {
                let srcText = group.localizations?[cat.sourceLanguage]?.stringUnit?.value ?? key
                let targetUnit = group.localizations?[viewModel.selectedLanguage]
                let currentTr = targetUnit?.stringUnit?.value ?? ""
                let issues = viewModel.qaIssues.filter { $0.key == key }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header: Key & Actions
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("KEY")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(RaycastTheme.ash)
                                Text(key)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RaycastTheme.ink)
                            }
                            Spacer()
                            RaycastPillButton(
                                title: viewModel.isTranslatingKey == key ? "Translating..." : "Translate (AI)",
                                icon: viewModel.isTranslatingKey == key ? "arrow.triangle.2.circlepath" : "sparkles"
                            ) {
                                Task {
                                    await viewModel.translateKey(key)
                                }
                            }
                            .disabled(viewModel.isTranslatingKey == key || viewModel.translationManager.isTranslating)
                        }

                        if let comment = group.comment, !comment.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DEVELOPER COMMENT")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(RaycastTheme.ash)
                                Text(comment)
                                    .font(.system(size: 12))
                                    .foregroundStyle(RaycastTheme.mute)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(RaycastTheme.surfaceElevated)
                                    )
                            }
                        }

                        // Source String Box
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("SOURCE (\(cat.sourceLanguage.uppercased()))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(RaycastTheme.ash)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(srcText, forType: .string)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.system(size: 10))
                                    .foregroundStyle(RaycastTheme.mute)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(srcText)
                                .font(.system(size: 13))
                                .foregroundStyle(RaycastTheme.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(RaycastTheme.surfaceCard)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(RaycastTheme.hairline, lineWidth: 1))
                                )
                        }

                        // Target Translation Box
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("TRANSLATION (\(viewModel.selectedLanguage.uppercased()))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(RaycastTheme.accentBlue)
                                Spacer()
                                if targetUnit?.hasTranslation == true {
                                    Text("State: \(targetUnit?.stringUnit?.state ?? "translated")")
                                        .font(.system(size: 10))
                                        .foregroundStyle(RaycastTheme.mute)
                                }
                            }

                            TextEditor(text: Binding(
                                get: { editedTranslation },
                                set: { newVal in
                                    editedTranslation = newVal
                                    viewModel.updateManualTranslation(key: key, newTranslation: newVal)
                                }
                            ))
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(RaycastTheme.surfaceCard)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(RaycastTheme.hairline, lineWidth: 1)
                            )
                        }

                        // QA Guardian Alerts Box
                        if !issues.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .foregroundStyle(RaycastTheme.accentYellow)
                                    Text("QA Guardian Alerts (\(issues.count))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(RaycastTheme.ink)
                                    Spacer()
                                    Button {
                                        Task {
                                            await viewModel.translateKey(key)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "wand.and.stars")
                                            Text("Re-translate AI")
                                        }
                                        .font(.system(size: 11, weight: .medium))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.mini)
                                    .disabled(viewModel.translationManager.isTranslating || viewModel.isTranslatingKey == key)
                                    .help("Re-translate this string with active AI to resolve QA issues")
                                }

                                ForEach(issues) { issue in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(issue.category.rawValue)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(issue.severity == .error ? RaycastTheme.accentRed : RaycastTheme.accentYellow)
                                            Spacer()
                                            StatusPill(
                                                title: issue.severity.rawValue,
                                                color: issue.severity == .error ? RaycastTheme.accentRed : RaycastTheme.accentYellow
                                            )
                                        }

                                        Text(issue.message)
                                            .font(.system(size: 12))
                                            .foregroundStyle(RaycastTheme.body)

                                        if let fix = issue.suggestedFix {
                                            HStack {
                                                Text("Fix: \(fix)")
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundStyle(RaycastTheme.accentGreen)
                                                Spacer()
                                                Button("Auto-Fix") {
                                                    viewModel.updateManualTranslation(key: key, newTranslation: fix)
                                                    editedTranslation = fix
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.mini)
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(RaycastTheme.surfaceElevated)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RaycastTheme.hairline, lineWidth: 1))
                                    )
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(RaycastTheme.surfaceCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(RaycastTheme.accentYellow.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(20)
                }
                .onAppear {
                    editedTranslation = currentTr
                }
                .onChange(of: key) {
                    editedTranslation = cat.strings[key]?.localizations?[viewModel.selectedLanguage]?.stringUnit?.value ?? ""
                }
                .onChange(of: viewModel.selectedLanguage) {
                    editedTranslation = cat.strings[key]?.localizations?[viewModel.selectedLanguage]?.stringUnit?.value ?? ""
                }
                .onChange(of: viewModel.lastTranslationUpdatedKey) {
                    if viewModel.lastTranslationUpdatedKey == key, let updated = viewModel.lastTranslationValue {
                        editedTranslation = updated
                    }
                }
                .onChange(of: viewModel.catalogVersion) {
                    if let cat = viewModel.catalog, let currentKey = viewModel.selectedKey {
                        editedTranslation = cat.strings[currentKey]?.localizations?[viewModel.selectedLanguage]?.stringUnit?.value ?? ""
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 40))
                        .foregroundStyle(RaycastTheme.ash)
                    Text("Select a string to inspect and translate")
                        .font(.system(size: 14))
                        .foregroundStyle(RaycastTheme.mute)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(RaycastTheme.surface)
    }
}

// MARK: - Translation Live Progress Banner
public struct TranslationLiveProgressBanner: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let mgr = viewModel.translationManager
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Translating...")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(RaycastTheme.accentBlue)
                        if !mgr.activeLanguage.isEmpty {
                            Text("[\(mgr.activeLanguage.uppercased())]")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(RaycastTheme.ink)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(RaycastTheme.surfaceElevated))
                        }
                        Spacer()
                        Text("\(Int(mgr.progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(RaycastTheme.accentBlue)
                    }
                    Text(mgr.statusMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(RaycastTheme.mute)
                        .lineLimit(1)
                }

                Button("Cancel") {
                    viewModel.translationManager.cancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            // Animated Linear Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(RaycastTheme.surfaceElevated)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [RaycastTheme.accentBlue, RaycastTheme.accentGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width * CGFloat(mgr.progress), geo.size.width)), height: 6)
                        .animation(.easeInOut(duration: 0.2), value: mgr.progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(mgr.completedCount) of \(mgr.totalCount) items")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(RaycastTheme.mute)
                Spacer()
                if mgr.errorCount > 0 {
                    Text("\(mgr.errorCount) failed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(RaycastTheme.accentRed)
                }
                Text("\(mgr.successCount) succeeded")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(RaycastTheme.accentGreen)
            }
        }
        .padding(10)
        .background(RaycastTheme.accentBlue.opacity(0.08))
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(RaycastTheme.accentBlue.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Translation Segmented Chart View
public struct TranslationSegmentedChartView: View {
    public let stats: LanguageProgressStats

    public init(stats: LanguageProgressStats) {
        self.stats = stats
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stats.language.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(RaycastTheme.ink)
                Text("• \(stats.percentageString) Translated")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(stats.completionRate >= 1.0 ? RaycastTheme.accentGreen : RaycastTheme.accentBlue)
                Spacer()
                Text("\(stats.translatedCount)/\(stats.totalCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(RaycastTheme.mute)
            }

            // Segmented Progress Bar
            GeometryReader { geo in
                let total = max(CGFloat(stats.totalCount), 1)
                let trW = (CGFloat(stats.translatedCount) / total) * geo.size.width
                let issueW = (CGFloat(stats.issuesCount) / total) * geo.size.width

                ZStack(alignment: .leading) {
                    // Background / Missing
                    RoundedRectangle(cornerRadius: 3)
                        .fill(RaycastTheme.surfaceElevated)
                        .frame(height: 6)

                    // Translated
                    RoundedRectangle(cornerRadius: 3)
                        .fill(RaycastTheme.accentGreen)
                        .frame(width: max(0, min(trW, geo.size.width)), height: 6)

                    // QA Issues highlight
                    if stats.issuesCount > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(RaycastTheme.accentYellow)
                            .frame(width: max(2, min(issueW, geo.size.width)), height: 6)
                    }
                }
            }
            .frame(height: 6)

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(RaycastTheme.accentGreen).frame(width: 6, height: 6)
                    Text("\(stats.translatedCount) Done")
                        .font(.system(size: 10))
                        .foregroundStyle(RaycastTheme.mute)
                }
                HStack(spacing: 4) {
                    Circle().fill(RaycastTheme.ash).frame(width: 6, height: 6)
                    Text("\(stats.missingCount) Missing")
                        .font(.system(size: 10))
                        .foregroundStyle(RaycastTheme.mute)
                }
                if stats.issuesCount > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(RaycastTheme.accentYellow).frame(width: 6, height: 6)
                        Text("\(stats.issuesCount) QA")
                            .font(.system(size: 10))
                            .foregroundStyle(RaycastTheme.accentYellow)
                    }
                }
            }
        }
    }
}
