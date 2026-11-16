import SwiftUI

@main
struct RubricsApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.flushAll() }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}

enum AppTab: Hashable { case grade, rubrics, classes }

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: AppTab = .grade

    var body: some View {
        TabView(selection: $tab) {
            GradingTab(goTo: { tab = $0 })
                .tabItem { Label("Beoordelen", systemImage: "checkmark.circle") }
                .tag(AppTab.grade)
            RubricsTab()
                .tabItem { Label("Rubrics", systemImage: "tablecells") }
                .tag(AppTab.rubrics)
            ClassesTab()
                .tabItem { Label("Klassen", systemImage: "person.3") }
                .tag(AppTab.classes)
        }
        .overlay(alignment: .bottom) {
            if let t = store.toast {
                ToastView(text: t).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toast)
    }
}

/// Opslagstatus rechtsboven.
struct SaveStatusView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Group {
            switch store.saveStatus {
            case .idle: Text("")
            case .saving: Text("Opslaan…")
            case .saved: Text("Opgeslagen")
            case .failed: Text("Opslaan mislukt").foregroundStyle(Theme.danger)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.muted)
    }
}
