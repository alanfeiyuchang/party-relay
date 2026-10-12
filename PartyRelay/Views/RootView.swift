import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared
    @State private var showSettings = false

    /// 系统状态栏竖条至少这么宽，才算「有侧边栏」（普通手机竖屏左右安全区是 0）
    private static let sidebarMinWidth: CGFloat = 36

    /// 页面上有暂停键的阶段（启动页、准备页没有）
    private var showsPause: Bool { store.phase != .menu && store.phase != .home }

    var body: some View {
        GeometryReader { geo in
            let inset = max(geo.safeAreaInsets.trailing, geo.safeAreaInsets.leading)
            let sidebar = inset >= Self.sidebarMinWidth ? inset : 0
            let onLeft = geo.safeAreaInsets.leading > geo.safeAreaInsets.trailing
            phaseView
                .environment(\.pauseSidebarWidth, showsPause ? sidebar : 0)
                .overlay(alignment: onLeft ? .bottomLeading : .bottomTrailing) {
                    // 暂停键放进状态栏那一条的最下面：上面是时间和 Wi-Fi，底下这段原本空着，
                    // 拿手机时拇指也更容易够到
                    if showsPause && sidebar > 0 {
                        HomeExitButton(placement: .sidebar)
                            .environment(\.pauseSidebarWidth, sidebar)
                            .frame(width: sidebar)
                            // 系统把时间和 Wi-Fi 画得比竖条正中略往里 6pt，跟它们对齐
                            .offset(x: onLeft ? -(sidebar - 6) : sidebar - 6, y: -12)
                    }
                }
        }
    }

    private var phaseView: some View {
        Group {
            switch store.phase {
            case .menu:
                ModeMenuView()
            case .home:
                HomeView(showSettings: $showSettings)
            case .wheel:
                WheelView()
            case .handoff:
                if store.isRotation { RotationHandoffView() } else { HandoffView() }
            case .playing:
                switch store.currentGame {
                case .drawGuess:  DrawView()
                case .emojiCode:  EmojiCodeView()
                default:          PlayView()
                }
            case .hallOfFame:
                HallOfFameView()
            case .soloResult:
                SoloResultView()
            case .rotationResult:
                RotationResultView()
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
