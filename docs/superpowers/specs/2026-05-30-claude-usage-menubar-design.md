# Claude Usage Menu Bar — Design

**Datum:** 2026-05-30
**Status:** Genehmigt (Brainstorming)

## Ziel

Eine kleine, schlanke native macOS-Menüleisten-App, die den aktuellen Plan-Verbrauch
des Claude-Accounts live anzeigt — also wie viel des Abo-Limits (5-Stunden- und
Wochenfenster) bereits verbraucht ist, vergleichbar mit `/usage` in Claude Code.

## Datenquelle

- **Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`
- **Header:**
  - `Authorization: Bearer <accessToken>`
  - `anthropic-beta: oauth-2025-04-20`
- **Token-Herkunft:** macOS Keychain, Generic Password mit Service-Name
  `Claude Code-credentials`. Der Wert ist JSON; der Token steht unter
  `claudeAiOauth.accessToken`. Claude Code hält diesen Token aktuell (Refresh),
  daher wird er bei jedem Poll frisch gelesen statt zwischengespeichert.

### Antwortstruktur (real beobachtet)

```json
{
  "five_hour":        { "utilization": 5.0, "resets_at": "2026-05-30T19:10:00+00:00" },
  "seven_day":        { "utilization": 3.0, "resets_at": "2026-06-01T06:00:01+00:00" },
  "seven_day_opus":   null,
  "seven_day_sonnet": { "utilization": 1.0, "resets_at": "2026-06-01T06:00:00+00:00" },
  "extra_usage":      { "is_enabled": true, "monthly_limit": 2000, "used_credits": 0.0,
                        "utilization": null, "currency": "USD", "disabled_reason": null }
}
```

- `utilization` = Prozent des jeweiligen Limits, das bereits verbraucht ist (0–100).
- `resets_at` = ISO-8601 UTC-Zeitpunkt, an dem das Fenster zurückgesetzt wird.
- Opus/Sonnet-Wochenwerte können `null` sein (dann nicht zutreffend / nicht genutzt).
- Weitere Felder (`seven_day_oauth_apps`, `tangelo`, …) werden ignoriert.

## Technologie

- Native **SwiftUI**-App mit `MenuBarExtra` (macOS 13+ Ventura).
- Kein Dock-Icon: `LSUIElement = true` (Agent-App).
- Kein externes Framework; nur Foundation/SwiftUI + `ServiceManagement` (`SMAppService`).

## Architektur

Drei klar getrennte, einzeln testbare Komponenten:

### 1. `KeychainTokenProvider`
- **Aufgabe:** Liefert den aktuellen OAuth-Access-Token.
- **Umsetzung:** Ruft `security find-generic-password -s "Claude Code-credentials" -w`
  auf, parst die JSON-Ausgabe und gibt `claudeAiOauth.accessToken` zurück.
- **Fehler:** Token nicht gefunden / Keychain-Zugriff verweigert → typisierter Fehler.
- **Hinweis:** Beim ersten Zugriff fragt macOS evtl. einmalig nach Keychain-Erlaubnis
  („Immer erlauben" klicken).

### 2. `UsageClient`
- **Aufgabe:** Holt und dekodiert den Verbrauch.
- **Eingabe:** Access-Token. **Ausgabe:** `Usage`-Struct.
- **Fehlerbehandlung:**
  - `401` → `.tokenExpired` („In Claude Code neu einloggen").
  - `429` → `.rateLimited` (letzten bekannten Wert behalten, nicht überschreiben).
  - Netzwerk-/Decoding-Fehler → `.network` / `.decoding`.

### 3. `UsageStore` (`ObservableObject`)
- **Aufgabe:** Zustand für die UI; orchestriert Polling.
- **Verhalten:** Timer pollt alle **60 Sekunden** (plus sofort beim Start und bei
  manuellem Refresh). Hält `Usage`, `lastUpdated`, `lastError`.
- Bei `.rateLimited` bleibt der zuletzt erfolgreiche Wert sichtbar.

## Datenmodell

```swift
struct Window: Decodable { let utilization: Double; let resetsAt: Date? }
struct ExtraUsage: Decodable {
    let isEnabled: Bool; let monthlyLimit: Double
    let usedCredits: Double; let currency: String
}
struct Usage: Decodable {
    let fiveHour: Window
    let sevenDay: Window
    let sevenDayOpus: Window?
    let sevenDaySonnet: Window?
    let extraUsage: ExtraUsage?
}
```

`resets_at` wird mit `ISO8601DateFormatter` (mit Fractional Seconds) geparst.

## UI

### Menüleisten-Titel (immer sichtbar)
- Format: `5h 5% · 7d 3%` (gerundete Ganzzahl-Prozente).
- Farbe: ≥80 % orange, ≥95 % rot, sonst Standard. Maßgeblich ist der höhere der
  beiden angezeigten Werte.
- Bei Fehler/keinen Daten: `⚠︎` als Titel.

### Klick-Menü (Dropdown)
```
Claude Verbrauch
─────────────────────────────
5-Stunden-Limit      5%   ▓░░░░░░░░░  (Reset 21:10)
Woche (7 Tage)       3%   ▓░░░░░░░░░  (Reset So 08:00)
  └ Opus             –
  └ Sonnet           1%
─────────────────────────────
Extra-Budget         0 / 2000 $
Zuletzt aktualisiert  20:42:13
─────────────────────────────
Jetzt aktualisieren        ⌘R
Beim Login starten          ✓
Beenden                    ⌘Q
```
- Balken: Unicode-Blöcke (`▓`/`░`), 10 Segmente, gefüllt nach `utilization`.
- Reset-Zeiten: aus UTC in lokale Zeit umgerechnet, kurzes Format.
- Opus/Sonnet: nur mit Wert anzeigen, sonst „–".
- Extra-Budget: nur wenn `extraUsage.isEnabled == true`.
- „Beim Login starten": Toggle über `SMAppService.mainApp`.

## Fehler- & Randfälle

| Fall | Verhalten |
|------|-----------|
| Token im Keychain fehlt | Titel `⚠︎`, Menü: „Kein Claude-Login gefunden" |
| Keychain-Zugriff verweigert | Menü-Hinweis auf Keychain-Erlaubnis |
| `401` Token abgelaufen | Menü: „In Claude Code neu einloggen" |
| `429` Rate Limit | Letzten Wert behalten, still weiterpollen |
| Offline / Netzwerkfehler | Letzten Wert + „zuletzt aktualisiert"-Zeit zeigen |

## Test-Strategie

- `UsageClient`-Decoding gegen die reale Beispiel-JSON (inkl. `null`-Felder).
- `KeychainTokenProvider`-Parsing gegen Beispiel-Keychain-JSON.
- Titel-Formatierung: Rundung, Farbschwellen (79/80/94/95 %).
- Reset-Zeit-Umrechnung UTC → lokal.

## Nicht im Umfang (YAGNI)

- Kein OAuth-Refresh in der App (Claude Code übernimmt das).
- Keine Historie/Charts, kein Logging-Backend.
- Keine Konfigurations-UI außer „Beim Login starten" (Intervall fest 60 s).
- Keine lokale Token/Kosten-Berechnung aus JSONL (separate, lokale Sicht — bewusst weggelassen).
