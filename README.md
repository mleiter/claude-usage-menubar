# Claude Usage Menu Bar

[![CI](https://github.com/mleiter/claude-usage-menubar/actions/workflows/ci.yml/badge.svg)](https://github.com/mleiter/claude-usage-menubar/actions/workflows/ci.yml)

Schlanke macOS-Menüleisten-App, die den Claude-Plan-Verbrauch live anzeigt
(`5h X% · 7d Y%`). Datenquelle: `GET https://api.anthropic.com/api/oauth/usage`,
OAuth-Token aus dem macOS-Keychain (`Claude Code-credentials`, von Claude Code gepflegt).

> **Inoffiziell — auf eigene Gefahr.** Dieses Projekt steht in keiner Verbindung zu
> Anthropic und wird von Anthropic weder unterstützt noch geprüft. Es nutzt einen
> undokumentierten Endpoint und liest das von Claude Code im Keychain abgelegte
> OAuth-Token. Beides kann sich jederzeit ändern, wodurch die App ohne Vorwarnung
> aufhören kann zu funktionieren. Es werden keine Zugangsdaten gespeichert oder
> übertragen — der Token wird ausschließlich lokal zur Laufzeit gelesen.

## Download

Fertige App unter [Releases](https://github.com/mleiter/claude-usage-menubar/releases):
`ClaudeUsage.zip` herunterladen und der Anleitung unter
[„Auf einem anderen Mac installieren"](#auf-einem-anderen-mac-installieren) folgen.

## Bauen

```bash
./package.sh
open ClaudeUsage.app
```

`package.sh` baut ein **universal** Binary (Apple Silicon + Intel), signiert das
Bundle ad-hoc und legt zusätzlich `ClaudeUsage.zip` zum Verteilen an.

## Auf einem anderen Mac installieren

1. `ClaudeUsage.zip` auf den Ziel-Mac kopieren (AirDrop, USB, Cloud …) und entpacken.
2. `ClaudeUsage.app` nach `/Applications` ziehen (optional, aber üblich).
3. Da die App nicht über einen Apple-Developer-Account notarisiert ist, blockt
   Gatekeeper sie zunächst. Einmalig die Quarantäne entfernen:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ClaudeUsage.app
   ```
   (Alternativ beim ersten Start Rechtsklick auf die App → „Öffnen" → „Öffnen".)
4. App starten. Beim ersten Keychain-Zugriff „Immer erlauben" wählen.

**Voraussetzungen auf dem Ziel-Mac:** macOS 13+ und ein installiertes, eingeloggtes
Claude Code (liefert das Keychain-Token). Ohne Claude-Login zeigt die App
„Kein Claude-Login gefunden" — siehe Abschnitt unten.

> Für eine Verteilung ohne den `xattr`-Schritt bräuchtest du einen
> Apple Developer Account (99 $/Jahr) zum Signieren mit Developer ID + Notarisierung.

## Tests

```bash
swift test
```

## Was es zeigt

- **Menüleiste:** `5h X% · 7d Y%` — Prozent des 5‑Stunden- und des 7‑Tage-Limits.
  Ab ≥80 % orange, ≥95 % rot.
- **Klick-Menü:** beide Limits mit Balken und Reset-Zeit (lokale Zeit), separate
  Opus-/Sonnet-Wochenwerte, Extra-Budget (falls aktiviert), Zeitpunkt der letzten
  Aktualisierung, „Jetzt aktualisieren" (⌘R), „Beim Login starten",
  „Benachrichtigungen", „Beenden" (⌘Q).
- **Benachrichtigungen:** einmalige macOS-Mitteilung, wenn ein Limit die
  80 %- bzw. 95 %-Schwelle überschreitet (im Menü abschaltbar).

## Hinweise

- Benötigt macOS 13+ und ein eingeloggtes Claude Code (für den Keychain-Token).
- Beim ersten Start fragt macOS ggf. einmalig nach Keychain-Zugriff → „Immer erlauben".
- Poll-Intervall: 60 s; bei Fehlern (Netz weg, Rate-Limit) exponentielles
  Backoff bis max. 10 min. Nach dem Ruhezustand wird sofort aktualisiert.
- Bei Fehlern bleibt der zuletzt bekannte Wert sichtbar und wird im Menü
  als veraltet gekennzeichnet.
- Kein Dock-Icon (`LSUIElement`); die App lebt nur in der Menüleiste.

## Credentials auf einem anderen Mac

Die App bündelt keine Zugangsdaten. Sie liest zur Laufzeit das lokale Keychain-Item
`Claude Code-credentials`. Dieses Item ist gerätegebunden (nicht via iCloud
synchronisiert). Auf einem anderen Mac funktioniert die App also nur, wenn dort
Claude Code installiert und eingeloggt ist; andernfalls erscheint
„Kein Claude-Login gefunden".

## Entwicklung

Dieses Projekt wird mit [Claude Code](https://claude.com/claude-code) entwickelt;
alle Änderungen werden vom Maintainer geprüft und getestet. Die AI-Beteiligung
ist in der Commit-History per `Co-Authored-By` ausgewiesen.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
