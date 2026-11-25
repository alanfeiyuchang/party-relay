// 宣传片只在带 TRAILER 标志的构建里编译：日常 Debug 一直有，
// 录制脚本给 Release 加上这个标志（画面要跑满 60fps），而上架的归档不带它，
// 所以这几千行动画和素材不会进商店包。
#if DEBUG || TRAILER
import SwiftUI

private typealias M = TrailerMath
private typealias S = TrailerStyle

/// 多个场景共用的几个位置
enum TrailerLayout {
    static let centerX: CGFloat = TrailerCanvas.width / 2
    /// 标题那一块的中心
    static let headlineY: CGFloat = TrailerCanvas.pick(58, 104)
    /// 画面主体（卡片、代码块）的中心
    static let stageY: CGFloat = TrailerCanvas.pick(255, 340)
    /// 3D 那几张铺满画面时的中心和尺寸：Blender 出的是 9:16，缩在卡片里会被裁得很怪，
    /// 不如直接铺满，标题压在上面
    static let bleedSize = CGSize(width: TrailerCanvas.width,
                                  height: TrailerCanvas.pick(430, 600))
    static let bleedY: CGFloat = TrailerCanvas.pick(248, 318)
    /// 讲三块屏时 3D 那张放小一点，下面要留给实拍小图
    static let shotSize = CGSize(width: 330, height: TrailerCanvas.pick(220, 296))
    static let shotY: CGFloat = TrailerCanvas.pick(200, 272)
    /// 主体下面那排胶囊
    static let pillY: CGFloat = TrailerCanvas.pick(400, 532)
}

// MARK: - 0–11.6s 开场：三块屏 → 这是什么游戏 → 以前怎么玩

@available(iOS 18.0, *)
struct TrailerOpenScene: View {
    let t: Double

    var body: some View {
        ZStack {
            if t < 4.5 { hero }
            if t >= 3.3 && t < 7.9 { game }
            if t >= 7.0 { old }
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
    }

    /// 0–3.6 前三秒直接给结果：折成 90° 的手机摆在两个人中间
    private var hero: some View {
        let exit = M.easeIn(M.progress(t, 3.45, 0.6))
        return ZStack {
            BleedShot(name: .wide3D, zoom: M.progress(t, 0, 4.4), zoomFrom: 1.14, zoomTo: 1.0)
                .trailerDepth(exit, scale: 0.08, lift: -24, blur: 12)
            TrailerHeadline(title: TrailerCopy.Hook.title,
                            subtitle: TrailerCopy.Hook.subtitle,
                            reveal: M.progress(t, 0.3, 1.1),
                            exit: M.easeIn(M.progress(t, 3.1, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }

    /// 3.6–7.4 这是个什么游戏
    private var game: some View {
        let enter = M.spring(t, at: 3.55, response: 0.62, damping: 0.8)
        let exit = M.easeIn(M.progress(t, 7.1, 0.55))
        return ZStack {
            TrailerPhoneFrame(screenWidth: 152, name: .menu)
                .scaleEffect(0.9 + 0.1 * enter)
                .opacity(M.clamp(enter * 2))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY - 10)
                .trailerDepth(exit, scale: 0.1, lift: -20, blur: 10)
            HStack(spacing: 8) {
                ForEach(Array(TrailerCopy.Hook.modes.enumerated()), id: \.offset) { index, mode in
                    let a = M.spring(t, at: 4.3 + Double(index) * 0.22, response: 0.5, damping: 0.78)
                    TrailerPill(text: mode, tint: [S.purple, S.pink, S.teal][index % 3], filled: true)
                        .scaleEffect(0.8 + 0.2 * a)
                        .opacity(M.clamp(a * 2))
                }
            }
            .position(x: TrailerLayout.centerX, y: TrailerLayout.pillY)
            .trailerDepth(exit, scale: 0.08, lift: -14, blur: 8)
            TrailerHeadline(title: TrailerCopy.Hook.gameTitle,
                            subtitle: TrailerCopy.Hook.gameSubtitle,
                            reveal: M.progress(t, 3.75, 0.9),
                            exit: M.easeIn(M.progress(t, 7.0, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }

    /// 7.4–11.5 以前只有一块屏：传来传去、轮流捂着
    private var old: some View {
        let enter = M.spring(t, at: 7.35, response: 0.62, damping: 0.8)
        let exit = M.easeIn(M.progress(t, 11.1, 0.55))
        return ZStack {
            TrailerPhoneFrame(screenWidth: 152, name: .word, overlay: AnyView(CoverHand(t: t)))
                .scaleEffect(0.9 + 0.1 * enter)
                .opacity(M.clamp(enter * 2))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY - 10)
                .trailerDepth(exit, scale: 0.1, lift: -20, blur: 10)
            VStack(spacing: 8) {
                ForEach(Array(TrailerCopy.Hook.oldPills.enumerated()), id: \.offset) { index, text in
                    let a = M.spring(t, at: 8.2 + Double(index) * 0.5, response: 0.5, damping: 0.78)
                    TrailerPill(text: text, tint: S.inkSoft, size: 13)
                        .scaleEffect(0.86 + 0.14 * a)
                        .opacity(M.clamp(a * 2))
                }
            }
            .position(x: TrailerLayout.centerX, y: TrailerLayout.pillY + 10)
            .trailerDepth(exit, scale: 0.08, lift: -14, blur: 8)
            TrailerHeadline(title: TrailerCopy.Hook.oldTitle,
                            subtitle: TrailerCopy.Hook.oldSubtitle,
                            reveal: M.progress(t, 7.55, 0.9),
                            exit: M.easeIn(M.progress(t, 11.0, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }
}

/// 一只手盖住屏幕下半：出题的人得捂着，别人才看不到词
@available(iOS 18.0, *)
private struct CoverHand: View {
    let t: Double

    var body: some View {
        let slide = M.easeInOut(M.progress(t, 8.6, 0.9)) - M.easeInOut(M.progress(t, 10.2, 0.8))
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(colors: [Color(trailerHex: 0xEFC7A8), Color(trailerHex: 0xD8A079)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 150, height: 120)
            .shadow(color: .black.opacity(0.22), radius: 12, y: -4)
            .offset(y: 120 - 118 * CGFloat(slide))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .clipped()
    }
}

// MARK: - 11.5–31s 折起来之后，三块屏各干什么

@available(iOS 18.0, *)
struct TrailerFoldScene: View {
    let t: Double

    var body: some View {
        ZStack {
            if t < 16.6 { folding }
            if t >= 15.9 { screens }
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
    }

    /// 11.5–16 折起来这个动作本身
    private var folding: some View {
        let exit = M.easeIn(M.progress(t, 15.6, 0.6))
        return ZStack {
            FoldDiagram(fold: M.easeInOut(M.progress(t, 12.6, 1.9)))
                .frame(width: 320, height: TrailerCanvas.pick(240, 300))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
                .trailerDepth(exit, scale: 0.1, lift: -20, blur: 10)
            TrailerPill(text: TrailerCopy.Fold.foldLabel, tint: S.purple, size: 15, filled: true)
                .opacity(M.clamp(M.progress(t, 14.4, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.pillY)
                .trailerDepth(exit, scale: 0.08, lift: -14, blur: 8)
            TrailerHeadline(title: TrailerCopy.Fold.title,
                            subtitle: TrailerCopy.Fold.subtitle,
                            reveal: M.progress(t, 11.7, 1.0),
                            exit: M.easeIn(M.progress(t, 15.5, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }

    /// 16–31：上半屏 → 下半屏 → 外屏，每块屏一句话加一张实拍
    private var screens: some View {
        let enter = M.spring(t, at: 15.95, response: 0.68, damping: 0.82)
        let exit = M.easeIn(M.progress(t, 30.6, 0.6))
        // 25.5 之前看内屏那一侧，之后转到外屏那一侧
        let toCover = M.easeInOut(M.progress(t, 25.5, 0.7))
        return ZStack {
            ZStack {
                TrailerShot(name: .inner3D, size: TrailerLayout.shotSize,
                            zoom: M.progress(t, 16, 10), zoomFrom: 1.0, zoomTo: 1.1)
                    .opacity(1 - toCover)
                TrailerShot(name: .cover3D, size: TrailerLayout.shotSize,
                            zoom: M.progress(t, 25.5, 5.5), zoomFrom: 1.0, zoomTo: 1.08)
                    .opacity(toCover)
            }
            .scaleEffect(0.93 + 0.07 * enter)
            .opacity(M.clamp(enter * 2))
            .position(x: TrailerLayout.centerX, y: TrailerLayout.shotY)
            .trailerDepth(exit, scale: 0.1, lift: -20, blur: 10)

            partCard
                .position(x: TrailerLayout.centerX, y: TrailerCanvas.pick(410, 494))
                .trailerDepth(exit, scale: 0.08, lift: -16, blur: 8)

            TrailerHeadline(title: TrailerCopy.Fold.lidTitle, subtitle: nil,
                            titleSize: TrailerCanvas.pick(26, 30),
                            reveal: M.progress(t, 16.2, 0.8),
                            exit: M.easeIn(M.progress(t, 20.4, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t < 21.0 ? 1 : 0)
            TrailerHeadline(title: TrailerCopy.Fold.deckTitle, subtitle: nil,
                            titleSize: TrailerCanvas.pick(26, 30),
                            reveal: M.progress(t, 21.1, 0.8),
                            exit: M.easeIn(M.progress(t, 24.9, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t >= 21.0 && t < 25.5 ? 1 : 0)
            TrailerHeadline(title: TrailerCopy.Fold.coverTitle, subtitle: nil,
                            titleSize: TrailerCanvas.pick(26, 30),
                            reveal: M.progress(t, 25.6, 0.8),
                            exit: M.easeIn(M.progress(t, 30.4, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t >= 25.5 ? 1 : 0)
        }
    }

    /// 当前这块屏：一行说明 + 这块屏上真实的画面
    @ViewBuilder private var partCard: some View {
        if t < 21.0 {
            // 上半屏：笔记本模式内屏的上半段，就是词卡
            PartRow(text: TrailerCopy.Fold.lidBody, appear: M.progress(t, 16.5, 0.6)) {
                AnyView(TrailerSlice(name: .laptop, band: 0.02...0.46, width: 172))
            }
        } else if t < 25.5 {
            // 下半屏：同一张的下半段，画板
            PartRow(text: TrailerCopy.Fold.deckBody, appear: M.progress(t, 21.3, 0.6)) {
                AnyView(TrailerSlice(name: .laptop, band: 0.52...0.98, width: 172))
            }
        } else {
            // 外屏：29s 之后闪一下「答对报分」
            PartRow(text: TrailerCopy.Fold.coverBody, appear: M.progress(t, 25.8, 0.6)) {
                AnyView(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white)
                            .frame(width: 172, height: 118)
                        TrailerShot(name: .cover, size: CGSize(width: 172, height: 118),
                                    corner: 12, mode: .fit, shadow: false)
                        TrailerShot(name: .coverCorrect, size: CGSize(width: 172, height: 118),
                                    corner: 12, mode: .fit, shadow: false)
                            .opacity(M.clamp(M.progress(t, 28.8, 0.25)) * (1 - M.progress(t, 30.1, 0.4)))
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(S.purple.opacity(0.22), lineWidth: 1)
                            .frame(width: 172, height: 118)
                    }
                    .shadow(color: S.purple.opacity(0.2), radius: 14, y: 8)
                )
            }
        }
    }
}

/// 3D 那几张铺满画面：底部化进背景色，顶部压一层白让标题读得出来
@available(iOS 18.0, *)
private struct BleedShot: View {
    let name: TrailerAssets.Name
    var zoom: Double = 0
    var zoomFrom: CGFloat = 1
    var zoomTo: CGFloat = 1

    var body: some View {
        let size = TrailerLayout.bleedSize
        TrailerShot(name: name, size: size, corner: 0,
                    zoom: zoom, zoomFrom: zoomFrom, zoomTo: zoomTo, shadow: false)
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.96), .white.opacity(0.74), .white.opacity(0.2), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: size.height * 0.50)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, TrailerStyle.paper],
                    startPoint: .center, endPoint: .bottom
                )
                .frame(height: size.height * 0.34)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .position(x: TrailerLayout.centerX, y: TrailerLayout.bleedY)
    }
}

/// 一句说明压在一张小图上
@available(iOS 18.0, *)
private struct PartRow: View {
    let text: String
    let appear: Double
    @ViewBuilder var shot: () -> AnyView

    var body: some View {
        let a = M.spring(appear * 0.6, response: 0.5, damping: 0.8)
        VStack(spacing: 10) {
            shot()
            Text(verbatim: text)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(S.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 330)
        }
        .opacity(M.clamp(appear * 3))
        .scaleEffect(0.92 + 0.08 * a)
        .offset(y: CGFloat(1 - a) * 14)
    }
}

/// 侧视图：两根棍子绕一个铰链从摊平合到 90°
@available(iOS 18.0, *)
private struct FoldDiagram: View {
    /// 0 = 摊平，1 = 折到 90°
    let fold: Double

    var body: some View {
        Canvas { ctx, size in
            let hinge = CGPoint(x: size.width * 0.5, y: size.height * 0.62)
            let len = size.width * 0.44
            let thick = max(size.height * 0.060, 11)
            // 平躺那半固定朝左
            ctx.fill(Self.bar(at: hinge, angle: .pi, len: len, thick: thick),
                     with: .color(S.purple.opacity(0.9)))
            // 另一半从「朝右」（摊平）转到「朝上」（90°）
            let angle = M.mix(0, -Double.pi / 2, fold)
            ctx.fill(Self.bar(at: hinge, angle: angle, len: len, thick: thick),
                     with: .color(S.teal.opacity(0.9)))
            // 桌面
            var table = Path()
            table.move(to: CGPoint(x: size.width * 0.06, y: hinge.y + thick * 0.62))
            table.addLine(to: CGPoint(x: size.width * 0.94, y: hinge.y + thick * 0.62))
            ctx.stroke(table, with: .color(S.inkSoft.opacity(0.28)), lineWidth: 2)
        }
        .overlay(alignment: .topTrailing) {
            // 折到 90° 之后，立起那半的背面就是外屏
            Text(verbatim: "外屏")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(S.teal)
                .opacity(M.clamp(M.progress(fold, 0.75, 0.25)))
                .padding(.trailing, 44)
                .padding(.top, 36)
        }
    }

    /// 以 `at` 为起点、朝 `angle` 方向的一根圆角棍子
    private static func bar(at origin: CGPoint, angle: Double, len: CGFloat, thick: CGFloat) -> Path {
        let rect = CGRect(x: 0, y: -thick / 2, width: len, height: thick)
        let path = Path(roundedRect: rect, cornerRadius: thick / 2)
        let transform = CGAffineTransform(rotationAngle: CGFloat(angle))
            .concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
        return path.applying(transform)
    }
}

// MARK: - 31–58.5s 外屏唯一的那条路

@available(iOS 18.0, *)
struct TrailerDoorScene: View {
    let t: Double

    var body: some View {
        ZStack {
            if t < 35.6 { narrowDoor }
            if t >= 34.9 && t < 53.6 { api }
            if t >= 52.9 { deny }
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
    }

    /// 31–35 一扇窄门
    private var narrowDoor: some View {
        let exit = M.easeIn(M.progress(t, 34.6, 0.6))
        return ZStack {
            DoorGraphic(close: M.easeInOut(M.progress(t, 31.6, 1.6)))
                .frame(width: 300, height: TrailerCanvas.pick(220, 280))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
                .trailerDepth(exit, scale: 0.1, lift: -20, blur: 10)
            TrailerHeadline(title: TrailerCopy.Door.title,
                            subtitle: TrailerCopy.Door.subtitle,
                            reveal: M.progress(t, 31.2, 1.0),
                            exit: M.easeIn(M.progress(t, 34.5, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }

    /// 35–53：API 名字 → 两个工厂方法 → 头文件里那句门槛
    private var api: some View {
        let enter = M.spring(t, at: 34.95, response: 0.65, damping: 0.82)
        let exit = M.easeIn(M.progress(t, 52.9, 0.6))
        return ZStack {
            codeStage
                .scaleEffect(0.93 + 0.07 * enter)
                .opacity(M.clamp(enter * 2))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
                .trailerDepth(exit, scale: 0.1, lift: -18, blur: 10)
            TrailerHeadline(title: TrailerCopy.Door.apiTitle,
                            subtitle: TrailerCopy.Door.apiSubtitle,
                            reveal: M.progress(t, 35.2, 0.9),
                            exit: M.easeIn(M.progress(t, 40.4, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t < 41.0 ? 1 : 0)
            TrailerHeadline(title: TrailerCopy.Door.factoryTitle,
                            subtitle: TrailerCopy.Door.factorySubtitle,
                            reveal: M.progress(t, 41.1, 0.9),
                            exit: M.easeIn(M.progress(t, 45.9, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t >= 41.0 && t < 46.5 ? 1 : 0)
            TrailerHeadline(title: TrailerCopy.Door.quoteTitle, subtitle: nil,
                            titleSize: TrailerCanvas.pick(26, 30),
                            reveal: M.progress(t, 46.6, 0.9),
                            exit: M.easeIn(M.progress(t, 52.5, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t >= 46.5 ? 1 : 0)
        }
    }

    @ViewBuilder private var codeStage: some View {
        if t < 41.0 {
            TrailerCodeCard(
                lines: [.init(text: TrailerCopy.Door.api, hot: true)],
                width: 340, size: 22, reveal: M.progress(t, 35.5, 0.8),
                title: "// iOS 27"
            )
        } else if t < 46.5 {
            TrailerCodeCard(
                lines: [
                    .init(text: ".externalNonInteractive", dim: true),
                    .init(text: "    // HDMI / AirPlay 外接显示器", dim: true),
                    .init(text: ".cameraCapture", hot: t >= 43.4),
                ],
                width: 340, size: 16, reveal: M.progress(t, 41.4, 1.1),
                title: "UISceneAccessory"
            )
        } else {
            QuoteCard(reveal: M.progress(t, 46.9, 1.0), note: M.progress(t, 49.6, 0.6))
        }
    }

    /// 53–58.5：不开相机会话，系统直接不给
    private var deny: some View {
        let enter = M.spring(t, at: 53.0, response: 0.6, damping: 0.8)
        let exit = M.easeIn(M.progress(t, 58.1, 0.55))
        let stamp = M.spring(t, at: 54.3, response: 0.45, damping: 0.6)
        return ZStack {
            VStack(spacing: 16) {
                Text(verbatim: TrailerCopy.Door.deny)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(S.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(S.red.opacity(0.1))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(S.red.opacity(0.55), lineWidth: 2.5)
                            }
                    }
                    .rotationEffect(.degrees(-4))
                    .scaleEffect(1.25 - 0.25 * CGFloat(stamp))
                    .opacity(M.clamp(stamp * 2))
                TrailerPill(text: TrailerCopy.Door.denyPill, tint: S.inkSoft, size: 14)
                    .opacity(M.clamp(M.progress(t, 55.8, 0.5)))
            }
            .scaleEffect(0.94 + 0.06 * enter)
            .opacity(M.clamp(enter * 2))
            .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
            .trailerDepth(exit, scale: 0.1, lift: -18, blur: 10)
            TrailerHeadline(title: TrailerCopy.Door.denyTitle,
                            subtitle: TrailerCopy.Door.denySubtitle,
                            reveal: M.progress(t, 53.2, 0.9),
                            exit: M.easeIn(M.progress(t, 58.0, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }
}

/// 两扇门合到只剩一条缝
@available(iOS 18.0, *)
private struct DoorGraphic: View {
    let close: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gap = M.mix(w * 0.52, 16, close)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(S.accentDown)
                    .frame(width: gap + 20, height: h * 0.92)
                    .blur(radius: 14)
                    .opacity(0.55 + 0.45 * close)
                ForEach([-1.0, 1.0], id: \.self) { side in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [.white, Color(trailerHex: 0xEFE8FA)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(S.purple.opacity(0.18), lineWidth: 1)
                        }
                        .frame(width: w * 0.46, height: h * 0.92)
                        .shadow(color: S.purple.opacity(0.2), radius: 16, y: 8)
                        .offset(x: CGFloat(side) * (gap / 2 + w * 0.23))
                }
            }
            .frame(width: w, height: h)
        }
    }
}

/// 头文件里那句门槛，原样引，不改写
@available(iOS 18.0, *)
private struct QuoteCard: View {
    let reveal: Double
    let note: Double

    var body: some View {
        TrailerCard(corner: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text(verbatim: TrailerCopy.Door.quote)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(S.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textRenderer(GlyphBlurRenderer(progress: reveal))
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(S.pink)
                    Text(verbatim: TrailerCopy.Door.quoteNote)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(S.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .opacity(M.clamp(note * 2))
            }
            .frame(width: 300, alignment: .leading)
        }
    }
}

// MARK: - 58.5–75.2s 那个只为过门槛而存在的相机会话

@available(iOS 18.0, *)
struct TrailerCameraScene: View {
    let t: Double

    var body: some View {
        ZStack {
            if t < 65.6 { session }
            if t >= 64.9 && t < 70.1 { purpose }
            if t >= 69.4 { cost }
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
    }

    /// 58.5–65 这个会话长什么样
    private var session: some View {
        let enter = M.spring(t, at: 58.6, response: 0.65, damping: 0.82)
        let exit = M.easeIn(M.progress(t, 64.6, 0.6))
        return ZStack {
            VStack(spacing: 14) {
                TrailerCodeCard(
                    lines: [
                        .init(text: "session.sessionPreset = .low"),
                        .init(text: "output.alwaysDiscardsLateVideoFrames = true"),
                        .init(text: "func captureOutput(_ o: …) { }", hot: true),
                        .init(text: "    // 帧收到就扔，一行都不读", dim: true),
                    ],
                    width: 344, size: 13, reveal: M.progress(t, 59.0, 1.3),
                    title: "AVCaptureSession"
                )
                HStack(spacing: 7) {
                    ForEach(Array(TrailerCopy.Camera.traits.enumerated()), id: \.offset) { index, text in
                        let a = M.spring(t, at: 61.4 + Double(index) * 0.35, response: 0.5, damping: 0.78)
                        TrailerPill(text: text, tint: S.purple, size: 12)
                            .scaleEffect(0.84 + 0.16 * a)
                            .opacity(M.clamp(a * 2))
                    }
                }
            }
            .scaleEffect(0.94 + 0.06 * enter)
            .opacity(M.clamp(enter * 2))
            .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
            .trailerDepth(exit, scale: 0.1, lift: -18, blur: 10)
            TrailerHeadline(title: TrailerCopy.Camera.title,
                            subtitle: TrailerCopy.Camera.subtitle,
                            titleSize: TrailerCanvas.pick(25, 29),
                            reveal: M.progress(t, 58.8, 0.9),
                            exit: M.easeIn(M.progress(t, 64.5, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }

    /// 65–69.5 它唯一的用处
    private var purpose: some View {
        let enter = M.spring(t, at: 64.95, response: 0.6, damping: 0.8)
        let exit = M.easeIn(M.progress(t, 69.1, 0.55))
        let flow = M.easeInOut(M.progress(t, 66.1, 1.0))
        return ZStack {
            HStack(spacing: 12) {
                IconCard(symbol: "video.fill", label: TrailerCopy.Camera.from, tint: S.inkSoft)
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(S.accent)
                    .opacity(M.clamp(flow * 2))
                    .offset(x: CGFloat(1 - flow) * -10)
                VStack(spacing: 6) {
                    TrailerShot(name: .cover, size: CGSize(width: 118, height: 81),
                                corner: 10, mode: .fit, shadow: false)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white)
                        }
                    Text(verbatim: TrailerCopy.Camera.to)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(S.teal)
                }
                .opacity(M.clamp((flow - 0.4) * 2.4))
            }
            .scaleEffect(0.94 + 0.06 * enter)
            .opacity(M.clamp(enter * 2))
            .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
            .trailerDepth(exit, scale: 0.1, lift: -18, blur: 10)
            TrailerHeadline(title: TrailerCopy.Camera.purposeTitle,
                            subtitle: TrailerCopy.Camera.purposeSubtitle,
                            reveal: M.progress(t, 65.1, 0.9),
                            exit: M.easeIn(M.progress(t, 69.0, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }

    /// 69.5–75 代价
    private var cost: some View {
        let enter = M.spring(t, at: 69.5, response: 0.6, damping: 0.8)
        let exit = M.easeIn(M.progress(t, 74.6, 0.55))
        let columns = [GridItem(.fixed(160), spacing: 10), GridItem(.fixed(160), spacing: 10)]
        return ZStack {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(TrailerCopy.Camera.costs.enumerated()), id: \.offset) { index, text in
                    let a = M.spring(t, at: 70.0 + Double(index) * 0.45, response: 0.5, damping: 0.78)
                    HStack(spacing: 7) {
                        Circle()
                            .fill(index == 1 ? S.green : S.pink)
                            .frame(width: 9, height: 9)
                        Text(verbatim: text)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(S.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .frame(width: 160, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white)
                            .shadow(color: S.purple.opacity(0.14), radius: 10, y: 5)
                    }
                    .scaleEffect(0.9 + 0.1 * a)
                    .opacity(M.clamp(a * 2))
                }
            }
            .frame(width: 330)
            .scaleEffect(0.95 + 0.05 * enter)
            .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
            .trailerDepth(exit, scale: 0.1, lift: -18, blur: 10)
            TrailerHeadline(title: TrailerCopy.Camera.costTitle,
                            subtitle: TrailerCopy.Camera.costSubtitle,
                            reveal: M.progress(t, 69.7, 0.9),
                            exit: M.easeIn(M.progress(t, 74.5, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }
}

@available(iOS 18.0, *)
private struct IconCard: View {
    let symbol: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .frame(width: 84, height: 81)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .overlay(alignment: .topTrailing) {
                    // 挂着的那个相机其实什么都不干
                    Image(systemName: "nosign")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(S.red.opacity(0.75))
                        .padding(6)
                }
                .shadow(color: S.purple.opacity(0.16), radius: 12, y: 6)
            Text(verbatim: label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - 75–91s 剩下的坑

@available(iOS 18.0, *)
struct TrailerPitfallScene: View {
    let t: Double

    var body: some View {
        let enter = M.spring(t, at: 75.0, response: 0.62, damping: 0.82)
        let exit = M.easeIn(M.progress(t, 90.6, 0.6))
        // 旁白第 18 条前半句还在讲「外屏右边 84pt」，那一行得先露脸；
        // 后半句（不按比例缩）才换成「搬过去会被切」的前后对比
        let toFit = M.easeInOut(M.progress(t, 87.4, 0.6))
        return ZStack {
            VStack(spacing: 10) {
                ForEach(Array(TrailerCopy.Pitfall.rows.enumerated()), id: \.offset) { index, row in
                    TrailerRow(want: row.want, answer: row.answer, granted: row.granted,
                               width: 334, appear: M.progress(t, 75.5 + Double(index) * 4.85, 0.6))
                }
            }
            .opacity(1 - toFit)
            .scaleEffect(0.95 + 0.05 * enter - 0.05 * CGFloat(toFit))
            .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)

            FitComparison(reveal: M.progress(t, 87.8, 0.7))
                .opacity(toFit)
                .scaleEffect(0.94 + 0.06 * toFit)
                .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY)
                .trailerDepth(exit, scale: 0.1, lift: -18, blur: 10)

            TrailerHeadline(title: TrailerCopy.Pitfall.title,
                            subtitle: TrailerCopy.Pitfall.subtitle,
                            reveal: M.progress(t, 75.2, 0.9),
                            exit: M.easeIn(M.progress(t, 86.8, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t < 87.4 ? 1 : 0)
            TrailerHeadline(title: TrailerCopy.Pitfall.fitTitle,
                            subtitle: TrailerCopy.Pitfall.fitSubtitle,
                            titleSize: TrailerCanvas.pick(25, 29),
                            reveal: M.progress(t, 87.6, 0.9),
                            exit: M.easeIn(M.progress(t, 90.4, 0.45)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
                .opacity(t >= 87.4 ? 1 : 0)
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
    }
}

/// 左边「直接搬」被切掉两边，右边「按比例 fit」完整
@available(iOS 18.0, *)
private struct FitComparison: View {
    let reveal: Double

    var body: some View {
        HStack(spacing: 12) {
            panel(title: TrailerCopy.Pitfall.fitBad, bad: true, appear: M.progress(reveal, 0, 0.6))
            panel(title: TrailerCopy.Pitfall.fitGood, bad: false, appear: M.progress(reveal, 0.35, 0.6))
        }
    }

    private func panel(title: String, bad: Bool, appear: Double) -> some View {
        let a = M.spring(appear * 0.6, response: 0.5, damping: 0.8)
        let box = CGSize(width: 158, height: 109)
        return VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white)
                // 「直接搬」= 归一化坐标照搬：短边对齐，长边溢出去被切掉
                TrailerShot(name: .cover, size: box, corner: 12,
                            mode: bad ? .fill : .fit, shadow: false)
                    .scaleEffect(bad ? 1.88 : 1.0)
                    .frame(width: box.width, height: box.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                if bad {
                    HStack {
                        Rectangle().fill(S.red.opacity(0.26)).frame(width: box.width * 0.26)
                        Spacer()
                        Rectangle().fill(S.red.opacity(0.26)).frame(width: box.width * 0.26)
                    }
                    .frame(width: box.width, height: box.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(bad ? S.red.opacity(0.7) : S.green.opacity(0.7), lineWidth: 2)
            }
            .frame(width: box.width, height: box.height)
            .shadow(color: S.purple.opacity(0.16), radius: 12, y: 6)
            HStack(spacing: 5) {
                Image(systemName: bad ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(bad ? S.red : S.green)
                Text(verbatim: title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(S.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .opacity(M.clamp(appear * 3))
        .scaleEffect(0.92 + 0.08 * a)
        .offset(y: CGFloat(1 - a) * 12)
    }
}

// MARK: - 91–101.5s 呼吁 + 片尾

@available(iOS 18.0, *)
struct TrailerEndScene: View {
    let t: Double

    var body: some View {
        ZStack {
            if t < 97.3 { plea }
            if t >= 96.5 { card }
        }
        .frame(width: TrailerCanvas.width, height: TrailerCanvas.height)
    }

    /// 91–96.5 推近外屏，把那句话压在上面
    private var plea: some View {
        let exit = M.easeIn(M.progress(t, 96.4, 0.6))
        return ZStack {
            BleedShot(name: .cover3D, zoom: M.progress(t, 91, 6), zoomFrom: 1.02, zoomTo: 1.18)
                .trailerDepth(exit, scale: 0.1, lift: -24, blur: 12)
            TrailerHeadline(title: TrailerCopy.End.title,
                            subtitle: TrailerCopy.End.subtitle,
                            reveal: M.progress(t, 91.2, 1.1),
                            exit: M.easeIn(M.progress(t, 96.2, 0.5)))
                .position(x: TrailerLayout.centerX, y: TrailerLayout.headlineY)
        }
    }

    /// 96.5–101.5 片尾
    private var card: some View {
        let enter = M.spring(t, at: 96.6, response: 0.72, damping: 0.82)
        return VStack(spacing: 16) {
            Group {
                if let ui = TrailerAssets.image(.icon) {
                    Image(uiImage: ui).resizable()
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(S.accentDown)
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .shadow(color: S.purple.opacity(0.28), radius: 20, y: 10)

            VStack(spacing: 5) {
                Text(verbatim: TrailerCopy.End.appName)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(S.ink)
                Text(verbatim: TrailerCopy.End.appLine)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(S.inkSoft)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            VStack(spacing: 3) {
                Text(verbatim: TrailerCopy.End.closing)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(S.ink)
                Text(verbatim: TrailerCopy.End.closingAccent)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(S.accent)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.top, 6)
            .opacity(M.clamp(M.progress(t, 98.2, 0.8)))
        }
        .frame(width: 340)
        .scaleEffect(0.9 + 0.1 * enter)
        .opacity(M.clamp(enter * 2))
        .position(x: TrailerLayout.centerX, y: TrailerLayout.stageY - 10)
    }
}
#endif
