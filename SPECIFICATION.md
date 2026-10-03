# SPECIFICATION: LocalizedTranslate (L10n Studio Pro)
**Next-Generation AI-Powered Localization Studio for macOS**

*Version:* 1.0.0-PRO  
*Author:* Lead Software Architect & System Coordinator  
*Target OS:* macOS 14.0+ (Sonoma, Sequoia & beyond)  
*Technology Stack:* Swift 5.10 / Swift 6, SwiftUI, Swift Concurrency (Actors, AsyncAlgorithms), KeychainAccess, Apple HIG & Raycast-inspired Dark Canvas Design System.

---

## 1. Executive Summary & Vision

### 1.1 Sứ mệnh sản phẩm
Hiện nay, việc bản địa hóa (Localization) cho các ứng dụng macOS/iOS/visionOS bằng công cụ truyền thống (Xcode String Catalog Editor, Crowdin, Localazy, Poedit) hoặc các CLI script như `AITranslate` gặp các nhược điểm nghiêm trọng:
1. **Thiếu ngữ cảnh (Context Blindness):** Dịch máy dịch từng từ đơn lẻ, không hiểu ngữ cảnh màn hình, dẫn đến bản dịch ngô nghê hoặc sai nghĩa hoàn toàn (ví dụ: "Book" là danh từ "cuốn sách" hay động từ "đặt vé").
2. **Nguy cơ crash app do vỡ format specifiers:** Rất nhiều công cụ dịch tự động làm biến mất `%@`, `%d`, `%1$@`, đổi thứ tự token hoặc dịch cả HTML/XML tag, gây crash ứng dụng runtime.
3. **Không xử lý được biến thể phức tạp:** Các script đơn giản không hỗ trợ hoặc bỏ qua Plural rules (zero, one, two, few, many, other) và Device variations (Mac, iPhone, iPad, Apple Watch, Apple Vision Pro).
4. **Trải nghiệm rời rạc:** Lập trình viên phải chuyển đổi giữa terminal, web browser và Xcode; không có diff viewer, không kiểm soát được chi phí token trước khi dịch, không có tính năng khóa thuật ngữ (Glossary/Brand voice).

**LocalizedTranslate (L10n Studio Pro)** được xây dựng để trở thành **ứng dụng bản địa hóa số 1 trên macOS**:
- Tích hợp sâu vào quy trình phát triển Xcode (`.xcstrings`, `.strings`, `.stringsdict`).
- Đa nhà cung cấp AI: OpenAI, Anthropic Claude, Google Gemini, DeepSeek và **Local LLMs (Ollama / Apple Intelligence)** đảm bảo bảo mật mã nguồn tối đa.
- Cơ chế **Visual & Screen Context Awareness** (phân tích ảnh chụp màn hình UI đính kèm để định hướng dịch chuẩn xác 100%).
- Hệ thống **QA Linter & Guardian**: Ngăn chặn 100% lỗi format specifier, cảnh báo tràn chuỗi (UI Overflow Alert).
- Trải nghiệm Raycast-grade Native UI: Siêu tốc, bàn phím điều hướng `Cmd + K`, thiết kế tối giản sang trọng theo chuẩn `DESIGN.md`.

---

## 2. Competitive Matrix & Core Differentiators

| Tính năng | AITranslate (CLI gốc) | Xcode Native Editor | Crowdin / Localazy | LocalizedTranslate (L10n Studio) |
| :--- | :---: | :---: | :---: | :---: |
| **Giao diện** | Terminal CLI | Xcode Native Tab | Web App nặng nề | **Native macOS App (Raycast UI)** |
| **Định dạng file** | `.xcstrings` cơ bản | `.xcstrings` | Nhiều file qua cloud | **`.xcstrings` (Full), `.strings`, `.stringsdict`, JSON** |
| **Hỗ trợ Plurals & Devices** | ❌ Bỏ qua | ⚠️ Thủ công từng key | ⚠️ Thủ công | **✅ AI dịch tự động theo chuẩn ngữ pháp từng ngôn ngữ** |
| **Mô hình AI** | Cố định GPT-5 mini | ❌ Không có | Cố định / Trả phí đắt | **OpenAI, Anthropic, Gemini, DeepSeek, Local Ollama** |
| **QA / Placeholder Safety** | Regex cơ bản | ❌ | Check thủ công | **✅ Real-time AST Validator & Token Guardian** |
| **Visual Context (Screenshots)**| ❌ | ❌ | Phải upload thủ công | **✅ Kéo thả screenshot, AI Vision đọc UI context** |
| **Bảo mật API Key** | Truyền qua CLI flag | N/A | Server lưu trữ | **✅ Apple Keychain mã hóa cấp phần cứng** |
| **Chi phí & Ước tính token** | ❌ Không tính | N/A | Trả theo gói tháng | **✅ Live Token Estimator & Cost Preview trước khi dịch** |
| **Translation Memory (TM)** | ❌ | ❌ | Cloud-only | **✅ Local SQLite / SwiftData Cache (tiết kiệm 60% chi phí)** |

---

## 3. Product Architecture & Technical Stack

### 3.1 Cấu trúc tầng (Layered Architecture - MVVM-C)
Tuân thủ kiến trúc mô-đun hóa cao, an toàn đa luồng theo tiêu chuẩn Swift 6:
```
┌─────────────────────────────────────────────────────────────┐
│                    macOS App UI Layer                       │
│  - App / Navigation Coordinator                             │
│  - Command Palette (Cmd + K)                                │
│  - 3-Pane Raycast Style Workspace (Sidebar / List / Detail) │
│  - Diff & QA Inspector Sheet                                │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Feature ViewModels                       │
│  - ProjectWorkspaceViewModel                                │
│  - TranslationPipelineViewModel                             │
│  - QAGuardianViewModel                                      │
│  - SettingsAndProvidersViewModel                            │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Core Business Engine                     │
│  - CatalogParser & Serializer (.xcstrings, .strings)        │
│  - TranslationPipelineCoordinator (Batching, Concurrency)   │
│  - QALinterEngine (Regex AST, Token Validation, Length Alert)│
│  - TranslationMemoryEngine (Local Cache & Deduplication)    │
│  - ScreenshotVisionAnalyzer (Vision / OCR Context Builder)  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                 Network & AI Provider Clients               │
│  - AIProviderFactory & Protocols                            │
│  - OpenAIClient (ChatCompletion + Structured Outputs)       │
│  - AnthropicClient (Claude 3.5 Messages API)                │
│  - GeminiClient (v1beta REST API)                           │
│  - OllamaClient (Local HTTP Streaming API)                  │
│  - KeychainManager (Secure Storage for Tokens)              │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Cấu trúc thư mục nguồn dự kiến
```
LocalizedTranslate/
├── App/
│   ├── LocalizedTranslateApp.swift
│   └── AppCoordinator.swift
├── DesignSystem/
│   ├── ColorTokens.swift          // Bảng màu chuẩn DESIGN.md (#07080a, #0d0d0d, hairline #242728, ...)
│   ├── TypographyTokens.swift     // Inter / System San Francisco với letter-spacing và tracking
│   ├── ComponentStyles.swift      // Raycast Card, Primary Pill Button, Keycap badges
│   └── VisualComponents/          // Custom splitters, search bars, status pills
├── Models/
│   ├── XCStrings/                 // Full model StringCatalog, Plurals, Devices, Substitutions
│   ├── LegacyStrings/             // Parser cho .strings và .stringsdict
│   ├── Translation/               // BatchItem, TranslationResult, ProviderConfig
│   ├── QualityAssurance/          // QAIssue, Severity (error/warning), ValidationRule
│   └── Settings/                  // AppPreferences, ProviderType, CustomGlossary
├── Services/
│   ├── Storage/
│   │   ├── KeychainManager.swift  // Lưu an toàn API keys
│   │   └── TranslationMemory.swift// Cache lưu trữ bản dịch cục bộ
│   ├── Parser/
│   │   ├── XCStringsParser.swift  // Đọc / Ghi file JSON với đúng thứ tự key của Apple
│   │   └── LegacyStringsParser.swift
│   ├── AIProviders/
│   │   ├── AIProviderProtocol.swift
│   │   ├── OpenAIProvider.swift
│   │   ├── ClaudeProvider.swift
│   │   ├── GeminiProvider.swift
│   │   ├── OllamaProvider.swift
│   │   └── AIProviderFactory.swift
│   ├── QA/
│   │   └── QALinterService.swift  // Bắt lỗi placeholder, format specifier (%@, %d)
│   └── Pipeline/
│       └── TranslationManager.swift // Actor điều phối batching, retry, rate limit
└── Views/
    ├── MainWorkspace/             // 3-pane layout
    │   ├── SidebarView.swift      // Danh sách file, trạng thái hoàn thành (%)
    │   ├── StringCatalogListView.swift // Danh sách key, filter (untranslated, errors, search)
    │   └── DetailEditorView.swift // Chỉnh sửa song ngữ, plural tabs, context note
    ├── QAInspector/
    │   └── QADashboardView.swift  // Báo cáo lỗi format và gợi ý sửa nhanh
    ├── ContextHub/
    │   └── VisualContextView.swift// Kéo thả screenshot, nhập app description
    ├── Settings/
    │   └── SettingsView.swift     // Quản lý API Key, Provider, Model, Glossary
    └── CommandPalette/
        └── QuickCommandPalette.swift // Raycast Cmd+K palette
```

---

## 4. Chi tiết các chức năng đột phá (Functional Specifications)

### Chức năng 1: Xcode String Catalog Engine 100% tương thích
- **Đọc và ghi chuẩn Apple `.xcstrings`:**
  - Giữ nguyên metadata: `comment`, `extractionState` (`manual`, `extracted_with_value`), `state` (`translated`, `needs_review`, `stale`).
  - Hỗ trợ toàn diện **Plural Variations**: Tự động sinh và dịch đúng danh mục biến thể cho từng ngôn ngữ đích (ví dụ: tiếng Ả Rập có đủ 6 dạng `zero`, `one`, `two`, `few`, `many`, `other`; tiếng Anh có `one`, `other`; tiếng Việt chỉ có `other`).
  - Hỗ trợ **Device Variations**: `mac`, `iphone`, `ipad`, `applewatch`, `applevision`, `appletv`.
  - Giữ nguyên cấu trúc JSON và sắp xếp key tương thích 1:1 với Xcode để tránh xung đột git diff (Match Xcode ordering).
- **Hỗ trợ Legacy Formats:**
  - Import/Export `.strings` và `.stringsdict`.
  - Cho phép 1-Click nâng cấp từ `.strings` sang `.xcstrings`.

### Chức năng 2: Multi-Provider AI Translation Hub & Local LLM
- Hỗ trợ cắm API Key trực tiếp của:
  1. **OpenAI:** GPT-4o, GPT-4o-mini, o3-mini (hỗ trợ Structured JSON Outputs).
  2. **Anthropic Claude:** Claude 3.5 Sonnet, Claude 3.7 Sonnet (văn phong tự nhiên nhất).
  3. **Google Gemini:** Gemini 2.0 Flash, Gemini 1.5 Pro.
  4. **DeepSeek:** DeepSeek V3, DeepSeek R1 (tiết kiệm chi phí vượt trội).
  5. **Ollama / Local LLM (100% Offline & Private):** Kết nối trực tiếp máy chủ cục bộ `http://localhost:11434`, không gửi một dòng mã nào ra internet.
- **Batching & Rate Limit Manager thông minh:**
  - Đóng gói batch linh hoạt (10-30 keys tùy độ dài ký tự).
  - Tự động backoff và retry khi chạm rate limit (HTTP 429).
  - Fallback thông minh: Nếu một batch gặp lỗi decode, hệ thống tự động rã batch ra dịch lẻ từng key thay vì làm hỏng toàn bộ quá trình.

### Chức năng 3: Ngữ cảnh trực quan (Visual Context) & App Persona
- **Screen & UI Persona:**
  - Cho phép lập trình viên định nghĩa "App Profile": Loại app (Fintech, Sức khỏe, Trò chơi, Công cụ), đối tượng người dùng, phong cách ngôn ngữ (Trang trọng / Thân thiện / Ngắn gọn cho nút bấm).
- **Screenshot Attachment (Visual Localization):**
  - Kéo thả ảnh chụp màn hình vào file/key tương ứng. AI Vision sẽ đọc text trên màn hình, xác định vị trí button hay title để dịch với ngữ nghĩa chính xác tuyệt đối.
- **Context-Preserving Prompting:**
  - Kế thừa và mở rộng hệ thống prompt của `AITranslate`, kèm quy tắc bảo vệ từ viết tắt, casing, dấu câu và chiều dài nút bấm.

### Chức năng 4: QA Guardian & Safety Validator (Linter bảo vệ ứng dụng)
- **Format Specifier AST Validator:**
  - Kiểm tra đối chiếu nghiêm ngặt: Bản gốc có `%@`, `%d`, `%ld`, `%1$@`, `%2$f` thì bản dịch **bắt buộc** phải có đúng số lượng và đúng specifier.
  - Ngăn chặn lỗi kinh điển khi AI dịch `%@` thành `% @` hoặc thay `%d` bằng text.
- **UI Overflow & Length Warning:**
  - Cảnh báo khi chuỗi ngôn ngữ mục tiêu dài hơn 150% chuỗi gốc ở các vị trí là nút bấm hoặc menu.
- **Brand Glossary (Do Not Translate):**
  - Cho phép khai báo danh sách từ độc quyền không được dịch (ví dụ: "AirDrop", "Face ID", tên app...).
  - QA Linter sẽ gắn cờ cảnh báo nếu AI cố tình dịch các từ này.

### Chức năng 5: Translation Memory & Diff Review
- **Local Translation Memory (TM):**
  - Tự động ghi nhớ các cặp source-target đã được duyệt.
  - Khi gặp chuỗi tương tự trong dự án mới hoặc file mới, hệ thống tự động gợi ý hoặc áp dụng ngay, không tốn thêm bất kỳ token AI nào.
- **Side-by-Side Diff Inspector:**
  - Hiển thị trực quan bản dịch cũ và bản dịch mới của AI.
  - Cho phép chọn "Accept All", "Accept Selected", hoặc "Revert" tức thì.
- **Automatic Safe Backups:**
  - Tự động tạo snapshot file `.xcstrings.backup-TIMESTAMP` trước mỗi lần lưu.

### Chức năng 6: Raycast-Grade Design & Productivity UI
- **Thiết kế Dark Canvas sang trọng:**
  - Sử dụng hệ màu theo `DESIGN.md`: Canvas `#07080a`, Surface `#0d0d0d`, Hairline `#242728`, CTA pill trắng thuần khiết `#ffffff`.
- **Command Palette (`Cmd + K`):**
  - Tìm kiếm nhanh mọi tính năng: "Translate Untranslated in French", "Run QA Check", "Export to .strings", "Switch Provider to Claude 3.5 Sonnet".
- **Keyboard Shortcuts:**
  - `Cmd + Enter`: Translate selected.
  - `Cmd + Shift + T`: Translate all missing strings.
  - `Cmd + S`: Safe Save & Sync.

---

## 5. Phân chia công việc cho các Sub-Agents (Sub-Agent Work Packages)

Để xây dựng ứng dụng với tốc độ và chất lượng cao nhất, công việc được chia thành **6 Work Packages (WP)** độc lập, có thể thực hiện song song hoặc tuần tự:

```
[Coordinator]
     │
     ├── WP1: Core Models & Apple Catalog Engine (Sub-Agent 1)
     │        └── XCStrings full parser, Plurals, Devices, Serializer, Test Suite
     │
     ├── WP2: AI Services & Provider Adapter Hub (Sub-Agent 2)
     │        └── OpenAI, Claude, Gemini, Ollama, Keychain & Rate Limiter
     │
     ├── WP3: QA Guardian & Linter Engine (Sub-Agent 3)
     │        └── Placeholder validation, specifier checker, length alerts
     │
     ├── WP4: Raycast Design System & UI Components (Sub-Agent 4)
     │        └── Colors, typography, custom controls, cards, keycaps
     │
     ├── WP5: Main Workspace & Feature Views (Sub-Agent 5)
     │        └── 3-Pane UI, Diff Reviewer, Settings, Command Palette
     │
     └── WP6: System Integration & Review Agent (Sub-Agent 6 - Reviewer)
              └── End-to-end integration, test with sample xcstrings, build verify
```

### Chi tiết nhiệm vụ từng Sub-Agent:

#### Sub-Agent 1: Data Model & Xcode Catalog Engine (WP1)
- **Mục tiêu:** Xây dựng engine đọc/ghi `.xcstrings` đầy đủ và mạnh nhất, không bỏ sót Plural hay Device variation nào.
- **Files phụ trách:**
  - `Models/XCStrings/StringCatalogModels.swift`
  - `Services/Parser/XCStringsParser.swift`
  - `Services/Parser/LegacyStringsParser.swift`
- **Tiêu chí nghiệm thu (Acceptance Criteria):**
  - Đọc được file mẫu `Localizable.xcstrings` lớn từ `/Users/sixblack/code/AITranslate`.
  - Encode ra JSON khớp 100% trật tự khóa của Xcode.
  - Xử lý mượt mà Plural (`zero`, `one`, `two`, `few`, `many`, `other`) và Device variations.

#### Sub-Agent 2: AI Provider Engine & Translation Pipeline (WP2)
- **Mục tiêu:** Tạo hệ thống kết nối AI đa nền tảng, an toàn, hỗ trợ batching và retry.
- **Files phụ trách:**
  - `Services/Storage/KeychainManager.swift`
  - `Services/AIProviders/AIProviderProtocol.swift`
  - `Services/AIProviders/OpenAIProvider.swift`
  - `Services/AIProviders/ClaudeProvider.swift`
  - `Services/AIProviders/GeminiProvider.swift`
  - `Services/AIProviders/OllamaProvider.swift`
  - `Services/Pipeline/TranslationManager.swift`
- **Tiêu chí nghiệm thu:**
  - Quản lý API Key an toàn trong macOS Keychain.
  - Batching 20 items với JSON schema validation.
  - Hỗ trợ đổi qua lại giữa OpenAI, Claude, Gemini, Ollama.

#### Sub-Agent 3: QA Guardian & Safety Linter (WP3)
- **Mục tiêu:** Đảm bảo 100% bản dịch không làm hỏng app khi chạy.
- **Files phụ trách:**
  - `Models/QualityAssurance/QAModels.swift`
  - `Services/QA/QALinterService.swift`
- **Tiêu chí nghiệm thu:**
  - Bắt lỗi specifier: Thiếu `%@`, `%d`, `%1$@`, đổi vị trí hoặc sai dạng.
  - Bắt lỗi HTML tag không đóng hoặc bị dịch.
  - Bắt lỗi vi phạm từ khóa Brand Glossary.
  - Đưa ra danh sách `QAIssue` kèm vị trí và gợi ý tự động sửa (Auto-Fix).

#### Sub-Agent 4: Raycast Design System & Styling (WP4)
- **Mục tiêu:** Xây dựng giao diện đẳng cấp Raycast Dark Mode theo đúng `DESIGN.md`.
- **Files phụ trách:**
  - `DesignSystem/ColorTokens.swift`
  - `DesignSystem/TypographyTokens.swift`
  - `DesignSystem/ComponentStyles.swift`
  - `DesignSystem/VisualComponents/*.swift`
- **Tiêu chí nghiệm thu:**
  - Bảng màu chuẩn Canvas (`#07080a`), Surface (`#0d0d0d`), Hairline (`#242728`), White CTA Pill.
  - Inter/System font tracking, hairline 1px borders, keycap styles cho phím tắt.

#### Sub-Agent 5: UI Views & Workspace Assembly (WP5)
- **Mục tiêu:** Ghép nối các màn hình hoàn chỉnh, mượt mà và trực quan.
- **Files phụ trách:**
  - `Views/MainWorkspace/SidebarView.swift`
  - `Views/MainWorkspace/StringCatalogListView.swift`
  - `Views/MainWorkspace/DetailEditorView.swift`
  - `Views/CommandPalette/QuickCommandPalette.swift`
  - `Views/Settings/SettingsView.swift`
  - `Views/QAInspector/QADashboardView.swift`
- **Tiêu chí nghiệm thu:**
  - Bố cục 3-pane linh hoạt, hỗ trợ kéo thả file `.xcstrings`.
  - Lọc nhanh: Tất cả, Chưa dịch, Có cảnh báo QA, Đã duyệt.
  - Command Palette `Cmd + K` phản hồi tức thì.

#### Sub-Agent 6: System Reviewer & QA Auditor (WP6)
- **Mục tiêu:** Đóng vai trò auditor độc lập để chạy lại toàn bộ chức năng, kiểm thử chất lượng và xác nhận ứng dụng sẵn sàng.
- **Quy trình Review:**
  1. Kiểm tra build tổng thể với `xcodebuild` không phát sinh lỗi hay warning nghiêm trọng.
  2. Tạo bộ test cases kiểm thử:
     - Test parse file mẫu thực tế từ `AITranslate/Localizable.xcstrings`.
     - Test QA Linter với các chuỗi lỗi cố ý (thiếu `%@`, sai token).
     - Test mock AI translation pipeline với batching.
  3. Lập Báo cáo Đánh giá Nghiệm thu (Verification & Audit Report).

---

## 6. Trình tự thực thi của Coordinator

1. **Giai đoạn 1 (Khởi tạo Nền tảng):**
   - Sub-Agent 1 thiết lập Core Model và Catalog Engine.
   - Sub-Agent 4 thiết lập Design Tokens và Raycast Component Library.
2. **Giai đoạn 2 (Dịch vụ & Logic trung tâm):**
   - Sub-Agent 2 triển khai AI Services & Keychain.
   - Sub-Agent 3 triển khai QA Guardian Linter.
3. **Giai đoạn 3 (Giao diện người dùng & Workspace):**
   - Sub-Agent 5 xây dựng UI 3-pane, Command Palette, Settings và gắn kết ViewModels.
4. **Giai đoạn 4 (Kiểm thử, Tích hợp & Đánh giá độc lập):**
   - Sub-Agent 6 chạy toàn bộ quy trình kiểm thử, test với file thực tế, kiểm tra giao diện và nộp báo cáo đánh giá nghiệm thu cho Coordinator.

---
*Tài liệu được bảo chứng bởi Coordinator - Sẵn sàng cho việc phân luồng triển khai.*
