#if DEBUG
import SwiftUI

/// 外屏内容没法在模拟器上让系统真的显示出来（没有相机会话、也折不了），
/// 所以给一条旁路：Duo 模拟器的主屏正好就是外屏尺寸，直接把它铺满来看版式。
/// `SIMCTL_CHILD_PREVIEW_COVER=1 xcrun simctl launch booted com.partyrelay.app`
enum CoverPreview {
    static let on = ProcessInfo.processInfo.environment["PREVIEW_COVER"] == "1"
    /// 按指定点数排外屏内容，而不是铺满当前屏幕：`COVER_SIZE=678x466`。
    ///
    /// 真机摆成笔记本姿势时外屏那一面是**横**的（官方模型量出来 112.5×77.4mm，
    /// 长宽比 1.4535，几乎就是 678:466），可模拟器只肯给竖着的 466×678。
    /// 所以拍素材时按横版排一次，再把截图转回来。
    static var size: CGSize? {
        guard let raw = ProcessInfo.processInfo.environment["COVER_SIZE"] else { return nil }
        let parts = raw.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    /// 想直接看闪那一下的样子：COVER_CELEBRATE=1 看答对，COVER_CELEBRATE=skip 看换词
    private static let flashEnv = ProcessInfo.processInfo.environment["COVER_CELEBRATE"]
    static var celebrate: Bool { flashEnv == "1" || flashEnv == "skip" }
    static var skipFlash: Bool { flashEnv == "skip" }
}

/// 把外屏内容铺满当前屏幕，并让计时真的走起来。
struct CoverScreenPreviewHarness: View {
    @ObservedObject private var model = CoverScreenModel.shared
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var celebrateWith: [CoverScreenModel.Scorer] = []

    /// COVER_MODE=drawing 看画板镜像那一面，默认看问号那一面
    private var drawingMode: Bool {
        ProcessInfo.processInfo.environment["COVER_MODE"] == "drawing"
    }

    /// 内屏画板的长宽比。真机 90° 时下半屏那块画板约 1.84，竖屏约 1.07。
    /// 默认给 1.84：这是最扁的情况，也正是以前会被外屏切掉两边的那一种。
    private var canvasAspect: CGFloat {
        guard let raw = ProcessInfo.processInfo.environment["COVER_ASPECT"],
              let value = Double(raw), value > 0 else { return 1.84 }
        return CGFloat(value)
    }

    /// 沿画板四边描一圈。这一圈是「源画板的边界」本身，所以它在外屏上是否完整可见，
    /// 就是「镜像有没有被切」的直接答案——不用靠眼估画面少了多少。
    private func borderStroke(aspect: CGFloat) -> Stroke {
        let halfX = max(aspect, 1) / 2
        let halfY = max(1 / aspect, 1) / 2
        return Stroke(points: [CGPoint(x: -halfX, y: -halfY), CGPoint(x: halfX, y: -halfY),
                               CGPoint(x: halfX, y: halfY), CGPoint(x: -halfX, y: halfY),
                               CGPoint(x: -halfX, y: -halfY)],
                      color: .red, lineWidth: 4)
    }

    private func fire() {
        if CoverPreview.skipFlash { model.flashSkip() } else { model.flashCorrect(celebrateWith) }
    }

    var body: some View {
        content
            .onAppear {
                model.mode = drawingMode ? .drawing : .question
                if drawingMode {
                    model.canvasAspect = canvasAspect
                    // 红框是验「有没有被切」用的，拍素材时不要：COVER_BORDER=0
                    let border = ProcessInfo.processInfo.environment["COVER_BORDER"] != "0"
                    model.syncStrokes(ScreenshotMode.demoStrokes()
                                      + (border ? [borderStroke(aspect: canvasAspect)] : []))
                }
                model.sync(remaining: CoverPreview.celebrate ? 37 : 4, total: 60)
                if CoverPreview.celebrate {
                    // COVER_SCORERS=2 看轮流模式（猜对的 + 表演的各一行），默认看队伍模式那一行
                    let two = ProcessInfo.processInfo.environment["COVER_SCORERS"] == "2"
                    celebrateWith = two
                        ? [.init(emoji: "🦊", name: "小明"), .init(emoji: "🐼", name: "Alan")]
                        : [.init(emoji: "🔥", name: "火焰队")]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { fire() }
                }
            }
            .onReceive(tick) { _ in
                guard !CoverPreview.celebrate else {
                    // 庆祝只亮 850ms，截一张正好撞上的概率很低。预览里每秒重放一次，
                    // 随手截一张就能看到——只影响这条预览旁路，正常玩法还是只闪一下
                    fire()
                    return
                }
                model.sync(remaining: max(0, model.remaining - 1), total: model.total)
            }
    }

    /// 没给 COVER_SIZE 就铺满屏幕；给了就按那个点数排版，再转 90° 塞进竖着的模拟器窗口
    /// （截完用 `sips -r -90` 转回来就是横版外屏）。
    @ViewBuilder private var content: some View {
        if let size = CoverPreview.size {
            // 整层先把安全区让掉再摆内容：不这么做的话，CoverScreenContent 是在「缩进过的」
            // 区域里排的，它自己那层 ignoresSafeArea 转 90° 之后也补不回来，
            // 顶上会留一条白边（答对那一闪的绿色铺不到边）
            ZStack {
                CoverScreenContent()
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(90))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            // 系统状态栏不跟着这一层转，截出来会是躺着的 9:41——拍素材时直接关掉
            .statusBarHidden(true)
        } else {
            CoverScreenContent()
        }
    }
}
#endif
