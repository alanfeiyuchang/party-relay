import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared
    @State private var showSettings = false

    var body: some View {
        Group {
            switch store.phase {
            case .home:
                HomeView(showSettings: $showSettings)
            case .wheel:
                WheelView()
            case .handoff:
                HandoffView()
            case .playing:
                if store.currentGame == .drawGuess {
                    DrawView()
                } else {
                    PlayView()
                }
            case .roundResult:
                RoundResultView()
            case .scoreboard:
                ScoreboardView()
            case .victory:
                VictoryView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.phase)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        // 语言切换 → 整树重建，全部文案立即生效
        .id(langManager.language)
        .environment(\.locale, Locale(identifier: langManager.language.rawValue))
        .onAppear {
            FeedbackManager.shared.isEnabled = store.settings.feedbackOn
            ScreenshotMode.apply(to: store, showSettings: $showSettings)
        }
    }
}
