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
