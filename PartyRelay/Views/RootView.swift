import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared
    @ObservedObject private var hinge = HingeMonitor.shared
    @ObservedObject private var coverCamera = CoverScreenCamera.shared
    @State private var showSettings = false
    @State private var showFoldIntro = false

    /// `CameraCaptureAccessory` 要一个 Binding，而开关的真身在 CoverScreenModel 上。
    ///
    /// ⚠️ **这里故意不 `@ObservedObject` 那个 model。** 它上面挂着 `remaining`、`strokes`、
    /// `liveStroke` 这些高频 `@Published`——计时每秒推一次，画画时每个触摸点推一次。
    /// 一旦在这一层订阅，整棵 `phaseView` 每次都会重建，而 `PlayView` / `DrawView` 的
    /// `Timer.publish(...)` 是 view struct 的存储属性，重建就等于**重新起表**，
    /// 一局 60 秒会被一点点拖长。`HingeMonitor` 那边早就为同一件事留过警告，
    /// 这边是同一个坑的另一半。
    private var coverEnabled: Binding<Bool> {
        Binding(get: { CoverScreenModel.shared.enabled },
                set: { CoverScreenModel.shared.enabled = $0 })
    }


    private func maybeShowFoldIntro() {
        // 扫图时不弹：不然拍到的是教学卡，不是要看的那一页。
        // 这条坑过人——有一轮评审员拿到的 act/draw 两张图全是「Folded mode」。
        // foldintro* 这两个模式反过来，就是专门拍这张卡的
        let shot = ScreenshotMode.mode
        guard shot == nil || shot == "foldintro" || shot == "foldintrodraw" else { return }
        guard hinge.isLaptopPosture, store.phase == .playing,
              // 没做 90° 版面的玩法不弹：那张分工图讲的事情它们一条都不成立
              store.currentGame.hasFoldedLayout,
              !FoldTutorial.hasSeenIntro, !showFoldIntro else { return }
        // 教学盖在正在跑表的那一局上，不停表的话读说明的十几秒是从本队时间里扣的
        store.setPaused(true, for: .foldIntro)
        withAnimation(.easeOut(duration: 0.25)) { showFoldIntro = true }
    }

    private func dismissFoldIntro() {
        FoldTutorial.hasSeenIntro = true
        store.setPaused(false, for: .foldIntro)
        withAnimation(.easeOut(duration: 0.2)) { showFoldIntro = false }
    }

    /// 系统状态栏竖条至少这么宽，才算「有侧边栏」（普通手机竖屏左右安全区是 0）
    private static let sidebarMinWidth: CGFloat = 36

    /// 页面上有暂停键的阶段（启动页、准备页没有）
    private var showsPause: Bool { store.phase != .menu && store.phase != .home }

    /// 折起来了却还横着拿。
    ///
    /// 正常情况下 `OrientationLock` 在折的那一刻就把屏转回竖的了，轮不到这里。
    /// 这是兜底：系统拒掉旋转请求的时候，宁可盖住整页也别渲染一个劈错地方的分屏。
    private func isSideways(_ size: CGSize) -> Bool {
#if DEBUG
        // 模拟器折不了也转不了（App 本来就竖屏独占），想看那层提示：FORCE_SIDEWAYS=1
        if FoldTutorial.debugForceSideways { return true }
#endif
        return hinge.isLaptopPosture && size.width > size.height
    }

    /// 要把手机往哪边转才能回到竖屏：顺时针还是逆时针。
    ///
    /// 两种横屏要转的方向**正好相反**，所以不能写死。
    ///
    /// 这个对应关系是**真机上定的，不是推的**：先推了一版（landscapeLeft→逆时针），
    /// 装到机器上一看是反的。`UIInterfaceOrientation` 的 left/right 和
    /// 「机身顶边指向哪儿」的关系很容易想反，所以这里以实测为准：
    /// 实测 `interface=4`（landscapeRight）时，要**逆时针**转才回得到竖屏。
    ///
    /// 只有这一个方向落在竖屏上——另一边转过去是倒置竖屏，App 根本没声明那个方向。
    private static var rotateClockwise: Bool {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes
        where scene.session.role == .windowApplication {
            switch scene.interfaceOrientation {
            case .landscapeLeft:  return true
            case .landscapeRight: return false
            default: break
            }
        }
        return true
    }

    /// 折着却走到了一个折起来没法玩的玩法（见 OpenToPlayOverlay）
    private var needsFlat: Bool {
        hinge.isLaptopPosture && store.phase == .hallOfFame
    }

    /// 玩到一半被合上了。合上之后 App 跑在外屏上，而那一页印着答案（见 FoldedShutOverlay）
    private var isShut: Bool {
#if DEBUG
        if FoldTutorial.debugForceShut { return true }
#endif
        return hinge.status == .closed && store.phase == .playing
    }

    var body: some View {
#if DEBUG
        if CoverPreview.on {
            CoverScreenPreviewHarness()
        } else {
            mainBody
        }
#else
        mainBody
#endif
    }

    private var mainBody: some View {
        GeometryReader { geo in
            let inset = max(geo.safeAreaInsets.trailing, geo.safeAreaInsets.leading)
            let sidebar = inset >= Self.sidebarMinWidth ? inset : 0
            let onLeft = geo.safeAreaInsets.leading > geo.safeAreaInsets.trailing
            let sideways = isSideways(geo.size)
            phaseView
#if DEBUG
                // 真机 / 模拟器实际给了多大一块地方。这是拿到内屏真实安全区的唯一办法，
                // 见 FoldPreview
                .onAppear {
                    FoldPreview.report(size: geo.size, insets: geo.safeAreaInsets)
                    FoldPreview.reportDevice()
                }
#endif
                .environment(\.pauseSidebarWidth, showsPause ? sidebar : 0)
                // 整块屏的安全区只有在这一层量得到，折痕分屏要靠它才能算出真正的屏幕中线
                .environment(\.screenSafeAreaInsets, geo.safeAreaInsets)
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
                // 铰链状态只能通过挂在视图上的 interaction 拿到，所以这个读取器要一直在层级里。
                // 给 1×1 而不是 0×0：零尺寸视图不一定会被真正加进 UIKit 层级。
                .overlay(alignment: .topLeading) {
                    HingeReader().frame(width: 1, height: 1).allowsHitTesting(false)
                }
                .coverScreen(enabled: coverEnabled)
                // 第一次真的摊成 90°：讲清三块屏各自干嘛。只在玩法页触发，
                // 在菜单上折手机不该弹教学
                // 两个入口都要看：进玩法页时折起来，和已经折着才进玩法页。
                // 只听前一个的话，折着开局的人永远看不到教学
                .onChange(of: hinge.isLaptopPosture) { _, _ in maybeShowFoldIntro() }
                .onChange(of: store.phase) { _, newPhase in
                    maybeShowFoldIntro()
                    ScreenWake.update(for: newPhase)
                }
                .onAppear {
                    maybeShowFoldIntro()
                    ScreenWake.update(for: store.phase)
                }
                .overlay {
                    // 合上优先于一切：这一层的全部意义就是别让答案留在屏上
                    if isShut {
                        FoldedShutOverlay().transition(.opacity)
                    } else if needsFlat {
                        OpenToPlayOverlay().transition(.opacity)
                    } else if sideways {
                        RotateToLaptopOverlay(clockwise: Self.rotateClockwise) {
                            hinge.foldLayoutSuppressed = true
                        }
                        .transition(.opacity)
                    } else if showFoldIntro {
                        // 这张卡讲的就是折痕，自己却骑在折痕上——收进立起来那半屏
                        FoldIntroOverlay(drawing: store.currentGame == .drawGuess,
                                         onDismiss: dismissFoldIntro)
                            
                        .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: sideways)
                .animation(.easeOut(duration: 0.2), value: isShut)
                .animation(.easeOut(duration: 0.2), value: needsFlat)
                // 合着的手机没人能玩，这几秒不该从本队时间里扣
                .onChange(of: isShut) { _, shut in
                    store.setPaused(shut, for: .foldedShut)
                }
                // 权限弹窗是系统盖上来的，App 这边照样在跑表——第一队的时间不该烧在那上面
                .onChange(of: coverCamera.isRequesting) { _, asking in
                    store.setPaused(asking, for: .cameraPrompt)
                }
        }
    }

    private var phaseView: some View {
        Group {
            // 折到 90° 时，只有猜词页和画板页自己劈了两半（它们的下半屏有正经用途）。
            // 其余页面的正文由各自的内容容器（pageFrame / FittingScroll）收进立起来那半屏，
            // 见 FoldedTopHalf——不在这一层做，因为在这儿框住会把页面背景一起裁掉。
            // 名人堂是例外：两队左右对坐同时看一块屏，折起来本来就不该玩，
            // 它自己那套左右分屏不能被塞进半屏里
            switch store.phase {
            case .menu:
                ModeMenuView()
            case .home:
                HomeView(showSettings: $showSettings)
            case .wheel:
                WheelView()
            case .handoff:
                if store.isRotation {
                    RotationHandoffView()
                } else {
                    HandoffView()
                }
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
