# Moazan Traders — Project & Development History

- **Project Name:** `moazan_traders` (`MoazanTradersApp`, version `1.0.0+1`)
- **Project Path:** `C:\Users\Haseeb\.gemini\antigravity\scratch\moazan_traders`
- **Firebase Project:** `moazan-traders-kamoke` (Android, iOS & Web configured in `firebase.json`)
- **Live Hosting URL:** https://moazan-traders-kamoke.web.app
- **Android Release APK:** `APP/Moazan-Traders.apk` (`56,652,135` bytes, built `2026-11-18 16:33`)
- **Full Raw Chat Transcript:** [CHAT_HISTORY.md](./CHAT_HISTORY.md)

---

## 1. Git Commit History

| Commit | Date (`+0500`) | Summary |
| :--- | :--- | :--- |
| `d7fd1db` | `2026-11-17 17:51:11` | Initial commit: Moazan Traders Kamoke Digital Khata (Flutter + Firebase) — 73 pre-loaded dealers, ledger repository, dealers/recent/reports/data tabs, forms, and tests |
| `ff03c78` | `2026-11-17 18:05:46` | Use Moazan Traders logo for web shortcut icons and PWA manifest |
| `03299da` | `2026-11-17 18:15:28` | Add 1-tap PWA Install App / Shortcut button for web |
| `5f00b6b` | `2026-11-17 18:25:04` | Prevent duplicate dealers and auto-merge existing duplicates |
| `753ea40` | `2026-11-17 18:36:52` | Add Total footer row at bottom of dealer khata table |
| `e212034` | `2026-11-17 19:06:00` | Add All Dealers Balance PDF report button and generator |
| `4aae4fc` | `2026-11-17 19:13:42` | Fix PDF button on mobile web with in-app PdfPreview and direct download |

---

## 2. Post-Commit Updates (Current Working Tree, `2026-11-17` – `2026-11-18`)

These changes are present in the working directory (`git status`) after `4aae4fc`:

### Authentication & Session Persistence
- Added Firestore-backed login (`lib/services/auth_service.dart`, `lib/screens/login_screen.dart`, `lib/widgets/change_credentials_dialog.dart`, updated `firestore.rules`).
- Added web `window.localStorage` session storage (`lib/utils/session_storage_web.dart`) and mobile/desktop fallback (`lib/utils/session_storage_stub.dart`) to resolve the Web `MissingPluginException` issue.

### Offline Persistence, Data Management & UI Updates
- Enabled Cloud Firestore offline persistence with `CACHE_SIZE_UNLIMITED` in `lib/main.dart`.
- Updated `lib/models/ledger_entry.dart`, `lib/services/ledger_repository.dart`, `lib/screens/home_screen.dart`, `lib/screens/dealer_detail_screen.dart`, `lib/screens/reports_tab.dart`, `lib/screens/data_tab.dart`, and `lib/utils/pdf_report_service.dart` (including Credit/Debit terminology cleanup, direct PDF downloads, date/description visibility, and data export/import/reset updates).
- Updated dependencies in `pubspec.yaml` / `pubspec.lock` (`shared_preferences`, `crypto`) and tests in `test/widget_test.dart`.

### Android Release Build
- Updated `android/gradle.properties` and generated the Android Release APK at `APP/Moazan-Traders.apk` (`2026-11-18`).

---

## 3. Chat History Archive
All detailed user/assistant conversations from `2026-11-17` through `2026-11-19` are preserved in [CHAT_HISTORY.md](./CHAT_HISTORY.md).
