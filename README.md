# Claude Usage Menu Bar

Schlanke macOS-Menüleisten-App, die den Claude-Plan-Verbrauch live anzeigt
(`5h X% · 7d Y%`). Datenquelle: `GET https://api.anthropic.com/api/oauth/usage`,
OAuth-Token aus dem macOS-Keychain (`Claude Code-credentials`, von Claude Code gepflegt).

> **Inoffiziell — auf eigene Gefahr.** Dieses Projekt steht in keiner Verbindung zu
> Anthropic und wird von Anthropic weder unterstützt noch geprüft. Es nutzt einen
> undokumentierten Endpoint und liest das von Claude Code im Keychain abgelegte
> OAuth-Token. Beides kann sich jederzeit ändern, wodurch die App ohne Vorwarnung
> aufhören kann zu funktionieren. Es werden keine Zugangsdaten gespeichert oder
> übertragen — der Token wird ausschließlich lokal zur Laufzeit gelesen.

## Bauen

```bash
./package.sh
open ClaudeUsage.app
```

## Tests

```bash
swift test
```

## Was es zeigt

- **Menüleiste:** `5h X% · 7d Y%` — Prozent des 5‑Stunden- und des 7‑Tage-Limits.
  Ab ≥80 % orange, ≥95 % rot.
- **Klick-Menü:** beide Limits mit Balken und Reset-Zeit (lokale Zeit), separate
  Opus-/Sonnet-Wochenwerte, Extra-Budget (falls aktiviert), Zeitpunkt der letzten
  Aktualisierung, „Jetzt aktualisieren" (⌘R), „Beim Login starten", „Beenden" (⌘Q).

## Hinweise

- Benötigt macOS 13+ und ein eingeloggtes Claude Code (für den Keychain-Token).
- Beim ersten Start fragt macOS ggf. einmalig nach Keychain-Zugriff → „Immer erlauben".
- Poll-Intervall: 60 s. Bei Rate-Limit (429) bleibt der zuletzt bekannte Wert sichtbar.
- Kein Dock-Icon (`LSUIElement`); die App lebt nur in der Menüleiste.

## Credentials auf einem anderen Mac

Die App bündelt keine Zugangsdaten. Sie liest zur Laufzeit das lokale Keychain-Item
`Claude Code-credentials`. Dieses Item ist gerätegebunden (nicht via iCloud
synchronisiert). Auf einem anderen Mac funktioniert die App also nur, wenn dort
Claude Code installiert und eingeloggt ist; andernfalls erscheint
„Kein Claude-Login gefunden".

## Lizenz

MIT — siehe [LICENSE](LICENSE).
