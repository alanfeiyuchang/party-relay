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

/// 把「作画时那块画板」的方框等比放进当前这块地方，并居中。
///
/// 为什么需要它：笔画存的是归一化坐标，单位是画板**短边**（见 `CanvasSpace`）。
/// 这个归一化保住了比例，却没保住**范围**——在折叠时那块宽扁的画板上（约 1.84）
/// x 能画到 ±0.92，而摊开后画板变窄高（约 0.80），可见的 x 只到 ±0.5，
/// 横向直接被切掉四成多。外屏早就是这么修的（`DrawingFace`），内屏一直没修。
///
/// 所以作画区的长宽比在一个词之内**钉死**，画板只是被等比放进当前可用的地方，
/// 怎么折都不会丢东西，内外屏看到的也是同一张画。
enum CanvasFit {
    static func box(aspect: CGFloat, in size: CGSize) -> CGRect {
        guard aspect > 0, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let fit = size.width / size.height > aspect
            ? CGSize(width: size.height * aspect, height: size.height)   // 高度先到顶
            : CGSize(width: size.width, height: size.width / aspect)     // 宽度先到顶
        return CGRect(x: (size.width - fit.width) / 2,
                      y: (size.height - fit.height) / 2,
                      width: fit.width, height: fit.height)
    }
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
    @ObservedObject private var hinge = HingeMonitor.shared
    /// 折起来之前停在哪一页（看词 / 画布），摊开时还回去
    @State private var canvasBeforeFold = false
    /// 这个词的作画区长宽比，0 = 还没钉。换词 / 清空时归零（见 pinBoard）
    @State private var boardAspect: CGFloat = 0

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
    @State private var pickerCell = 4 * DrawView.gridColumns + 9   // 色盘里选中的格子，默认纯紫，跟原来第六格的颜色对齐
    @State private var swatchRect: CGRect = .zero     // 自选色按钮在画布坐标系里的位置，色盘从这里长出来、也缩回这里

    static let palette: [Color] = [.black, .red, .blue, .green, .orange]
    static let widths: [CGFloat] = [3, 6, 12]
    /// 橡皮比画笔粗一圈，不然擦得太慢
    static let eraserScale: CGFloat = 2.5

    /// 色盘展开/收起用同一条弹簧，两个方向的手感才对称；bounce 给足，到位时会冲过头再弹回来
    static let pickerSpring: Animation = .spring(duration: 0.4, bounce: 0.3)

    /// 色盘：12 列 × 8 行，点一格就是一个颜色，不用拖。
    /// 第一行是灰阶（白 → 黑）；下面每列一个色相，从红开始每 30° 一列，从上到下由浅到深 7 档
    static let gridColumns = 12
    static let gridShades: [Double] = [0.18, 0.3, 0.42, 0.5, 0.62, 0.74, 0.86]   // 0 = 白，0.5 = 纯色，1 = 黑
    static var gridRows: Int { 1 + gridShades.count }
    static let headerHeight: CGFloat = 32       // 面板顶上那行（色点 + 标题 + 完成），固定高度，面板高度才算得准

    static func gridColor(_ cell: Int) -> Color {
        let row = cell / gridColumns, col = cell % gridColumns
        if row == 0 { return Color(white: 1 - Double(col) / Double(gridColumns - 1)) }
        let hue = Double(col) / Double(gridColumns)
        let shade = gridShades[row - 1]
        return shade <= 0.5 ? Color(hue: hue, saturation: shade * 2, brightness: 1)
                            : Color(hue: hue, saturation: 1, brightness: 2 - shade * 2)
    }

    /// 面板上沿至少离它所在那块区域的顶边这么远
    static let panelTopMargin: CGFloat = 12
    /// 再挤也不把色盘压到这个宽度以下——格子小到点不准就没意义了，宁可溢出一点
    static let panelMinWidth: CGFloat = 260

    /// 面板里除了色格之外的固定高度：上下内边距 + 顶栏 + 顶栏和色格之间那道间距
    static let panelChrome: CGFloat = 14 + headerHeight + 12 + 14
    /// 面板左右内边距之和
    static let panelInset: CGFloat = 28

    /// 格子是正方形、边长 = 面板内宽 / 12，所以面板高度跟着屏宽走
    static func panelHeight(width: CGFloat) -> CGFloat {
        let cell = (width - panelInset) / CGFloat(gridColumns)
        return panelChrome + cell * CGFloat(gridRows)
    }

    /// `panelHeight` 的反函数：给定能用的高度，算出面板最宽能给到多宽。
    /// 色格是正方形，所以面板高度是被宽度决定的——想限高只能限宽，没有别的旋钮。
    static func panelWidth(fitting height: CGFloat) -> CGFloat {
        let cell = max((height - panelChrome) / CGFloat(gridRows), 0)
        return cell * CGFloat(gridColumns) + panelInset
    }
    private var pickedColor: Color { Self.gridColor(pickerCell) }

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
            // 摊成 90° 时不再分两屏来回切：上半屏看词 + 计分，下半屏直接就是画板，
            // 这正是折叠屏能做而直板做不了的事
            if hinge.isLaptopPosture {
                laptopBody
            } else if showCanvas {
                canvasBody
            } else {
                wordBody
            }
        }
        .onChange(of: hinge.isLaptopPosture) { _, laptop in
            if laptop {
                // 折起来：画板和词同屏，不再需要「开始作画」这个开关。
                // 先记住折之前停在哪一页，摊开时好还回去
                canvasBeforeFold = showCanvas
                showCanvas = false
            } else {
                // 摊开：还原到折之前那一页。不还原的话，正画到一半把手机摊开会被踢回
                // 看词页，要重新点一次「开始作画」才拿得回画板，而表还在走。
                // 只看「折之前在哪一页」不够：从看词页折起来、在折叠画板上画完再摊开，
                // 折之前那一页是看词页，照样会被踢回去——画过就说明人在画板上
                showCanvas = canvasBeforeFold || !strokes.isEmpty
            }
        }
        .onAppear {
            remaining = store.roundDuration
            skipsLeft = store.skipAllowance
            if word.isEmpty { word = store.nextWord() }
            if store.settings.privacyGuardOn { motion.start() }
            // 外屏这一页镜像画板，计时缩到右上角
            CoverScreenModel.shared.mode = .drawing
            CoverScreenModel.shared.sync(remaining: remaining, total: store.roundDuration)
            CoverScreenModel.shared.syncStrokes(strokes)
            CoverScreenModel.shared.enabled = true
            CoverScreenCamera.shared.start()
            if let m = ScreenshotMode.mode, ["draw", "drawcanvas", "drawpicker"].contains(m) {
                word = LanguageManager.shared.language == .en ? "snowman" : "雪人"
                ownPoints = 2
                if m != "draw" {
                    strokes = ScreenshotMode.demoStrokes()
                    showCanvas = true
                }
                if m == "drawpicker" {
                    // 录屏脚本用：停一下 → 展开 → 点橙色那格（点完自己收起），两个动画都录进去。
                    // 先停 2 秒：刚启动时主线程还忙，停太短的话这几段会被挤到一起一口气跑完
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        usingCustom = true
                        withAnimation(Self.pickerSpring) { pickerOpen = true }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                        pickGridColor(4 * Self.gridColumns + 1)
                    }
                }
            }
        }
        .onDisappear {
            motion.stop()
            CoverScreenModel.shared.enabled = false
            CoverScreenModel.shared.mode = .question
            CoverScreenModel.shared.clearDrawing()
            CoverScreenCamera.shared.stop()
        }
        .onReceive(timer) { _ in
            guard remaining > 0, !store.turnPaused else { return }
            remaining -= 1
            CoverScreenModel.shared.sync(remaining: remaining, total: store.roundDuration)
            if remaining == 0 {
                FeedbackManager.shared.timeUp()
                store.finishPlay(own: ownPoints, stolen: stolenPoints)
            } else if remaining <= 5 {
                FeedbackManager.shared.countdownTick()
            }
        }
    }

    // MARK: 工具栏（竖屏和 90° 分屏共用）

    private var toolbar: some View {
        // 6色 + 自选色 + 橡皮 + 3档粗细 + 撤销/清空
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
                    CoverScreenModel.shared.syncStrokes(strokes)
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title3)
                }
                Button {
                    FeedbackManager.shared.skip()
                    strokes.removeAll()
                    // 一张都不剩了，作画区的比例也该放开，重新按当下的白板来
                    boardAspect = 0
                    CoverScreenModel.shared.clearDrawing()
                    eraserOn = false
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)
    }

    // MARK: 90° 笔记本布局（上半屏看词 + 计分，下半屏画板 + 工具）

    /// 摊成 90° 时，画板和词语同时在屏上——不用再来回按「开始作画 / 收起画布」。
    /// 下半屏平躺着正好当画板，上半屏立着朝自己显示词和按钮，外屏同时把画面给对面看。
    private var laptopBody: some View {
        CreaseSplit {
            laptopTopPane
        } bottom: {
            laptopBottomPane
        }
    }

    private var laptopTopPane: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HomeExitButton()
                TimerRing(remaining: remaining, total: store.roundDuration, size: 44)
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
                CoverScreenPill()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            Spacer(minLength: 0)

            if store.isRotation {
                GuesserRing(onGuess: creditGuess) { laptopWordCard }
            } else {
                laptopWordCard
            }

            Spacer(minLength: 0)

            // 计分按钮：没有「开始作画」，因为画板就在下面
            VStack(spacing: 8) {
                if store.isRotation {
                    EmptyView()
                } else if store.openBuzz {
                    HStack(spacing: 10) {
                        correctButton(compactLabel: true, tall: false)
                        Button {
                            FeedbackManager.shared.buzz()
                            stolenPoints += 1
                            nextDrawing(guessed: true)
                        } label: {
                            Label(L("draw.sniped"), systemImage: "bolt.fill")
                        }
                        .buttonStyle(BigButtonStyle(colors: [.red, .orange], font: .headline))
                    }
                } else {
                    correctButton(compactLabel: false, tall: false)
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
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    /// 上半屏的词卡：比竖屏那张矮，因为这半屏只有一半高度
    private var laptopWordCard: some View {
        VStack(spacing: 6) {
            Text(L("draw.artist_only"))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
            Text(word)
                .font(.system(size: word.count > 6 ? 32 : 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, store.isRotation ? 14 : 20)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(game.gradient)
                .shadow(color: game.colors[0].opacity(0.45), radius: 12, y: 5)
        )
        .padding(.horizontal, 20)
    }

    /// ⚠️ `canvasSpace` 这个坐标系必须钉在**色盘层所在的那一层**上。
    /// 色盘是用 `swatchRect`（在 `canvasSpace` 里量的按钮位置）定位的，而它自己的
    /// `GeometryReader` 用的是本地坐标——两者原点不同的话，面板就会整体偏掉。
    /// 以前坐标系挂在 `CreaseSplit` 外面（整屏），色盘层却在下半屏里，原点差了
    /// 一整个上半屏的高度，于是面板被推到屏幕下面去了，看着就是「点了没反应」。
    private var laptopBottomPane: some View {
        ZStack {
            VStack(spacing: 8) {
                drawingCanvas
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                toolbar
                    .padding(.bottom, 10)
            }
            colorPickerLayer
        }
        .coordinateSpace(name: Self.canvasSpace)
        .onPreferenceChange(SwatchRectKey.self) { swatchRect = $0 }
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

            FoldHintPill()

            if store.catchUp.isActive {
                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)
            }

            if store.isRotation {
                // 轮流模式：其他人的名字围着词，谁猜对点谁
                Spacer(minLength: 0)
                GuesserRing(onGuess: creditGuess) { wordCard }
                Spacer(minLength: 0)
            } else {
                Spacer()
                wordCard
                Spacer()
            }

            // 开始作画 + 计分按钮（只在看词界面）
            VStack(spacing: 10) {
                Button {
                    FeedbackManager.shared.tap()
                    showCanvas = true
                } label: {
                    Label(L("draw.start_drawing"), systemImage: "paintbrush.pointed.fill")
                }
                .buttonStyle(BigButtonStyle(colors: game.colors))

                if store.isRotation {
                    EmptyView()
                } else if store.openBuzz {
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

    /// 词卡 / 防窥屏
    @ViewBuilder private var wordCard: some View {
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
            // 轮流模式上下还要排两圈名字，词卡压矮一点
            .padding(.vertical, store.isRotation ? 26 : 38)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(game.gradient)
                    .shadow(color: game.colors[0].opacity(0.45), radius: 14, y: 6)
            )
            .padding(.horizontal, 24)
        }
    }

    /// 轮流模式：表演者点了某个人的名字，两人各 +1，换下一个词
    private func creditGuess(_ guesser: UUID) {
        FeedbackManager.shared.correct()
        ownPoints += 1
        store.creditGuess(by: guesser)
        nextDrawing(guessed: true, mark: false, guesser: guesser)
    }

    /// `tall` 只在竖屏给：竖屏时这颗按钮是拇指落点，加高好按。摊成 90° 之后它跑到
    /// 立起来的上半屏上，谁也不会把拇指搁在那儿，而上半屏的高度要分给词卡和折痕留白。
    private func correctButton(compactLabel: Bool, tall: Bool = true) -> some View {
        Button {
            FeedbackManager.shared.correct()
            ownPoints += 1
            nextDrawing(guessed: true)
        } label: {
            Label(compactLabel ? L("play.correct_us") : L("draw.correct_plain"),
                  systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(BigButtonStyle(colors: [.green, .mint], font: .headline, tall: tall))
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

            toolbar

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
            // 面板往按钮正上方长，所以能用的高度就是按钮上沿往上那一段。
            // 竖屏时这段很宽裕，限制来自屏宽；90° 时只有半块屏，限制来自高度——
            // 以前这里写的是「笔记本模式就把宽度压到 520」，那是个猜的数：
            // 真机内屏上 520 宽算出来的面板有 400pt 高，比下半屏能给的还高。
            // 既然高度是被宽度决定的，就直接从剩余高度反推宽度，两种姿态同一个公式。
            let room = swatchRect.minY - 14 - Self.panelTopMargin
            let byHeight = max(Self.panelWidth(fitting: room), Self.panelMinWidth)
            let panelWidth = min(geo.size.width - 24, byHeight)
            let panelH = Self.panelHeight(width: panelWidth)
            let target = CGRect(x: (geo.size.width - panelWidth) / 2,   // 压窄之后要居中，不然贴着左边
                                y: max(swatchRect.minY - 14 - panelH, Self.panelTopMargin),
                                width: panelWidth,
                                height: panelH)
            // 按钮中间那颗 16pt 的色点：水滴从这里长出来，收起时也缩回这里
            let dot = CGRect(x: swatchRect.midX - 8, y: swatchRect.midY - 8, width: 16, height: 16)

            ZStack {
                // 点画布上别的地方也收起。
                // 90° 时不能 ignoresSafeArea：这一层活在下半屏里，放它出去会漫过折痕，
                // 把本该空着的那条缝糊上一层灰
                Color.black.opacity(pickerOpen ? 0.18 : 0)
                    .ignoresSafeArea(edges: hinge.isLaptopPosture ? [] : .all)
                    .allowsHitTesting(pickerOpen)
                    .onTapGesture { closePicker() }

                pickerPanel(width: panelWidth)
                    .frame(width: panelWidth, height: panelH)   // 内容始终按最终尺寸布局，动画里只是被裁掉
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
            .frame(height: Self.headerHeight)
            colorGrid(width: width - 28)
        }
        .padding(14)
    }

    /// 色盘本体：点哪格就是哪个颜色，白框滑到那一格。
    /// 96 格画在一个 Canvas 里、点击按坐标换算成格子：水滴动画每一帧都要重新排版面板，一格一个 view 的话太重
    private func colorGrid(width: CGFloat) -> some View {
        let cell = width / CGFloat(Self.gridColumns)
        return Canvas { context, _ in
            for index in 0..<(Self.gridRows * Self.gridColumns) {
                // 多画半个点压住右边和下边的邻格，小数格宽时格子之间才不会透出细缝
                let rect = CGRect(x: CGFloat(index % Self.gridColumns) * cell,
                                  y: CGFloat(index / Self.gridColumns) * cell,
                                  width: cell + 0.5, height: cell + 0.5)
                context.fill(Path(rect), with: .color(Self.gridColor(index)))
            }
        }
        .frame(width: width, height: cell * CGFloat(Self.gridRows))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { location in
            let col = min(max(Int(location.x / cell), 0), Self.gridColumns - 1)
            let row = min(max(Int(location.y / cell), 0), Self.gridRows - 1)
            pickGridColor(row * Self.gridColumns + col)
        }
        .overlay(alignment: .topLeading) {
            // 选中框画在裁切外面，角上的格子才不会被圆角切掉一半；白框外面再描一圈暗边，选白色时也看得见
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(.white, lineWidth: 3)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.black.opacity(0.35), lineWidth: 1))
                .frame(width: cell + 4, height: cell + 4)
                .offset(x: CGFloat(pickerCell % Self.gridColumns) * cell - 2,
                        y: CGFloat(pickerCell / Self.gridColumns) * cell - 2)
                .animation(.spring(duration: 0.25, bounce: 0.2), value: pickerCell)
                .allowsHitTesting(false)
        }
    }

    /// 点一格：换成这个颜色，停一下让人看到白框移过去，再自己缩回按钮
    private func pickGridColor(_ index: Int) {
        FeedbackManager.shared.tap()
        pickerCell = index
        usingCustom = true
        eraserOn = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard pickerOpen else { return }
            withAnimation(Self.pickerSpring) { pickerOpen = false }
        }
    }

    private var drawingCanvas: some View {
        GeometryReader { geo in
            // 这个词的作画区：长宽比在 pinBoard 里钉死，这里只是把它等比放进当前这块地方
            let board = CanvasFit.box(aspect: boardAspect > 0 ? boardAspect
                                                              : Self.aspect(of: geo.size),
                                      in: geo.size)
            Canvas { context, size in
                context.translateBy(x: board.minX, y: board.minY)
                // 和外屏裁同一刀。不裁的话，作画区以外也画得上去、这边看得见，
                // 外屏却照不出来——用户看到的就是「上面被切掉一块」
                context.clip(to: Path(roundedRect: CGRect(origin: .zero, size: board.size),
                                      cornerRadius: 22))
                for stroke in strokes {
                    context.stroke(Self.path(for: stroke.points, in: board.size),
                                   with: .color(stroke.color),
                                   style: StrokeStyle(lineWidth: stroke.lineWidth,
                                                      lineCap: .round, lineJoin: .round))
                }
                if let s = currentStroke {
                    context.stroke(Self.path(for: s.points, in: board.size),
                                   with: .color(s.color),
                                   style: StrokeStyle(lineWidth: s.lineWidth,
                                                      lineCap: .round, lineJoin: .round))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // 落点按**作画区**归一化，不是按整块可用区域：
                        // 折一下摊一下，作画区的形状不变，已经画好的线也就不会被切
                        let local = CGPoint(x: value.location.x - board.minX,
                                            y: value.location.y - board.minY)
                        let p = CanvasSpace.normalize(local, in: board.size)
                        if currentStroke == nil {
                            // 第一笔落下的这一刻才锁死作画区的比例（见 pinBoardIfNeeded）。
                            // 此刻 board 就是整块白板，所以锁的是它自己的比例，形状不变
                            pinBoardIfNeeded(geo.size)
                            currentStroke = Stroke(points: [p],
                                                   color: brushColor,
                                                   lineWidth: brushWidth)
                        } else {
                            currentStroke?.points.append(p)
                        }
                        // 外屏跟着笔尖走：只推这一笔，不动已完成的数组
                        CoverScreenModel.shared.syncLive(currentStroke)
                    }
                    .onEnded { _ in
                        if let s = currentStroke { strokes.append(s) }
                        currentStroke = nil
                        CoverScreenModel.shared.syncLive(nil)
                        CoverScreenModel.shared.syncStrokes(strokes)
                    }
            )
            // 外屏要知道这块画板有多宽多高才镜像得全——笔画存的是归一化坐标，
            // 光有点算不出画板边界在哪（见 CoverScreenModel.canvasAspect）
            .onAppear { reportBoard(geo.size) }
            .onChange(of: geo.size) { _, size in reportBoard(size) }
        }
    }

    private static func aspect(of size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return size.width / size.height
    }

    /// 告诉外屏当前作画区是什么比例。还没钉的时候就是整块白板。
    private func reportBoard(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        CoverScreenModel.shared.canvasAspect =
            boardAspect > 0 ? boardAspect : Self.aspect(of: size)
    }

    /// **落笔那一刻**才把作画区的长宽比钉下来，这个词剩下的时间里都不再变。
    ///
    /// 以前是第一次量到尺寸就钉（`onAppear`），钉的往往是一个中间态的尺寸：
    /// 版面落定之后白板变了形，而作画区还是旧比例，于是它成了白板里居中的一小块。
    /// 白板那一圈margin 照样画得上去、内屏也看得见，外屏却裁掉了——
    /// 用户看到的就是「外屏上面不全」。
    ///
    /// 改成落笔时钉：没动笔之前作画区**就是**整块白板（没有 margin，不可能画到框外），
    /// 一旦开始画就锁死，之后折叠/摊开只让这块方框整体缩放，笔画一个点都不会跑掉。
    private func pinBoardIfNeeded(_ size: CGSize) {
        guard boardAspect <= 0, size.width > 0, size.height > 0 else { return }
        boardAspect = Self.aspect(of: size)
        CoverScreenModel.shared.canvasAspect = boardAspect
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
    /// mark = false：这个词已经记过账了（轮流模式点名字时连猜对的人一起记了）
    /// guesser：轮流模式下点中名字的那个人，外屏要报出这一分记给了谁
    private func nextDrawing(guessed: Bool, mark: Bool = true, guesser: UUID? = nil) {
        if mark { store.markCurrentWord(guessed: guessed) }
        // 换词也要让外屏闪一下：对面看不到这块屏，不说的话他们还在猜上一个词
        if guessed { CoverScreenModel.shared.flashCorrect(store.coverScorers(guesser: guesser)) }
        else { CoverScreenModel.shared.flashSkip() }
        word = store.nextWord()
        strokes.removeAll()
        currentStroke = nil
        boardAspect = 0          // 新的词，重新按当时的姿态钉一次
        CoverScreenModel.shared.clearDrawing()
        eraserOn = false
        showCanvas = false
        forceShow = false
    }
}

// MARK: - 按钮位置

/// 自选色按钮在画布坐标系里的位置，色盘靠它决定从哪儿长出来
struct SwatchRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    /// 只有自选色按钮会写这个值。没写的兄弟视图（比如排在后面、里面有 ForEach 的色盘层）会带着默认的 .zero
    /// 一起参与合并，直接 value = nextValue() 的话按钮的位置会被 .zero 盖掉，色盘就一直不显示
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
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

    /// 竖直方向先走、水平方向后走（前 0.05 秒左右是一滴 30×80 左右的竖水滴）。
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
