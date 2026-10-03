# LocalizedTranslate (L10n Studio Pro)

<p align="center">
  <img src="LocalizedTranslate/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" width="128" height="128" alt="LocalizedTranslate Icon" style="border-radius: 24px; box-shadow: 0 12px 30px rgba(0,0,0,0.5);">
</p>

<p align="center">
  <strong>Studio bản địa hóa thế hệ mới cho macOS — Tích hợp sâu vào Xcode String Catalog với trí tuệ nhân tạo (AI)</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=flat-square&logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.10%20%7C%206.0-orange?style=flat-square&logo=swift" alt="Swift 6">
  <img src="https://img.shields.io/badge/UI-Raycast%20Dark%20Canvas-101111?style=flat-square" alt="Dark Canvas">
  <img src="https://img.shields.io/badge/Formats-.xcstrings%20%7C%20.strings%20%7C%20.stringsdict-blue?style=flat-square" alt="Formats">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
</p>

---

## 📖 Giới thiệu (Overview)

**LocalizedTranslate (L10n Studio Pro)** là ứng dụng macOS bản địa hóa tối tân được thiết kế chuyên biệt cho lập trình viên iOS, macOS, watchOS và visionOS. 

Thay vì phải dịch máy thô sơ bằng CLI hay tốn thời gian thao tác thủ công từng chuỗi trong Xcode / Web dịch thuật cồng kềnh, **LocalizedTranslate** mang lại trải nghiệm bản địa hóa Native mượt mà, thông minh và an toàn tuyệt đối với giao diện Dark Canvas lấy cảm hứng từ Raycast.

---

## ✨ Tính năng cốt lõi (Key Features)

- **Đầy đủ định dạng Apple Localization:**
  - Hỗ trợ toàn diện **Xcode 15+ String Catalog (`.xcstrings`)**.
  - Hỗ trợ legacy formats: `.strings`, `.stringsdict`, và JSON.
- **Hỗ trợ biến thể số nhiều & thiết bị (Plurals & Device Variations):**
  - Tự động nhận diện và dịch đúng ngữ pháp quy tắc số nhiều: `zero`, `one`, `two`, `few`, `many`, `other`.
  - Phân tách bản dịch theo từng thiết bị: `Mac`, `iPhone`, `iPad`, `Apple Watch`, `Apple Vision Pro`.
- **Hệ thống AI đa dạng (Multi-Provider AI Engine):**
  - **OpenAI:** GPT-4o, GPT-4o-mini, o3-mini.
  - **Anthropic:** Claude 3.5 Sonnet, Claude 3.7 Sonnet, Claude 3.5 Haiku.
  - **Google Gemini:** Gemini 2.0 Flash, Gemini 1.5 Pro.
  - **DeepSeek:** DeepSeek V3, DeepSeek R1 (Reasoning).
  - **Local LLMs (Ollama / Apple Intelligence):** Dịch 100% offline trên máy, bảo mật mã nguồn doanh nghiệp, chi phí $0.
- **QA Linter & Token Guardian (Chống crash runtime):**
  - Bảo vệ 100% các format specifiers (`%@`, `%d`, `%1$@`, `%2$s`, `%ld`,...).
  - Kiểm tra tính toàn vẹn của thẻ XML/HTML, dấu ký tự đặc biệt, cảnh báo chuỗi quá dài gây tràn UI.
- **Visual Screen Context Awareness:**
  - Kéo thả ảnh chụp màn hình UI trực tiếp vào để AI hiểu vị trí hiển thị của từ ngữ (Button, Header, Menu item), loại bỏ triệt để hiện tượng dịch sai ngữ cảnh.
- **Raycast-grade Native UI & Command Palette:**
  - Giao diện Dark Canvas tinh tế (`#07080a`), hairline borders 1px, typography Inter tinh xảo.
  - Quick Command Palette (`Cmd + K`) giúp tìm kiếm và thao tác bằng bàn phím với tốc độ ánh sáng.
- **Bảo mật chuẩn Apple:**
  - Toàn bộ API Key được mã hóa và lưu trữ an toàn trong **macOS Keychain** cấp phần cứng.
  - App Sandbox an toàn với quyền truy cập file do người dùng cấp.

---

## 🚀 Cài đặt vào `/Applications` và Ký Local (Local Signing)

Để sử dụng ứng dụng ổn định trên macOS như khi cài đặt từ App Store (không bị Gatekeeper chặn, xuất hiện trong Spotlight / Raycast / Launchpad), bạn có thể build và cài đặt với chữ ký local (Ad-Hoc Signing) hoàn toàn miễn phí mà **không cần tài khoản Apple Developer trả phí**.

### Cách 1: Tự động hóa với 1 lệnh duy nhất (Khuyên dùng)

Trong thư mục dự án, chạy lệnh:

```bash
./scripts/install.sh
```

Hoặc qua Makefile:

```bash
make install
```

**Script sẽ tự động thực hiện trọn gói:**
1. Clean và build ứng dụng ở chế độ tối ưu `Release` thông qua `xcodebuild`.
2. Tắt phiên bản app cũ nếu đang chạy.
3. Cài đặt trực tiếp vào thư mục `/Applications/LocalizedTranslate.app`.
4. **Local Signing (Ad-hoc codesign)** kèm các quyền bảo mật Sandbox (`.entitlements`).
5. Gỡ cờ hạn chế `com.apple.quarantine` để macOS Gatekeeper cho phép chạy ngay lập tức.
6. Đăng ký bundle với cơ sở dữ liệu `LaunchServices` của hệ thống macOS.
7. Hỏi và mở ngay app nếu bạn muốn.

---

### Cách 2: Thực hiện thủ công từng bước (Manual Installation)

Nếu muốn tự tay kiểm soát từng bước, bạn có thể thực hiện theo các bước sau trong Terminal:

#### Bước 1: Build bản Release với xcodebuild
```bash
xcodebuild -scheme LocalizedTranslate \
           -configuration Release \
           -derivedDataPath ./DerivedData \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           clean build
```

#### Bước 2: Chép file `.app` vào thư mục `/Applications`
```bash
rm -rf /Applications/LocalizedTranslate.app
cp -R ./DerivedData/Build/Products/Release/LocalizedTranslate.app /Applications/
```

#### Bước 3: Ký số nội bộ (Ad-Hoc Signing kèm Entitlements)
Ký số ad-hoc (`-`) đảm bảo app có đầy đủ danh tính và các quyền sandbox (truy cập mạng để gọi AI API, truy cập file người dùng chọn):
```bash
codesign --force --deep --sign - \
         --entitlements ./LocalizedTranslate/LocalizedTranslate.entitlements \
         /Applications/LocalizedTranslate.app
```

#### Bước 4: Gỡ bỏ thuộc tính Quarantine của Gatekeeper
Loại bỏ cảnh báo "App is damaged or cannot be opened" do hệ thống macOS áp đặt cho các app tự biên dịch:
```bash
xattr -cr /Applications/LocalizedTranslate.app
```

#### Bước 5: Cập nhật LaunchServices và khởi chạy
Đăng ký app với hệ điều hành để xuất hiện ngay trong Spotlight và Raycast:
```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted /Applications/LocalizedTranslate.app

# Mở ứng dụng:
open /Applications/LocalizedTranslate.app
```

---

## 🛠️ Hướng dẫn sử dụng (User Guide)

1. **Khởi chạy ứng dụng:** Mở **LocalizedTranslate** từ Spotlight, Raycast hoặc trong thư mục `/Applications`.
2. **Cấu hình API Key:**
   - Nhấn `Cmd + ,` hoặc bấm biểu tượng bánh răng **Settings**.
   - Nhập API Key của nhà cung cấp bạn muốn (OpenAI, Anthropic, Gemini, DeepSeek, hoặc bật kết nối Ollama local).
   - Chọn Model mặc định và thiết lập prompt ngữ cảnh cho dự án của bạn.
3. **Mở dự án:**
   - Kéo thả file `Localizable.xcstrings` (hoặc `.strings`) vào cửa sổ ứng dụng, hoặc nhấn **Open Catalog**.
4. **Bản địa hóa với AI:**
   - Chọn ngôn ngữ nguồn (Source Language) và ngôn ngữ đích (Target Languages).
   - Chọn các key muốn dịch (hoặc chọn "Translate Untranslated Only").
   - Nhấn **Translate Selection** hoặc **Translate All**.
5. **QA & Lưu thay đổi:**
   - Trình kiểm tra QA Linter sẽ tự động đối chiếu các placeholder (`%@`, `%d`) để đảm bảo không bị lỗi format.
   - Nhấn `Cmd + S` để lưu trực tiếp vào file. Xcode sẽ tự động reload các chuỗi mới ngay lập tức!

---

## ⌨️ Phím tắt tiện ích (Keyboard Shortcuts)

| Phím tắt | Thao tác |
| :--- | :--- |
| `Cmd + O` | Mở file String Catalog (`.xcstrings`) |
| `Cmd + S` | Lưu các thay đổi vào file |
| `Cmd + K` | Mở thanh lệnh nhanh (Command Palette) |
| `Cmd + ,` | Mở cài đặt (Settings & API Keys) |
| `Cmd + Enter` | Bắt đầu dịch các chuỗi đang chọn |
| `Cmd + F` | Tìm kiếm chuỗi trong danh sách |
| `Esc` | Đóng bảng lệnh Command Palette / Bỏ chọn |

---

## 💻 Yêu cầu hệ thống (System Requirements)

- **Hệ điều hành:** macOS 14.0 (Sonoma) hoặc macOS 15.0 (Sequoia) trở lên.
- **Kiến trúc:** Apple Silicon (M1/M2/M3/M4) hoặc Intel Mac 64-bit.
- **Môi trường build (nếu tự compile):** Xcode 15.0+ hoặc Xcode 16.0+, Command Line Tools.

---

## 📂 Cấu trúc mã nguồn (Project Architecture)

```
LocalizedTranslate/
├── LocalizedTranslate/
│   ├── LocalizedTranslateApp.swift       # Entry point ứng dụng SwiftUI
│   ├── ContentView.swift                # Root view điều hướng
│   ├── DesignSystem/
│   │   └── RaycastTheme.swift           # Hệ thống màu sắc & typography Dark Canvas
│   ├── Models/
│   │   └── XCStrings/
│   │       └── StringCatalogModels.swift # Định nghĩa cấu trúc JSON chuẩn của Apple .xcstrings
│   ├── Services/
│   │   ├── AIProviders/
│   │   │   └── AIProviders.swift        # Adapter OpenAI, Claude, Gemini, DeepSeek, Ollama
│   │   ├── Parser/
│   │   │   ├── XCStringsParser.swift    # Bộ parse và serialize .xcstrings an toàn
│   │   │   └── LegacyStringsParser.swift # Xử lý file .strings và .stringsdict
│   │   ├── QA/
│   │   │   └── QALinterService.swift    # Kiểm định an toàn placeholder, format token AST
│   │   └── Storage/
│   │       └── KeychainManager.swift    # Lưu trữ API Key mã hóa phần cứng
│   ├── ViewModels/
│   │   └── WorkspaceViewModel.swift     # Quản lý trạng thái, batch translation, progress
│   └── Views/
│       ├── MainWorkspaceViews.swift     # Giao diện studio chính (Table, Sidebar, Inspector)
│       ├── QuickCommandPalette.swift    # Thanh lệnh Cmd+K phong cách Raycast
│       └── SettingsView.swift           # Cấu hình Providers, Prompts, Glossary
├── scripts/
│   └── install.sh                       # Script 1-click build, local sign & cài vào /Applications
├── Makefile                             # Build & install automation
├── SPECIFICATION.md                     # Tài liệu thiết kế hệ thống chi tiết
└── DESIGN.md                            # Tiêu chuẩn thiết kế Raycast Dark Canvas
```

---

## 📄 Bản quyền (License)

Dự án được phân phối dưới giấy phép [MIT License](LICENSE).
Mọi đóng góp (Pull Request, Issue) đều được hoan nghênh nồng nhiệt!
