// 宣传片只在带 TRAILER 标志的构建里编译：日常 Debug 一直有，
// 录制脚本给 Release 加上这个标志（画面要跑满 60fps），而上架的归档不带它，
// 所以这几千行动画和素材不会进商店包。
#if DEBUG || TRAILER
import SwiftUI

/// 小红书宣传片：一镜到底的动态图形，整支片子在 App 里实时渲染，
/// `-ML_trailer YES` 启动时顶掉正常界面，`scripts/record-trailer.sh` 在模拟器里录下来。
///
/// 只有一个时钟：`t` = 开场黑板放完之后的秒数，取自 `TimelineView(.animation)` 里的墙上时间。
/// 每个场景都是 t 的纯函数，所以同一份代码录多少次都是同一帧。
/// 旁白不画在画面上：`trailer/voiceover.srt` 是规格书，每条字幕对应一段画面，
/// 最后一条的结束时间（101.5s）就是成片长度。
///
/// 版式：固定 390pt 宽的画布，9:16（默认）或 3:4，整体缩放到屏幕宽度，
/// 底部 18% 空着留给剪映里加的字幕。
///
/// 分段（秒）：0 三块屏 · 3.6 这是什么游戏 · 7.4 以前只有一块屏 · 11.5 折起来 ·
/// 16 上半屏 · 21 下半屏 · 25.5 外屏 · 31 一扇窄门 · 35 UISceneAccessory ·
/// 41 两个工厂方法 · 46.5 头文件里的门槛 · 53 isAvailable = false · 58.5 假相机 ·
/// 65 它唯一的用处 · 69.5 代价 · 75 剩下的坑 · 85 fit · 91 呼吁 · 96.5 片尾 · 101.5 结束。
/// `-ML_trailerFrom <秒>` 从中间开播（只给预览和抽查用，录制脚本不传）。
@available(iOS 18.0, *)
struct TrailerView: View {
    @State private var start: Date?

    /// 从第几秒开播（预览用）
    private static let startOffset: Double = {
        let raw = UserDefaults.standard.double(forKey: "ML_trailerFrom")
        return raw > 0 ? raw : 0
    }()

    /// 黑板那几秒里让舞台从头扫到尾，每个场景都真渲染一遍。
    ///
    /// 片子的时钟是墙上时间，所以任何一次首帧卡顿（图片第一次合成、文字第一次排版、
    /// Canvas 第一次画）都不会让画面等人，而是直接跳过去——录出来就是画面比旁白早。
    /// 预解码只解决了图片，这里把剩下的也提前做掉。
    private static func prerollTime(_ t: Double) -> Double {
        let p = min(max(1 + t / TrailerCanvas.leadIn, 0), 1)
        return p * TrailerCanvas.duration
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / TrailerCanvas.width
            ZStack {
                Color.black
                if let start {
                    let origin = start.addingTimeInterval(TrailerCanvas.leadIn - Self.startOffset)
                    TimelineView(.animation) { _ in
                        // 用墙上时间，不用 timeline 给的 date：场景重的时候那个值会迟到半秒
                        let t = Date().timeIntervalSince(origin)
                        ZStack {
                            // t < 0 时在黑板底下把整条时间线快速扫一遍（见 prerollTime）
                            TrailerStage(t: t < 0 ? Self.prerollTime(t) : t)
                                .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
                                .clipped()
                                .scaleEffect(scale)
                                .frame(width: proxy.size.width, height: TrailerCanvas.height * scale)
                            // 开场黑板：录制脚本靠它找到 t = 0 在录像里的位置
                            if t < 0 { Color.black }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // 图都在黑板那 2.5 秒里解好，别在镜头里解码
            TrailerAssets.warmUp()
            if start == nil { start = Date() }
        }
    }
}

/// 所有场景叠在一起，每个只在自己那段时间里挂着
@available(iOS 18.0, *)
private struct TrailerStage: View {
    let t: Double

    var body: some View {
        let cue = max(t, 0)
        ZStack {
            TrailerBackdrop(t: cue, focus: Self.focus(cue))
            Group {
                if cue < 11.7 { TrailerOpenScene(t: cue) }
                if cue >= 11.3 && cue < 31.3 { TrailerFoldScene(t: cue) }
                if cue >= 30.8 && cue < 58.8 { TrailerDoorScene(t: cue) }
            }
            Group {
                if cue >= 58.2 && cue < 75.3 { TrailerCameraScene(t: cue) }
                if cue >= 74.7 && cue < 91.3 { TrailerPitfallScene(t: cue) }
                if cue >= 90.7 { TrailerEndScene(t: min(cue, 120)) }
            }
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
        .environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "zh-Hans"))
        .allowsHitTesting(false)
    }

    /// 底光聚在哪儿：跟着当前这段的主体走，线性插值
    private static let focusKeys: [(time: Double, y: CGFloat)] = [
        (0, TrailerLayout.stageY), (11.5, TrailerLayout.stageY),
        (16, TrailerLayout.stageY - 20), (31, TrailerLayout.stageY),
        (46.5, TrailerLayout.stageY), (58.5, TrailerLayout.stageY),
        (75, TrailerLayout.stageY), (91, TrailerLayout.stageY),
        (96.5, TrailerLayout.stageY - 30), (TrailerCanvas.duration, TrailerLayout.stageY - 30),
    ]

    static func focus(_ t: Double) -> CGPoint {
        let keys = focusKeys
        guard let first = keys.first, let last = keys.last else {
            return CGPoint(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
        }
        var y = last.y
        if t <= first.time {
            y = first.y
        } else if t < last.time {
            for index in 1..<keys.count where t < keys[index].time {
                let a = keys[index - 1]
                let b = keys[index]
                let p = TrailerMath.easeInOut((t - a.time) / (b.time - a.time))
                y = TrailerMath.mix(a.y, b.y, p)
                break
            }
        }
        // 光跟着画面轻轻横摆一点，底不至于太死
        let x = TrailerLayout.centerX + CGFloat(sin(t * 0.21)) * 26
        return CGPoint(x: x, y: y)
    }
}
#endif
