import SwiftUI
import Combine

// MARK: - 笔画模型

struct Stroke: Identifiable {
    let id = UUID()
    /// 归一化坐标：原点在画布中心，单位是画布短边。画布尺寸变了（折叠 / 展开 / 分屏）笔迹也不会错位或变形
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

/// 画布坐标与归一化坐标之间的换算
enum CanvasSpace {
    static func normalize(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let unit = max(min(size.width, size.height), 1)
        return CGPoint(x: (p.x - size.width / 2) / unit,
                       y: (p.y - size.height / 2) / unit)
    }

    static func denormalize(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let unit = min(size.width, size.height)
        return CGPoint(x: size.width / 2 + p.x * unit,
                       y: size.height / 2 + p.y * unit)
    }
}

/// 你画我猜（按键流程）：看词界面 ⇄「开始作画/收起画布」⇄ 画布界面
/// 计分按钮（答对/换一个/被抢答）只在看词界面；画布界面只有作画工具。
/// 防偷窥模式开启时，看词界面叠加姿态隐词（放平自动隐藏）。
struct DrawView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject private var motion = MotionManager.shared

    @State private var word = ""
    @State private var ownPoints = 0
    @State private var stolenPoints = 0
    @State private var skipsLeft = 0
    @State private var remaining = 60
    @State private var showCanvas = false     // 按键切换：词语界面 / 画布界面
    @State private var forceShow = false      // 连点三次强制显词（防偷窥模式下）
    @State private var forceTaps: [Date] = []

    @State var strokes: [Stroke] = []
    @State private var currentStroke: Stroke?
    @State private var selectedColor: Color = .black
    @State private var selectedWidth: CGFloat = 6
    @State private var eraserOn = false        // 橡皮：白底画布上用白色笔刷擦，撤销/清空照常生效
    @State private var usingCustom = false            // 当前笔是不是自选色（别拿 Color 相等去判断，自选色可能恰好等于某个预设色）
    @State private var pickerOpen = false
    @State private var pickerHue: Double = 0.78       // 默认紫，跟原来第六格的颜色对齐
    @State private var pickerShade: Double = 0.33     // 0 = 白，0.5 = 纯色，1 = 黑
    @State private var swatchRect: CGRect = .zero     // 自选色按钮在画布坐标系里的位置，色盘从这里长出来、也缩回这里

    static let palette: [Color] = [.black, .red, .blue, .green, .orange]
    static let widths: [CGFloat] = [3, 6, 12]
    /// 橡皮比画笔粗一圈，不然擦得太慢
    static let eraserScale: CGFloat = 2.5

    /// 色盘展开/收起用同一条弹簧，两个方向的手感才对称；bounce 给足，到位时会冲过头再弹回来
    static let pickerSpring: Animation = .spring(duration: 0.8, bounce: 0.3)
    static let panelHeight: CGFloat = 172

    /// 一条色带走完「白 → 纯色 → 黑」，一个手指就能调深浅
    static func customColor(hue: Double, shade: Double) -> Color {
        shade <= 0.5 ? Color(hue: hue, saturation: shade * 2, brightness: 1)
                     : Color(hue: hue, saturation: 1, brightness: 2 - shade * 2)
    }
    private var pickedColor: Color { Self.customColor(hue: pickerHue, shade: pickerShade) }

    private var brushColor: Color { eraserOn ? .white : (usingCustom ? pickedColor : selectedColor) }
    private var brushWidth: CGFloat { eraserOn ? selectedWidth * Self.eraserScale : selectedWidth }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var game: GameKind { .drawGuess }

    /// 防偷窥模式下，看词界面放平自动隐词
    private var wordHiddenByGuard: Bool {
        store.settings.privacyGuardOn && !forceShow && motion.posture == .flat
    }

    var body: some View {
        ZStack {
            PartyBackground()
            if showCanvas {
                canvasBody
            } else {
                wordBody
            }
        }
        .onAppear {
            remaining = store.roundDuration
            skipsLeft = store.skipAllowance
            if word.isEmpty { word = store.nextWord() }
            if store.settings.privacyGuardOn { motion.start() }
            if let m = ScreenshotMode.mode, ["draw", "drawcanvas", "drawpicker"].contains(m) {
                word = LanguageManager.shared.language == .en ? "snowman" : "雪人"
                ownPoints = 2
                if m != "draw" {
                    strokes = ScreenshotMode.demoStrokes()
                    showCanvas = true
                }
                if m == "drawpicker" {
                    // 录屏脚本用：停一下 → 展开 → 拖一下色相 → 收起，两个动画都录进去。
                    // 先停 2 秒：刚启动时主线程还忙，停太短的话这几段会被挤到一起一口气跑完
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        usingCustom = true
                        withAnimation(Self.pickerSpring) { pickerOpen = true }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                        withAnimation(.easeInOut(duration: 0.9)) { pickerHue = 0.05 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                        withAnimation(Self.pickerSpring) { pickerOpen = false }
                    }
                }
            }
        }
        .onDisappear { motion.stop() }
        .onReceive(timer) { _ in
            guard remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 {
                FeedbackManager.shared.timeUp()
                store.finishPlay(own: ownPoints, stolen: stolenPoints)
            } else if remaining <= 5 {
                FeedbackManager.shared.countdownTick()
            }
        }
    }

    // MARK: 看词界面（计分按钮都在这里）

    private var wordBody: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HomeExitButton()
                TimerRing(remaining: remaining, total: store.roundDuration, size: 50)
                Text("+\(ownPoints)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(game.colors[0])
                    .contentTransition(.numericText())
                if stolenPoints > 0 {
                    Text(L("play.stolen", stolenPoints))
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                Spacer()
                if store.openBuzz { OpenBuzzBadge(compact: true) }
                if store.settings.privacyGuardOn {
                    ForceRevealButton(forceShow: $forceShow, taps: $forceTaps)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if store.catchUp.isActive {
                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)
            }

            Spacer()

            if wordHiddenByGuard {
                PrivacyCard(game: game)
            } else {
                VStack(spacing: 12) {
                    Text(L("draw.artist_only"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Text(word)
                        .font(.system(size: word.count > 6 ? 40 : 54, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 38)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(game.gradient)
                        .shadow(color: game.colors[0].opacity(0.45), radius: 14, y: 6)
                )
                .padding(.horizontal, 24)
            }

            Spacer()

            // 开始作画 + 计分按钮（只在看词界面）
            VStack(spacing: 10) {
                Button {
                    FeedbackManager.shared.tap()
                    showCanvas = true
                } label: {
                    Label(L("draw.start_drawing"), systemImage: "paintbrush.pointed.fill")
                }
                .buttonStyle(BigButtonStyle(colors: game.colors))

                if store.openBuzz {
                    HStack(spacing: 10) {
                        correctButton(compactLabel: true)
                        Button {
                            FeedbackManager.shared.buzz()
                            stolenPoints += 1
                            nextDrawing(guessed: true)
                        } label: {
                            Label(L("draw.sniped"), systemImage: "bolt.fill")
                        }
                        .buttonStyle(BigButtonStyle(colors: [.red, .orange], font: .headline, tall: true))
                    }
                } else {
                    correctButton(compactLabel: false)
                }

                Button {
                    FeedbackManager.shared.skip()
                    skipsLeft -= 1
                    nextDrawing(guessed: false)
                } label: {
                    Label(L("play.skip_n", skipsLeft), systemImage: "arrow.uturn.right.circle.fill")
                }
                .buttonStyle(BigButtonStyle(colors: skipsLeft > 0
                                            ? [.orange, .yellow]
                                            : [Color(.systemGray3), Color(.systemGray4)],
                                            font: .headline))
                .disabled(skipsLeft <= 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private func correctButton(compactLabel: Bool) -> some View {
        Button {
            FeedbackManager.shared.correct()
            ownPoints += 1
            nextDrawing(guessed: true)
        } label: {
            Label(compactLabel ? L("play.correct_us") : L("draw.correct_plain"),
                  systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(BigButtonStyle(colors: [.green, .mint], font: .headline, tall: true))
    }

    // MARK: 画布界面（只有作画工具 + 收起画布）

    static let canvasSpace = "drawCanvas"

    private var canvasBody: some View {
        ZStack {
            canvasStack
            colorPickerLayer
        }
        .coordinateSpace(name: Self.canvasSpace)
        .onPreferenceChange(SwatchRectKey.self) { swatchRect = $0 }
    }

    private var canvasStack: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                HomeExitButton()
                TimerRing(remaining: remaining, total: store.roundDuration, size: 48)
                Text("+\(ownPoints)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(game.colors[0])
                    .contentTransition(.numericText())
                Spacer()
                if store.openBuzz { OpenBuzzBadge(compact: true) }
                Text(L("draw.word_hidden"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.8)))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // 画布
            drawingCanvas
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 12)

            // 工具栏：6色 + 橡皮 + 3档粗细 + 撤销/清空
            HStack(spacing: 4) {
                ForEach(Array(Self.palette.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 26, height: 26)
                        .overlay(Circle()
                            .stroke(.blue, lineWidth: (!eraserOn && !usingCustom && selectedColor == color) ? 3 : 0)
                            .padding(-3))
                        .onTapGesture {
                            FeedbackManager.shared.tap()
                            selectedColor = color
                            usingCustom = false
                            eraserOn = false          // 选颜色 = 切回画笔
                        }
                }
                // 自选色：彩虹外圈 + 中间是当前自选的颜色，点一下选中它并展开色盘
                Circle()
                    .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                          center: .center))
                    .overlay(Circle().fill(.white).padding(3))
                    .overlay(Circle().fill(pickedColor).padding(5))
                    .frame(width: 26, height: 26)
                    .overlay(Circle()
                        .stroke(.blue, lineWidth: (!eraserOn && usingCustom) ? 3 : 0)
                        .padding(-3))
                    // 量一下按钮在画布里的位置，色盘就是从这个圆长出来的
                    .background(GeometryReader { g in
                        Color.clear.preference(key: SwatchRectKey.self,
                                               value: g.frame(in: .named(DrawView.canvasSpace)))
                    })
                    .onTapGesture {
                        FeedbackManager.shared.tap()
                        usingCustom = true
                        eraserOn = false
                        withAnimation(Self.pickerSpring) { pickerOpen.toggle() }
                    }
                    .accessibilityLabel(Text(L("draw.custom_color")))
                // 橡皮：当成第七支「笔」，跟颜色互斥
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 1))
                    .overlay(
                        Image(systemName: "eraser.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(.systemGray))
                    )
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(.blue, lineWidth: eraserOn ? 3 : 0).padding(-3))
                    .onTapGesture {
                        FeedbackManager.shared.tap()
                        eraserOn = true
                    }
                    .accessibilityLabel(Text(L("draw.eraser")))
                Divider().frame(height: 26)
                ForEach(Self.widths, id: \.self) { w in
                    Circle()
                        .fill(Color.primary.opacity(selectedWidth == w ? 1 : 0.35))
                        .frame(width: 8 + w, height: 8 + w)
                        .frame(width: 20, height: 22)
                        .onTapGesture {
                            FeedbackManager.shared.tap()
                            selectedWidth = w
                        }
                }
                Divider().frame(height: 26)
                Button {
                    FeedbackManager.shared.tap()
                    _ = strokes.popLast()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title3)
                }
                Button {
                    FeedbackManager.shared.skip()
                    strokes.removeAll()
                    eraserOn = false
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)

            // 收起画布 → 回到看词界面
            Button {
                FeedbackManager.shared.tap()
                showCanvas = false
            } label: {
                Label(L("draw.close_canvas"), systemImage: "chevron.down.circle.fill")
            }
            .buttonStyle(BigButtonStyle(colors: [.indigo, .purple], font: .headline))
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }
    }

    // MARK: 色盘（从按钮变形展开，点完成或点别处缩回按钮）

    /// 遮罩 + 色盘。色盘一直在视图树里，只是尺寸/位置/圆角在按钮和面板之间插值，
    /// 所以展开和收起是同一段连续动画，不是两个转场拼起来的。
    private var colorPickerLayer: some View {
        GeometryReader { geo in
            let panelWidth = geo.size.width - 24
            let target = CGRect(x: 12,
                                y: max(swatchRect.minY - 14 - Self.panelHeight, 12),
                                width: panelWidth,
                                height: Self.panelHeight)
            // 按钮中间那颗 16pt 的色点：水滴从这里长出来，收起时也缩回这里
            let dot = CGRect(x: swatchRect.midX - 8, y: swatchRect.midY - 8, width: 16, height: 16)

            ZStack {
                // 点画布上别的地方也收起
                Color.black.opacity(pickerOpen ? 0.18 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(pickerOpen)
                    .onTapGesture { closePicker() }

                pickerPanel(width: panelWidth)
                    .frame(width: panelWidth, height: Self.panelHeight)   // 内容始终按最终尺寸布局，动画里只是被裁掉
                    .modifier(DropMorph(progress: pickerOpen ? 1 : 0, from: dot, to: target, tint: pickedColor))
                    .opacity(swatchRect == .zero ? 0 : 1)                // 还没量到按钮位置之前先别画
                    .allowsHitTesting(pickerOpen)
            }
        }
    }

    private func closePicker() {
        FeedbackManager.shared.tap()
        withAnimation(Self.pickerSpring) { pickerOpen = false }
    }

    private func pickerPanel(width: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(pickedColor)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                Text(L("draw.custom_color"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: closePicker) {
                    Text(L("draw.done"))
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.systemGray6)))
                }
                .buttonStyle(.plain)
            }
            spectrumBar(width: width - 28, hueBar: true)
            spectrumBar(width: width - 28, hueBar: false)
        }
        .padding(14)
    }

    /// 上面一条选色相，下面一条选深浅；拖到哪儿画笔就立刻变成哪个颜色
    private func spectrumBar(width: CGFloat, hueBar: Bool) -> some View {
        let value = hueBar ? pickerHue : pickerShade
        let fill: LinearGradient = hueBar
            ? LinearGradient(colors: (0...12).map { Color(hue: Double($0) / 12, saturation: 1, brightness: 1) },
                             startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [.white, Self.customColor(hue: pickerHue, shade: 0.5), .black],
                             startPoint: .leading, endPoint: .trailing)
        return Capsule()
            .fill(fill)
            .frame(width: width, height: 30)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(.white)
                    .overlay(Circle()
                        .fill(hueBar ? Color(hue: pickerHue, saturation: 1, brightness: 1) : pickedColor)
                        .padding(4))
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .offset(x: (width - 26) * value)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let t = min(max(v.location.x / width, 0), 1)
                if hueBar { pickerHue = t } else { pickerShade = t }
            })
    }

    private var drawingCanvas: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for stroke in strokes {
                    context.stroke(Self.path(for: stroke.points, in: size),
                                   with: .color(stroke.color),
                                   style: StrokeStyle(lineWidth: stroke.lineWidth,
                                                      lineCap: .round, lineJoin: .round))
                }
                if let s = currentStroke {
                    context.stroke(Self.path(for: s.points, in: size),
                                   with: .color(s.color),
                                   style: StrokeStyle(lineWidth: s.lineWidth,
                                                      lineCap: .round, lineJoin: .round))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // 落点按画布尺寸归一化后再存，画布变形时已经画好的线不会跟着歪
                        let p = CanvasSpace.normalize(value.location, in: geo.size)
                        if currentStroke == nil {
                            currentStroke = Stroke(points: [p],
                                                   color: brushColor,
                                                   lineWidth: brushWidth)
                        } else {
                            currentStroke?.points.append(p)
                        }
                    }
                    .onEnded { _ in
                        if let s = currentStroke { strokes.append(s) }
                        currentStroke = nil
                    }
            )
        }
    }

    static func path(for points: [CGPoint], in size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first.map({ CanvasSpace.denormalize($0, in: size) }) else { return path }
        path.move(to: first)
        if points.count == 1 {
            path.addLine(to: CGPoint(x: first.x + 0.1, y: first.y + 0.1))
        } else {
            for p in points.dropFirst() { path.addLine(to: CanvasSpace.denormalize(p, in: size)) }
        }
        return path
    }

    /// 换词：结算当前词、清画布、回到看词界面
    private func nextDrawing(guessed: Bool) {
        store.markCurrentWord(guessed: guessed)
        word = store.nextWord()
        strokes.removeAll()
        currentStroke = nil
        eraserOn = false
        showCanvas = false
        forceShow = false
    }
}

// MARK: - 按钮位置

/// 自选色按钮在画布坐标系里的位置，色盘靠它决定从哪儿长出来
struct SwatchRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

// MARK: - 色盘的水滴变形

/// 色盘从按钮的色点长出来：先往上拉成一滴竖着的水滴，到位时再横向摊开成面板；收起时倒着走一遍缩回色点。
/// progress 由弹簧驱动，回弹时会冲过 1、或在收起时低于 0，超出 [0, 1] 的部分按直线外推，冲过头就是真的冲过头。
struct DropMorph: ViewModifier, Animatable {
    var progress: Double
    var from: CGRect
    var to: CGRect
    var tint: Color

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// 竖直方向先走、水平方向后走（前 0.1 秒是一滴 30×80 左右的竖水滴）。
    /// 两条曲线在 0 和 1 处都跟直线接得上，外推时不会有折角；lead 的系数小于 3 才保证单调
    private static func lead(_ p: Double) -> Double {
        guard p > 0 && p < 1 else { return p }
        return p + 2.4 * p * (1 - p) * (1 - p)
    }
    private static func lag(_ p: Double) -> Double {
        guard p > 0 && p < 1 else { return p }
        return p - p * (1 - p) * (1 - p)
    }
    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

    func body(content: Content) -> some View {
        let v = Self.lead(progress)
        let h = Self.lag(progress)
        let width = max(Self.lerp(from.width, to.width, h), 0.5)
        let height = max(Self.lerp(from.height, to.height, v), 0.5)
        // 没摊开之前两头都是半圆（竖着的水滴），快摊开完才收成面板的 22pt 圆角
        let radius = min(min(width, height) / 2, Self.lerp(200, 22, Self.clamp(h)))
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return content
            .opacity(Self.clamp((h - 0.6) / 0.3))          // 摊开得差不多了，里面的色带才浮出来
            .frame(width: width, height: height)
            .clipShape(shape)
            .background(
                shape.fill(.white)
                    // 刚离开按钮时还是色点的颜色，越长越白
                    .overlay(shape.fill(tint).opacity(1 - Self.clamp((v - 0.1) / 0.6)))
                    .shadow(color: .black.opacity(0.18 * Self.clamp(v)), radius: 14, y: 6)
            )
            .position(x: Self.lerp(from.midX, to.midX, h), y: Self.lerp(from.midY, to.midY, v))
    }
}
