# Claude Usage Menu Bar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine schlanke native macOS-Menüleisten-App, die den Claude-Plan-Verbrauch (5h- und 7-Tage-Limit) live als `5h X% · 7d Y%` anzeigt.

**Architecture:** Swift Package mit zwei Targets — `ClaudeUsageCore` (reine, testbare Logik: Modelle/Decoding, Token-Parsing, Formatierung) und `ClaudeUsage` (ausführbares SwiftUI-`MenuBarExtra`-App-Target: `UsageStore`, Views, App-Entry). Der OAuth-Token wird bei jedem Poll frisch aus dem macOS-Keychain (`Claude Code-credentials`) gelesen; alle 60 s wird `GET https://api.anthropic.com/api/oauth/usage` aufgerufen. Ein `package.sh`-Skript baut daraus ein `.app`-Bundle mit `LSUIElement` (kein Dock-Icon).

**Tech Stack:** Swift 6.2, SwiftUI (`MenuBarExtra`, macOS 13+), Foundation (`URLSession`, `JSONDecoder`), `ServiceManagement` (`SMAppService`), Swift Testing (`import Testing`), SwiftPM.

---

## File Structure

- `Package.swift` — Paketdefinition (Core-Lib + Executable + Testtarget).
- `Sources/ClaudeUsageCore/Models.swift` — `Usage`, `Window`, `ExtraUsage`, `UsageError`.
- `Sources/ClaudeUsageCore/UsageDecoding.swift` — `JSONDecoder.usageDecoder()`.
- `Sources/ClaudeUsageCore/KeychainTokenProvider.swift` — Token aus Keychain lesen + parsen.
- `Sources/ClaudeUsageCore/UsageClient.swift` — Request-Bau + Netzwerk-Fetch.
- `Sources/ClaudeUsageCore/Formatting.swift` — Titel, Level, Balken, Reset-Zeit.
- `Sources/ClaudeUsage/UsageStore.swift` — `ObservableObject`, Polling.
- `Sources/ClaudeUsage/MenuContentView.swift` — Dropdown-Inhalt.
- `Sources/ClaudeUsage/ClaudeUsageApp.swift` — `@main`, `MenuBarExtra`, AppDelegate (Activation Policy + Login-Item).
- `Tests/ClaudeUsageCoreTests/*.swift` — Unit-Tests der Core-Logik.
- `Resources/Info.plist` — Bundle-Metadaten (`LSUIElement`).
- `package.sh` — Release bauen + `.app`-Bundle zusammensetzen.

Begründung: Alles, was deterministisch testbar ist (Decoding, Parsing, Formatierung, Request-Bau), lebt in `ClaudeUsageCore` und wird per `swift test` abgedeckt. Das App-Target enthält nur UI/Polling-Verdrahtung (manuelle Verifikation).

---

### Task 1: Paket-Gerüst

**Files:**
- Create: `Package.swift`
- Create: `Sources/ClaudeUsageCore/Models.swift` (zunächst leerer Platzhalter-Typ)
- Create: `Tests/ClaudeUsageCoreTests/SmokeTests.swift`

- [ ] **Step 1: `Package.swift` schreiben**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ClaudeUsageCore"),
        .executableTarget(
            name: "ClaudeUsage",
            dependencies: ["ClaudeUsageCore"]
        ),
        .testTarget(
            name: "ClaudeUsageCoreTests",
            dependencies: ["ClaudeUsageCore"]
        ),
    ]
)
```

- [ ] **Step 2: Platzhalter-Quelle anlegen (damit das Target kompiliert)**

`Sources/ClaudeUsageCore/Models.swift`:
```swift
import Foundation

public enum ClaudeUsageCore {
    public static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
}
```

- [ ] **Step 3: Smoke-Test schreiben**

`Tests/ClaudeUsageCoreTests/SmokeTests.swift`:
```swift
import Testing
@testable import ClaudeUsageCore

@Test func endpointIsCorrect() {
    #expect(ClaudeUsageCore.endpoint.absoluteString == "https://api.anthropic.com/api/oauth/usage")
}
```

- [ ] **Step 4: Bauen & testen**

Run: `swift test`
Expected: PASS (1 Test grün), Paket kompiliert.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold Swift package with core lib and test target"
```

---

### Task 2: Datenmodell + Decoding

**Files:**
- Modify: `Sources/ClaudeUsageCore/Models.swift`
- Create: `Sources/ClaudeUsageCore/UsageDecoding.swift`
- Create: `Tests/ClaudeUsageCoreTests/DecodingTests.swift`

- [ ] **Step 1: Failing test mit echter API-JSON schreiben**

`Tests/ClaudeUsageCoreTests/DecodingTests.swift`:
```swift
import Foundation
import Testing
@testable import ClaudeUsageCore

private let sampleJSON = """
{
  "five_hour": {"utilization": 5.0, "resets_at": "2026-05-30T19:10:00.132744+00:00"},
  "seven_day": {"utilization": 3.0, "resets_at": "2026-06-01T06:00:01.132772+00:00"},
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": {"utilization": 1.0, "resets_at": "2026-06-01T06:00:00.132784+00:00"},
  "extra_usage": {"is_enabled": true, "monthly_limit": 2000, "used_credits": 0.0,
                  "utilization": null, "currency": "USD", "disabled_reason": null}
}
""".data(using: .utf8)!

@Test func decodesRealResponse() throws {
    let usage = try JSONDecoder.usageDecoder().decode(Usage.self, from: sampleJSON)
    #expect(usage.fiveHour.utilization == 5.0)
    #expect(usage.sevenDay.utilization == 3.0)
    #expect(usage.sevenDayOpus == nil)
    #expect(usage.sevenDaySonnet?.utilization == 1.0)
    #expect(usage.extraUsage?.isEnabled == true)
    #expect(usage.extraUsage?.monthlyLimit == 2000)
    #expect(usage.extraUsage?.currency == "USD")
    #expect(usage.fiveHour.resetsAt != nil)
}

@Test func parsesFractionalResetDate() throws {
    let usage = try JSONDecoder.usageDecoder().decode(Usage.self, from: sampleJSON)
    // 2026-05-30T19:10:00Z == 1780site... assert via interval, tz-unabhängig
    let expected = ISO8601DateFormatter().date(from: "2026-05-30T19:10:00Z")!
    #expect(abs(usage.fiveHour.resetsAt!.timeIntervalSince(expected)) < 1.0)
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `swift test --filter DecodingTests`
Expected: FAIL — `Usage`, `Window`, `ExtraUsage`, `usageDecoder()` existieren noch nicht.

- [ ] **Step 3: Modelle implementieren**

In `Sources/ClaudeUsageCore/Models.swift` ergänzen (unter dem bestehenden `enum`):
```swift
public struct Window: Decodable, Equatable {
    public let utilization: Double
    public let resetsAt: Date?
}

public struct ExtraUsage: Decodable, Equatable {
    public let isEnabled: Bool
    public let monthlyLimit: Double
    public let usedCredits: Double
    public let currency: String
}

public struct Usage: Decodable, Equatable {
    public let fiveHour: Window
    public let sevenDay: Window
    public let sevenDayOpus: Window?
    public let sevenDaySonnet: Window?
    public let extraUsage: ExtraUsage?
}
```

- [ ] **Step 4: Decoder implementieren**

`Sources/ClaudeUsageCore/UsageDecoding.swift`:
```swift
import Foundation

public extension JSONDecoder {
    static func usageDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFractional.date(from: string) { return date }
            if let date = plain.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return decoder
    }
}
```

- [ ] **Step 5: Tests ausführen**

Run: `swift test --filter DecodingTests`
Expected: PASS (beide Tests grün).

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeUsageCore Tests/ClaudeUsageCoreTests/DecodingTests.swift
git commit -m "feat: add usage model and JSON decoding"
```

---

### Task 3: Token-Parsing aus Keychain-JSON

**Files:**
- Create: `Sources/ClaudeUsageCore/KeychainTokenProvider.swift`
- Create: `Tests/ClaudeUsageCoreTests/TokenParsingTests.swift`

- [ ] **Step 1: Failing test schreiben**

`Tests/ClaudeUsageCoreTests/TokenParsingTests.swift`:
```swift
import Foundation
import Testing
@testable import ClaudeUsageCore

@Test func parsesAccessTokenFromKeychainJSON() throws {
    let data = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-TEST","refreshToken":"x"}}"#
        .data(using: .utf8)!
    let token = try KeychainTokenProvider.parseToken(from: data)
    #expect(token == "sk-ant-oat01-TEST")
}

@Test func throwsNoTokenWhenMissing() {
    let data = #"{"somethingElse":{}}"#.data(using: .utf8)!
    #expect(throws: UsageError.noToken) {
        try KeychainTokenProvider.parseToken(from: data)
    }
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `swift test --filter TokenParsingTests`
Expected: FAIL — `KeychainTokenProvider` und `UsageError` existieren noch nicht.

- [ ] **Step 3: `UsageError` ergänzen**

In `Sources/ClaudeUsageCore/Models.swift` ergänzen:
```swift
public enum UsageError: Error, Equatable {
    case noToken
    case keychainDenied
    case tokenExpired
    case rateLimited
    case network(String)
    case decoding
}
```

- [ ] **Step 4: `KeychainTokenProvider` implementieren**

`Sources/ClaudeUsageCore/KeychainTokenProvider.swift`:
```swift
import Foundation

public struct KeychainTokenProvider {
    public init() {}

    private struct Credentials: Decodable {
        struct OAuth: Decodable { let accessToken: String }
        let claudeAiOauth: OAuth
    }

    /// Reine, testbare JSON-Parsing-Funktion.
    public static func parseToken(from data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let creds = try? decoder.decode(Credentials.self, from: data) else {
            throw UsageError.noToken
        }
        return creds.claudeAiOauth.accessToken
    }

    /// Liest den Token via `security`-CLI aus dem Login-Keychain.
    public func currentToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            throw UsageError.keychainDenied
        }
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0, !data.isEmpty else {
            throw UsageError.noToken
        }
        return try Self.parseToken(from: data)
    }
}
```

- [ ] **Step 5: Tests ausführen**

Run: `swift test --filter TokenParsingTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeUsageCore Tests/ClaudeUsageCoreTests/TokenParsingTests.swift
git commit -m "feat: read and parse OAuth token from keychain"
```

---

### Task 4: Titel-Formatierung + Warn-Level

**Files:**
- Create: `Sources/ClaudeUsageCore/Formatting.swift`
- Create: `Tests/ClaudeUsageCoreTests/FormattingTests.swift`

- [ ] **Step 1: Failing tests schreiben**

`Tests/ClaudeUsageCoreTests/FormattingTests.swift`:
```swift
import Foundation
import Testing
@testable import ClaudeUsageCore

@Test func formatsTitleWithRoundedPercents() {
    #expect(formatTitle(fiveHour: 5.0, sevenDay: 3.0) == "5h 5% · 7d 3%")
    #expect(formatTitle(fiveHour: 5.6, sevenDay: 0.0) == "5h 6% · 7d 0%")
}

@Test func computesUsageLevelThresholds() {
    #expect(usageLevel(79) == .normal)
    #expect(usageLevel(80) == .warning)
    #expect(usageLevel(94) == .warning)
    #expect(usageLevel(95) == .critical)
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `swift test --filter FormattingTests`
Expected: FAIL — `formatTitle`, `usageLevel`, `UsageLevel` fehlen.

- [ ] **Step 3: Implementieren**

`Sources/ClaudeUsageCore/Formatting.swift`:
```swift
import Foundation

public enum UsageLevel: Equatable {
    case normal, warning, critical
}

public func usageLevel(_ maxUtilization: Double) -> UsageLevel {
    if maxUtilization >= 95 { return .critical }
    if maxUtilization >= 80 { return .warning }
    return .normal
}

public func formatTitle(fiveHour: Double, sevenDay: Double) -> String {
    "5h \(Int(fiveHour.rounded()))% · 7d \(Int(sevenDay.rounded()))%"
}
```

- [ ] **Step 4: Tests ausführen**

Run: `swift test --filter FormattingTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeUsageCore/Formatting.swift Tests/ClaudeUsageCoreTests/FormattingTests.swift
git commit -m "feat: add menu bar title formatting and warn levels"
```

---

### Task 5: Verbrauchs-Balken

**Files:**
- Modify: `Sources/ClaudeUsageCore/Formatting.swift`
- Create: `Tests/ClaudeUsageCoreTests/UsageBarTests.swift`

- [ ] **Step 1: Failing tests schreiben**

`Tests/ClaudeUsageCoreTests/UsageBarTests.swift`:
```swift
import Testing
@testable import ClaudeUsageCore

@Test func barIsEmptyAtZero() {
    #expect(usageBar(0) == "░░░░░░░░░░")
}

@Test func barShowsAtLeastOneSegmentWhenNonZero() {
    #expect(usageBar(3) == "▓░░░░░░░░░")
    #expect(usageBar(5) == "▓░░░░░░░░░")
}

@Test func barFillsProportionally() {
    #expect(usageBar(50) == "▓▓▓▓▓░░░░░")
    #expect(usageBar(100) == "▓▓▓▓▓▓▓▓▓▓")
}

@Test func barClampsAboveHundred() {
    #expect(usageBar(150) == "▓▓▓▓▓▓▓▓▓▓")
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `swift test --filter UsageBarTests`
Expected: FAIL — `usageBar` fehlt.

- [ ] **Step 3: Implementieren**

In `Sources/ClaudeUsageCore/Formatting.swift` ergänzen:
```swift
public func usageBar(_ utilization: Double, segments: Int = 10) -> String {
    let clamped = max(0, min(100, utilization))
    var filled = Int((clamped / 100 * Double(segments)).rounded())
    if clamped > 0 { filled = max(1, filled) }
    filled = min(segments, filled)
    return String(repeating: "▓", count: filled)
         + String(repeating: "░", count: segments - filled)
}
```

- [ ] **Step 4: Tests ausführen**

Run: `swift test --filter UsageBarTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeUsageCore/Formatting.swift Tests/ClaudeUsageCoreTests/UsageBarTests.swift
git commit -m "feat: add unicode usage bar rendering"
```

---

### Task 6: Reset-Zeit-Formatierung (UTC → lokal)

**Files:**
- Modify: `Sources/ClaudeUsageCore/Formatting.swift`
- Create: `Tests/ClaudeUsageCoreTests/ResetTimeTests.swift`

- [ ] **Step 1: Failing tests schreiben**

`Tests/ClaudeUsageCoreTests/ResetTimeTests.swift`:
```swift
import Foundation
import Testing
@testable import ClaudeUsageCore

private let resetDate = ISO8601DateFormatter().date(from: "2026-05-30T19:10:00Z")!

@Test func formatsResetInUTC() {
    let s = formatReset(resetDate, timeZone: TimeZone(identifier: "UTC")!)
    #expect(s.contains("19:10"))
}

@Test func formatsResetInLocalOffset() {
    let s = formatReset(resetDate, timeZone: TimeZone(identifier: "Europe/Berlin")!)
    #expect(s.contains("21:10")) // UTC+2 im Mai
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `swift test --filter ResetTimeTests`
Expected: FAIL — `formatReset` fehlt.

- [ ] **Step 3: Implementieren**

In `Sources/ClaudeUsageCore/Formatting.swift` ergänzen:
```swift
public func formatReset(
    _ date: Date,
    timeZone: TimeZone = .current,
    locale: Locale = Locale(identifier: "de_DE")
) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateFormat = "EE HH:mm"
    return formatter.string(from: date)
}
```

- [ ] **Step 4: Tests ausführen**

Run: `swift test --filter ResetTimeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeUsageCore/Formatting.swift Tests/ClaudeUsageCoreTests/ResetTimeTests.swift
git commit -m "feat: add reset-time formatting with timezone conversion"
```

---

### Task 7: UsageClient (Request-Bau + Fetch)

**Files:**
- Create: `Sources/ClaudeUsageCore/UsageClient.swift`
- Create: `Tests/ClaudeUsageCoreTests/UsageClientTests.swift`

- [ ] **Step 1: Failing test für Request-Bau schreiben**

`Tests/ClaudeUsageCoreTests/UsageClientTests.swift`:
```swift
import Foundation
import Testing
@testable import ClaudeUsageCore

@Test func buildsAuthorizedRequest() {
    let request = UsageClient.makeRequest(token: "sk-ant-oat01-TEST")
    #expect(request.url == ClaudeUsageCore.endpoint)
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-ant-oat01-TEST")
    #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
}

@Test func mapsStatusCodesToErrors() {
    #expect(UsageClient.error(forStatus: 401) == .tokenExpired)
    #expect(UsageClient.error(forStatus: 429) == .rateLimited)
    #expect(UsageClient.error(forStatus: 500) == .network("HTTP 500"))
    #expect(UsageClient.error(forStatus: 200) == nil)
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `swift test --filter UsageClientTests`
Expected: FAIL — `UsageClient` fehlt.

- [ ] **Step 3: Implementieren**

`Sources/ClaudeUsageCore/UsageClient.swift`:
```swift
import Foundation

public struct UsageClient {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public static func makeRequest(token: String) -> URLRequest {
        var request = URLRequest(url: ClaudeUsageCore.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return request
    }

    /// Liefert nil bei Erfolg (2xx), sonst den passenden Fehler.
    public static func error(forStatus status: Int) -> UsageError? {
        switch status {
        case 200...299: return nil
        case 401:       return .tokenExpired
        case 429:       return .rateLimited
        default:        return .network("HTTP \(status)")
        }
    }

    public func fetch(token: String) async throws -> Usage {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: Self.makeRequest(token: token))
        } catch {
            throw UsageError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let error = Self.error(forStatus: status) { throw error }
        do {
            return try JSONDecoder.usageDecoder().decode(Usage.self, from: data)
        } catch {
            throw UsageError.decoding
        }
    }
}
```

- [ ] **Step 4: Tests ausführen**

Run: `swift test --filter UsageClientTests`
Expected: PASS.

- [ ] **Step 5: Gesamte Core-Suite ausführen**

Run: `swift test`
Expected: Alle Tests grün.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeUsageCore/UsageClient.swift Tests/ClaudeUsageCoreTests/UsageClientTests.swift
git commit -m "feat: add usage API client with status-to-error mapping"
```

---

### Task 8: UsageStore (Polling-Zustand)

**Files:**
- Create: `Sources/ClaudeUsage/UsageStore.swift`

*Hinweis:* App-Target-UI/Verdrahtung; manuelle Verifikation (kein Unit-Test, da Timer/Netzwerk).

- [ ] **Step 1: `UsageStore` implementieren**

`Sources/ClaudeUsage/UsageStore.swift`:
```swift
import Foundation
import SwiftUI
import ClaudeUsageCore

@MainActor
final class UsageStore: ObservableObject {
    @Published var usage: Usage?
    @Published var lastUpdated: Date?
    @Published var lastError: UsageError?

    private let client = UsageClient()
    private let tokenProvider = KeychainTokenProvider()
    private var timer: Timer?
    private let interval: TimeInterval = 60

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        Task { @MainActor in
            do {
                let token = try tokenProvider.currentToken()
                let usage = try await client.fetch(token: token)
                self.usage = usage
                self.lastUpdated = Date()
                self.lastError = nil
            } catch let error as UsageError {
                // Rate-Limit: letzten Wert behalten, Fehler nur intern markieren.
                self.lastError = error
            } catch {
                self.lastError = .network(error.localizedDescription)
            }
        }
    }

    /// Titel für die Menüleiste.
    var title: String {
        guard let usage else { return "⚠︎" }
        return formatTitle(
            fiveHour: usage.fiveHour.utilization,
            sevenDay: usage.sevenDay.utilization)
    }

    var level: UsageLevel {
        guard let usage else { return .normal }
        return usageLevel(max(usage.fiveHour.utilization, usage.sevenDay.utilization))
    }
}
```

- [ ] **Step 2: Build prüfen (kompiliert das App-Target?)**

Run: `swift build`
Expected: Erfolgreich kompiliert (noch ohne `@main` Konflikt — App-Entry kommt in Task 10; bis dahin enthält das Target nur diese Datei und baut als Bibliothekscode).
Falls `swift build` einen fehlenden `@main`-Entrypoint bemängelt: ignorieren bis Task 10, oder Tasks 8–10 zusammen committen. (Empfohlen: erst nach Task 10 `swift build` final prüfen.)

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeUsage/UsageStore.swift
git commit -m "feat: add UsageStore with 60s polling"
```

---

### Task 9: Dropdown-Inhalt (MenuContentView)

**Files:**
- Create: `Sources/ClaudeUsage/MenuContentView.swift`

- [ ] **Step 1: View implementieren**

`Sources/ClaudeUsage/MenuContentView.swift`:
```swift
import SwiftUI
import ClaudeUsageCore

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    let toggleLoginItem: () -> Void
    @Binding var launchAtLogin: Bool

    var body: some View {
        if let usage = store.usage {
            windowRow("5-Stunden-Limit", usage.fiveHour)
            windowRow("Woche (7 Tage)", usage.sevenDay)
            if let opus = usage.sevenDayOpus {
                Text("  └ Opus  \(percent(opus.utilization))")
            } else {
                Text("  └ Opus  –")
            }
            if let sonnet = usage.sevenDaySonnet {
                Text("  └ Sonnet  \(percent(sonnet.utilization))")
            }
            if let extra = usage.extraUsage, extra.isEnabled {
                Divider()
                Text("Extra-Budget  \(Int(extra.usedCredits)) / \(Int(extra.monthlyLimit)) \(extra.currency)")
            }
            Divider()
            if let updated = store.lastUpdated {
                Text("Zuletzt aktualisiert  \(timeString(updated))")
            }
        } else {
            Text(errorMessage)
        }

        Divider()
        Button("Jetzt aktualisieren") { store.refresh() }
            .keyboardShortcut("r")
        Button(launchAtLogin ? "Beim Login starten ✓" : "Beim Login starten") {
            toggleLoginItem()
        }
        Button("Beenden") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func windowRow(_ label: String, _ window: Window) -> some View {
        let reset = window.resetsAt.map { " (Reset \(formatReset($0)))" } ?? ""
        return Text("\(label)  \(percent(window.utilization))  \(usageBar(window.utilization))\(reset)")
    }

    private func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private var errorMessage: String {
        switch store.lastError {
        case .noToken:        return "Kein Claude-Login gefunden"
        case .keychainDenied: return "Keychain-Zugriff verweigert"
        case .tokenExpired:   return "In Claude Code neu einloggen"
        default:              return "Lade …"
        }
    }
}
```

- [ ] **Step 2: Commit** (Build-Verifikation erfolgt nach Task 10)

```bash
git add Sources/ClaudeUsage/MenuContentView.swift
git commit -m "feat: add dropdown menu content view"
```

---

### Task 10: App-Entry, MenuBarExtra, AppDelegate

**Files:**
- Create: `Sources/ClaudeUsage/ClaudeUsageApp.swift`

- [ ] **Step 1: App-Entry implementieren**

`Sources/ClaudeUsage/ClaudeUsageApp.swift`:
```swift
import SwiftUI
import ServiceManagement
import ClaudeUsageCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kein Dock-Icon, auch wenn als nacktes Binary gestartet.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = UsageStore()
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                store: store,
                toggleLoginItem: toggleLoginItem,
                launchAtLogin: $launchAtLogin
            )
        } label: {
            Text(store.title)
                .foregroundStyle(color(for: store.level))
                .onAppear { store.start() }
        }
        .menuBarExtraStyle(.menu)
    }

    private func color(for level: UsageLevel) -> Color {
        switch level {
        case .normal:   return .primary
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    private func toggleLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
                launchAtLogin = false
            } else {
                try SMAppService.mainApp.register()
                launchAtLogin = true
            }
        } catch {
            // Im Dev-Modus (nacktes Binary) nicht unterstützt — still ignorieren.
        }
    }
}
```

- [ ] **Step 2: Vollständigen Build prüfen**

Run: `swift build`
Expected: Erfolgreich, ausführbares `ClaudeUsage`-Target.

- [ ] **Step 3: Core-Tests erneut prüfen (nichts gebrochen)**

Run: `swift test`
Expected: Alle Tests grün.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeUsage/ClaudeUsageApp.swift
git commit -m "feat: add app entry with MenuBarExtra and login-item toggle"
```

---

### Task 11: `.app`-Bundle-Packaging

**Files:**
- Create: `Resources/Info.plist`
- Create: `package.sh`

- [ ] **Step 1: `Info.plist` schreiben**

`Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ClaudeUsage</string>
    <key>CFBundleDisplayName</key>     <string>Claude Usage</string>
    <key>CFBundleIdentifier</key>      <string>com.markusleiter.ClaudeUsage</string>
    <key>CFBundleExecutable</key>      <string>ClaudeUsage</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
```

- [ ] **Step 2: `package.sh` schreiben**

`package.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="ClaudeUsage.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/ClaudeUsage" "$APP/Contents/MacOS/ClaudeUsage"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

echo "Gebaut: $APP"
echo "Starten mit: open $APP"
```

- [ ] **Step 3: Ausführbar machen & bauen**

Run:
```bash
chmod +x package.sh && ./package.sh
```
Expected: `ClaudeUsage.app` entsteht, Ausgabe „Gebaut: ClaudeUsage.app".

- [ ] **Step 4: Commit**

```bash
git add Resources/Info.plist package.sh
git commit -m "build: add app bundle packaging script and Info.plist"
```

---

### Task 12: Manuelle Verifikation & README

**Files:**
- Create: `README.md`

- [ ] **Step 1: App starten und beobachten**

Run:
```bash
open ClaudeUsage.app
```
Erwartet:
- In der Menüleiste erscheint `5h X% · 7d Y%` (X/Y ≈ aktuelle Werte).
- Beim ersten Start evtl. einmalig Keychain-Erlaubnisdialog → „Immer erlauben".
- Klick öffnet das Dropdown mit beiden Limits, Balken, Reset-Zeiten, „Zuletzt aktualisiert".
- „Jetzt aktualisieren" (⌘R) aktualisiert die Werte.
- „Beenden" (⌘Q) schließt die App; kein Dock-Icon vorhanden.

Querverifikation: `claude` öffnen und `/usage` vergleichen — Prozente sollten übereinstimmen.

- [ ] **Step 2: README schreiben**

`README.md`:
```markdown
# Claude Usage Menu Bar

Schlanke macOS-Menüleisten-App, die den Claude-Plan-Verbrauch live anzeigt
(`5h X% · 7d Y%`). Datenquelle: `GET https://api.anthropic.com/api/oauth/usage`,
OAuth-Token aus dem macOS-Keychain (`Claude Code-credentials`, von Claude Code gepflegt).

## Bauen
```bash
./package.sh
open ClaudeUsage.app
```

## Tests
```bash
swift test
```

## Hinweise
- Benötigt macOS 13+ und ein eingeloggtes Claude Code (für den Keychain-Token).
- Beim ersten Start ggf. Keychain-Zugriff erlauben.
- Poll-Intervall: 60 s. „Beim Login starten" über das Menü aktivierbar.
```

- [ ] **Step 3: Finaler Check**

Run: `swift test`
Expected: Alle Tests grün.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add README with build and usage instructions"
```

---

## Self-Review-Notiz

- **Spec-Abdeckung:** Datenquelle/Endpoint (Task 7), Keychain-Token (Task 3), Modell+Decoding inkl. `null`-Felder (Task 2), Titel `5h·7d` + Farben (Task 4/10), Balken (Task 5), Reset-Zeit UTC→lokal (Task 6), Dropdown inkl. Opus/Sonnet/Extra/Login-Item (Task 9/10), Fehlerfälle 401/429/offline (Task 7 + UsageStore Task 8), `.app`/`LSUIElement`/Autostart (Task 10/11). Alle Spec-Abschnitte abgedeckt.
- **Typkonsistenz:** `Usage`/`Window`/`ExtraUsage`/`UsageError`, `formatTitle`, `usageLevel`, `usageBar`, `formatReset`, `UsageClient.makeRequest/error/fetch`, `KeychainTokenProvider.parseToken/currentToken` durchgehend gleich benannt zwischen Definition und Verwendung.
- **Build-Hinweis:** `swift build` validiert das App-Target final erst nach Task 10 (App-Entry). Tasks 8–9 committen UI-Code, dessen Vollbuild in Task 10 grün wird.
