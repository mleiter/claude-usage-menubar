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
