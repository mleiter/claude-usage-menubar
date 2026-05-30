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

    private func windowRow(_ label: String, _ window: UsageWindow) -> some View {
        let reset = window.resetsAt.map { " (Reset \(formatReset($0)))" } ?? ""
        return Text("\(label)  \(percent(window.utilization))  \(usageBar(window.utilization))\(reset)")
    }

    private func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private func timeString(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
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
