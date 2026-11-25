// 宣传片只在带 TRAILER 标志的构建里编译：日常 Debug 一直有，
// 录制脚本给 Release 加上这个标志（画面要跑满 60fps），而上架的归档不带它，
// 所以这几千行动画和素材不会进商店包。
#if DEBUG || TRAILER
import SwiftUI

// MARK: - 画布

/// 成片画幅，`-ML_trailerAspect 9x16|3x4` 选，默认 9:16。
enum TrailerAspect: String {
    /// 390 × 693⅓ pt → 1080 × 1920（小红书全屏视频，推荐）
    case portrait = "9x16"
    /// 390 × 520 pt → 1080 × 1440（信息流 3:4）
    case classic = "3x4"

    static let current = TrailerAspect(
        rawValue: UserDefaults.standard.string(forKey: "ML_trailerAspect") ?? "9x16"
    ) ?? .portrait
}

/// 固定设计画布：宽 390pt，高按画幅定。所有东西都用 `.position` 摆在这套坐标里，
/// 由 `TrailerView` 整体缩放到屏幕宽度，录屏之后能精确裁出来。
enum TrailerCanvas {
    static let aspect = TrailerAspect.current
    static let isTall = aspect == .portrait
    static let width: CGFloat = 390
    static let height: CGFloat = isTall ? width * 16 / 9 : width * 4 / 3
    /// 底部 18% 留给剪映里加的字幕，不放任何文字和画面主体
    static let captionBand: CGFloat = (height * 0.18).rounded()
    static let contentBottom: CGFloat = height - captionBand
    /// 一个值两种画幅：3:4 用 classic，9:16 用 tall
    static func pick(_ classic: CGFloat, _ tall: CGFloat) -> CGFloat { isTall ? tall : classic }
    static func point(_ x: CGFloat, _ classicY: CGFloat, _ tallY: CGFloat) -> CGPoint {
        CGPoint(x: x, y: isTall ? tallY : classicY)
    }

    /// 成片长度（秒），录制脚本按这个精确裁剪。和 `trailer/voiceover.srt` 最后一条的结束时间一致。
    static let duration: Double = 101.5
    /// 正片开始前先铺这么久的纯黑板：录制脚本靠它找到 t = 0 在录像里的位置，
    /// 同时在底下把整条时间线扫一遍热身（见 `TrailerView.prerollTime`）。
    ///
    /// 模板里用的是白板，但这支片子底色本身就是浅的（奶油紫），白板和正片分不开，
    /// 所以这里换成黑板——整片里再没有第二帧是全黑的。
    static let leadIn: Double = 5.0
}

// MARK: - 计时

/// 纯时间函数：每个场景都是「时刻 t 的函数」，没有状态，所以成片可复现。
enum TrailerMath {
    static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

    /// t 走过 `start ... start + duration` 时从 0 到 1
    static func progress(_ t: Double, _ start: Double, _ duration: Double) -> Double {
        guard duration > 0 else { return t >= start ? 1 : 0 }
        return clamp((t - start) / duration)
    }

    static func mix(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }
    static func mix(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat { a + (b - a) * CGFloat(p) }
    static func mix(_ a: CGPoint, _ b: CGPoint, _ p: Double) -> CGPoint {
        CGPoint(x: mix(a.x, b.x, p), y: mix(a.y, b.y, p))
    }

    static func easeOut(_ p: Double) -> Double {
        let q = 1 - clamp(p)
        return 1 - q * q * q
    }

    static func easeIn(_ p: Double) -> Double {
        let q = clamp(p)
        return q * q * q
    }

    static func easeInOut(_ p: Double) -> Double {
        let q = clamp(p)
        if q < 0.5 { return 4 * q * q * q }
        let r = -2 * q + 2
        return 1 - r * r * r / 2
    }

    /// 阻尼弹簧的阶跃响应（0 → 1，会过冲），参数含义同 `.spring(response:dampingFraction:)`
    static func spring(_ elapsed: Double, response: Double = 0.55, damping: Double = 0.78) -> Double {
        guard elapsed > 0 else { return 0 }
        let omega = 2 * Double.pi / max(response, 0.05)
        let zeta = min(max(damping, 0.05), 0.995)
        let damped = omega * (1 - zeta * zeta).squareRoot()
        let decay = exp(-zeta * omega * elapsed)
        let wave = cos(damped * elapsed) + (zeta * omega / damped) * sin(damped * elapsed)
        return 1 - decay * wave
    }

    static func spring(_ t: Double, at start: Double, response: Double = 0.55, damping: Double = 0.78) -> Double {
        spring(t - start, response: response, damping: damping)
    }

    /// 可复现的伪随机（0 ..< 1）
    static func hash(_ index: Int, _ salt: Int = 0) -> Double {
        let x = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
        return x - x.rounded(.down)
    }
}

// MARK: - 配色

extension Color {
    init(trailerHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// 整支片子的配色跟 App 自己走：奶油紫的底、粉橙的重点色、紫 / 青两个队色。
///
/// 模板那套是深色 + 琥珀，这里没有照搬：PartyRelay 本身是浅色派对风，
/// 3D 那几张也是白桌子浅背景，底色压黑会和素材打架。
enum TrailerStyle {
    static let paper = Color(trailerHex: 0xF6F1FD)
    static let ink = Color(trailerHex: 0x241A3C)
    static let inkSoft = Color(trailerHex: 0x6B5E88)
    static let purple = Color(trailerHex: 0x8B5CF6)
    static let teal = Color(trailerHex: 0x14B8A6)
    static let pink = Color(trailerHex: 0xFF4D8D)
    static let orange = Color(trailerHex: 0xFF9A3C)
    static let red = Color(trailerHex: 0xF04438)
    static let green = Color(trailerHex: 0x19C37D)

    /// 重点文字 / 边框的粉橙渐变，就是 App 主按钮那一套
    static let accent = LinearGradient(
        colors: [pink, Color(trailerHex: 0xFF6F5B), orange],
        startPoint: .leading, endPoint: .trailing
    )
    static let accentDown = LinearGradient(
        colors: [pink, orange], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// 卡片底：白，带一点点紫调
    static let card = LinearGradient(
        colors: [.white, Color(trailerHex: 0xFBF8FF)], startPoint: .top, endPoint: .bottom
    )
    /// 代码卡用深色，和浅底拉开，顺便让代码本身更像代码
    static let codeBack = Color(trailerHex: 0x241C3A)
}

// MARK: - 卡片

/// 白卡：圆角、细描边、柔和的紫色投影。整片的「一张纸」就长这样。
@available(iOS 18.0, *)
struct TrailerCard<Content: View>: View {
    var corner: CGFloat = 22
    var padding: CGFloat = 18
    var glow: Double = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(TrailerStyle.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(TrailerStyle.accent, lineWidth: 2)
                            .opacity(glow)
                    }
                    .shadow(color: TrailerStyle.purple.opacity(0.18), radius: 22, x: 0, y: 12)
            }
    }
}

/// 小胶囊：一句话的标签，底色可换
@available(iOS 18.0, *)
struct TrailerPill: View {
    let text: String
    var tint: Color = TrailerStyle.purple
    var size: CGFloat = 14
    var filled = false

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(filled ? Color.white : tint)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, size * 0.85)
            .padding(.vertical, size * 0.45)
            .background {
                Capsule(style: .continuous)
                    .fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.13)))
            }
    }
}

// MARK: - 景深进出

extension View {
    /// 统一的进出场：`hidden` 0 → 1 会淡出、模糊、缩小并上浮（`scale` 为负则是放大）
    func trailerDepth(_ hidden: Double, scale: CGFloat = 0.1, lift: CGFloat = 0, blur: CGFloat = 10) -> some View {
        let h = CGFloat(TrailerMath.clamp(hidden))
        return self
            .scaleEffect(1 - scale * h)
            .offset(y: lift * h)
            .blur(radius: blur * h)
            .opacity(Double(1 - h))
    }
}

// MARK: - 标题

/// 逐字从模糊里解析出来的两行大标题。第二行吃粉橙渐变。
@available(iOS 18.0, *)
struct TrailerHeadline: View {
    let title: String
    var subtitle: String? = nil
    var titleSize: CGFloat = TrailerCanvas.pick(30, 34)
    var subtitleSize: CGFloat = TrailerCanvas.pick(20, 23)
    let reveal: Double
    var exit: Double = 0

    var body: some View {
        VStack(spacing: 7) {
            Text(verbatim: title)
                .font(.system(size: titleSize, weight: .heavy))
                .foregroundStyle(TrailerStyle.ink)
                .textRenderer(GlyphBlurRenderer(progress: TrailerMath.clamp(reveal * 1.2)))
            if let subtitle, !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .font(.system(size: subtitleSize, weight: .heavy))
                    .foregroundStyle(TrailerStyle.accent)
                    .textRenderer(GlyphBlurRenderer(progress: TrailerMath.clamp(reveal * 1.35 - 0.35)))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.42)
        .multilineTextAlignment(.center)
        .frame(width: 350)
        .shadow(color: Color.white.opacity(0.9), radius: 8)
        .trailerDepth(exit, scale: -0.07, lift: -16, blur: 10)
    }
}

/// 一个字一个字地从模糊 + 下移里落定
@available(iOS 18.0, *)
struct GlyphBlurRenderer: TextRenderer {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let runs = layout.flatMap { $0 }.flatMap { $0 }
        let count = max(runs.count, 1)
        for (index, glyph) in runs.enumerated() {
            // 每个字错开一点点出场；最后一个字也要有完整的 0.42 走完
            let start = Double(index) / Double(count) * 0.58
            let local = TrailerMath.easeOut(TrailerMath.clamp((progress - start) / 0.42))
            var copy = context
            copy.opacity = local
            copy.translateBy(x: 0, y: CGFloat((1 - local) * 14))
            copy.addFilter(.blur(radius: CGFloat((1 - local) * 6)))
            copy.draw(glyph)
        }
    }
}

// MARK: - 底

/// 奶油紫的网格渐变 + 缓慢上浮的小点，底部压一层让字幕带干净。
@available(iOS 18.0, *)
struct TrailerBackdrop: View {
    let t: Double
    /// 光聚在哪儿（画布坐标），跟着当前场景走
    let focus: CGPoint

    var body: some View {
        ZStack {
            TrailerStyle.paper
            MeshGradient(width: 3, height: 3, points: Self.points(t, focus: focus), colors: Self.colors)
                .opacity(0.9)
            RadialGradient(
                colors: [Color.white.opacity(0.75), Color.white.opacity(0)],
                center: UnitPoint(x: focus.x / TrailerCanvas.width, y: focus.y / TrailerCanvas.height),
                startRadius: 0,
                endRadius: TrailerCanvas.pick(250, 330)
            )
            TrailerMotes(t: t)
            LinearGradient(
                colors: [TrailerStyle.paper.opacity(0), TrailerStyle.paper.opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: TrailerCanvas.captionBand + 60)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
        .allowsHitTesting(false)
    }

    private static let colors: [Color] = [
        Color(trailerHex: 0xEADBFF), Color(trailerHex: 0xFFE3EC), Color(trailerHex: 0xDCE8FF),
        Color(trailerHex: 0xF3E9FF), Color(trailerHex: 0xFFF2E2), Color(trailerHex: 0xE3F6F4),
        Color(trailerHex: 0xF6F1FD), Color(trailerHex: 0xF2EBFC), Color(trailerHex: 0xF6F1FD),
    ]

    private static func points(_ t: Double, focus: CGPoint) -> [SIMD2<Float>] {
        let a = 0.085
        let fx = Double(focus.x / TrailerCanvas.width)
        let fy = Double(focus.y / TrailerCanvas.height)
        let topX = 0.5 + a * sin(t * 0.41)
        let leftY = 0.45 + a * cos(t * 0.33 + 1.2)
        let rightY = 0.45 + a * sin(t * 0.37 + 2.4)
        let bottomX = 0.5 + a * cos(t * 0.47 + 0.6)
        let cx = min(max(fx + 0.05 * sin(t * 0.5), 0.2), 0.8)
        let cy = min(max(fy + 0.05 * cos(t * 0.36), 0.2), 0.78)
        return [
            p(0, 0), p(topX, 0), p(1, 0),
            p(0, leftY), p(cx, cy), p(1, rightY),
            p(0, 1), p(bottomX, 1), p(1, 1),
        ]
    }

    private static func p(_ x: Double, _ y: Double) -> SIMD2<Float> {
        SIMD2<Float>(Float(x), Float(y))
    }
}

/// 慢慢往上飘的小圆点，给浅底一点层次
@available(iOS 18.0, *)
private struct TrailerMotes: View {
    let t: Double
    private let count = 30

    var body: some View {
        Canvas { context, size in
            for index in 0..<count {
                let depth = TrailerMath.hash(index, 7)
                let speed = 5 + 14 * depth
                let span = Double(size.height) + 40
                let rawY = TrailerMath.hash(index, 8) * span - t * speed
                let y = rawY - (rawY / span).rounded(.down) * span - 20
                let x = TrailerMath.hash(index, 9) * Double(size.width) + 9 * sin(t * 0.5 + Double(index))
                let r = 1.0 + 2.4 * depth
                let twinkle = 0.5 + 0.5 * sin(t * (1.0 + depth) + Double(index) * 1.7)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.opacity = (0.10 + 0.22 * depth) * twinkle
                let tint = index % 3 == 0 ? TrailerStyle.pink : TrailerStyle.purple
                context.fill(Path(ellipseIn: rect), with: .color(tint))
            }
        }
    }
}
#endif
