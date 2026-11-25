import SwiftUI
import AVFoundation

/// 外屏（折叠时朝外的那块小屏）要显示的内容。
///
/// **为什么要开相机会话：** iOS 27 想往外屏放东西只有 `UISceneAccessory` 一条路，
/// 而它只有两个工厂方法——`externalNonInteractive` 是给 HDMI / AirPlay 外接显示器的，
/// `cameraCapture` 的门槛在头文件里写得很死：
/// "while the app is in the foreground and **has an active camera capture session**"。
/// 真机实测过：不开会话时系统报 `isAvailable = false`，折到 90° 也一样。
///
/// 所以这里开一个**不显示、不保存、不读取画面**的最小会话，纯粹用来满足那个条件。
/// 代价是相机权限、状态栏绿点和一点耗电，提交时要在 App Review Notes 里讲清楚。
///
/// 曾经试过让它真的派上用场——在内屏计时旁边挂一个小窗显示朝外那颗镜头拍到的画面。
/// 放弃了：真机上 `position: .front` 的两颗（`built-in_video:1` 广角、`:8` 超广角）
/// **都是内屏那颗**，外屏那颗在展开状态下根本枚举不到，没法稳定地挑中它。
/// 既然画面不显示，帧就一帧都不解（见 `DiscardingSink`）。
@MainActor
final class CoverScreenModel: ObservableObject {
    static let shared = CoverScreenModel()

    /// 外屏这一刻该显示什么
    enum Mode {
        /// 说/演/唇语这类：一个大问号 + 剩余秒数，给对面猜的人看
        case question
        /// 你画我猜：实时镜像画板，计时缩到右上角
        case drawing
    }

    /// 系统是否允许现在往外屏放内容。
    @Published var isAvailable = false
    /// 这一刻想不想用外屏。只在玩法页打开——没必要让外屏在菜单上亮着一个过期的计时。
    @Published var enabled = false
    @Published var mode: Mode = .question

    // 外屏要显示的游戏状态，由玩法页推进来
    @Published var remaining = 0
    @Published var total = 60
    /// 每答对一次 +1，外屏据此播一次动画。
    @Published var correctPulse = 0
    /// 每换一次词 +1。换词也得让外屏知道，不然对面还在猜上一个词。
    @Published private(set) var skipPulse = 0

    /// 这一分算在谁头上。外屏朝着猜的人，他们看不到内屏那块记分板——
    /// 只闪一个对勾的话，他们知道「对了」，但不知道分记给了谁。
    /// 轮流模式一次进两个人（猜对的 + 表演的），所以是个数组。
    @Published private(set) var scorers: [Scorer] = []

    struct Scorer: Equatable, Identifiable {
        var emoji: String
        var name: String
        var points: Int = 1
        var id: String { emoji + name }
    }

    /// 内屏那块画板的长宽比（宽 / 高）。
    ///
    /// 为什么外屏需要这个数：笔画存的是归一化坐标，原点在画板中心、单位是画板**短边**
    /// （见 `CanvasSpace`）。这个归一化保住了比例，但没保住**范围**——一块宽扁的画板
    /// 归一化之后 x 会跑到 ±0.9，而同一套点画到外屏这块窄高的屏上，x 要乘外屏短边（宽），
    /// 于是左右各溢出一截，画面被切掉。真机内屏实测：90° 时画板约 645×350（比例 1.84），
    /// 镜到 466 宽的外屏上两边各丢 196pt，接近画面宽度的四成。
    ///
    /// 所以外屏得知道源画板的方框有多扁，才能把整块方框等比缩进自己的可视区里。
    @Published var canvasAspect: CGFloat = 1

    /// 已经画完的笔画。只在一笔结束时整体更新——每个点都发布整个数组的话代价是 O(n)。
    @Published var strokes: [Stroke] = []
    /// 正在画的那一笔，单独发布：它很短，每个点推一次也不贵，外屏才跟得上笔尖。
    @Published var liveStroke: Stroke?

    private init() {}

    func sync(remaining: Int, total: Int) {
        if self.remaining != remaining { self.remaining = remaining }
        if self.total != total { self.total = total }
    }

    /// 答对了：外屏闪一下，并报出得分的是谁。
    /// `scorers` 为空时只闪，不报名字——截图脚本和老调用点走的就是这条。
    func flashCorrect(_ scorers: [Scorer] = []) {
        self.scorers = scorers
        correctPulse += 1
    }

    /// 换词了：外屏闪一下并报一句，所有玩法都要。
    func flashSkip() { skipPulse += 1 }

    /// 一笔结束 / 撤销 / 清空时调用——这时候才整体换数组。
    /// 别拿 count 去判断「变没变」：撤销一笔再画一笔，count 是一样的。
    func syncStrokes(_ strokes: [Stroke]) { self.strokes = strokes }

    /// 笔尖移动时调用，只发布正在画的这一笔。
    func syncLive(_ stroke: Stroke?) { liveStroke = stroke }

    /// 画板尺寸变了（折叠 / 展开 / 转屏）时调用。只有比例有用，绝对尺寸外屏不关心。
    func syncCanvas(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let aspect = size.width / size.height
        if abs(canvasAspect - aspect) > 0.001 { canvasAspect = aspect }
    }

    func clearDrawing() {
        strokes = []
        liveStroke = nil
    }
}

extension GameStore {
    /// 外屏那句「谁加了分」要报谁。
    /// 队伍模式：这一分记在执机队头上。
    /// 轮流模式：猜对的人和表演的人各 +1（见 `GameStore.creditGuess`），两个都报，
    /// 猜对的那个排前面——对面最想知道的是「刚才是谁猜中的」。
    func coverScorers(guesser: UUID? = nil) -> [CoverScreenModel.Scorer] {
        // 快速模式不分队、也不记大分，报「某某 +1」没有意义——外屏只闪一个对勾
        if soloMode { return [] }
        guard isRotation else {
            return [.init(emoji: playingTeam.emoji, name: playingTeam.name)]
        }
        var list: [CoverScreenModel.Scorer] = []
        if let guesser, let p = players.first(where: { $0.id == guesser }) {
            list.append(.init(emoji: Player.emoji(p.avatar), name: p.name))
        }
        list.append(.init(emoji: Player.emoji(performer.avatar), name: performer.name))
        return list
    }
}

// MARK: - 只为解锁外屏而存在的相机会话

/// 一个不出画面的 `AVCaptureSession`。
///
/// 没有预览层，没有照片输出，视频帧收到就扔。它存在的唯一目的是让系统认为
/// "这个 App 正在用相机"，从而放行 `cameraCapture` 这路外屏内容。
@MainActor
final class CoverScreenCamera: ObservableObject {
    static let shared = CoverScreenCamera()

    @Published private(set) var isRunning = false
    @Published private(set) var denied = false
    /// 系统权限弹窗正挂在屏上。弹窗期间回合表要停——
    /// 否则第一支队伍的时间在一个他们还没读完的弹窗后面空烧
    @Published private(set) var isRequesting = false

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "coverscreen.capture")
    private let sink = DiscardingSink()
    private var configured = false
    /// 玩法页希望外屏亮着。真开不开还要看这台机器有没有铰链（见 `evaluate`）
    private var wanted = false

    private init() {}

    /// 玩法页进场时调。**不保证真的开**——没有铰链的机器一个字都不会问。
    func start() {
        wanted = true
        evaluate()
    }

    /// 铰链状态变了之后由 `HingeMonitor` 调一次。
    ///
    /// 为什么需要这一下：铰链状态要等 `UIHingeInteraction` 第一次回调才知道，
    /// 而玩法页的 `onAppear` 往往跑在它前面。只在 `start()` 里判断的话，
    /// 折叠机上第一局永远开不了会话。
    func hingeAvailabilityChanged() { evaluate() }

    private func evaluate() {
        guard wanted else { return }
        // **没有铰链就没有外屏**，也就没有任何理由碰相机。普通 iPhone 上这条路
        // 永远走不到：不弹权限、状态栏不亮绿点、审核也不用解释。
        guard HingeMonitor.shared.status != .unavailable else { return }
        requestAndStart()
    }

    private func requestAndStart() {
#if DEBUG
        // 截图/录屏自动化用：模拟器上的相机权限弹窗 grant 之后还会赖着不走，挡住版面。
        // 外屏在模拟器上本来也不可能亮，跳过相机不影响任何要验的东西。
        if ProcessInfo.processInfo.environment["SKIP_CAMERA"] == "1" { return }
#endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            reallyStart()
        case .notDetermined:
            isRequesting = true
            AVCaptureDevice.requestAccess(for: .video) { ok in
                Task { @MainActor in
                    self.isRequesting = false
                    if ok { self.reallyStart() } else { self.denied = true }
                }
            }
        default:
            denied = true
        }
    }

    func stop() {
        wanted = false
        guard isRunning else { return }
        isRunning = false
        let session = session
        queue.async { session.stopRunning() }
    }

    private func reallyStart() {
        denied = false
        guard !isRunning else { return }
        isRunning = true
        let session = session
        let sink = sink
        let needsConfig = !configured
        configured = true
        queue.async {
            if needsConfig {
                session.beginConfiguration()
                // 最低档画质：这些帧谁都不看，没必要为它花电
                session.sessionPreset = .low
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                }
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(sink, queue: self.queue)
                if session.canAddOutput(output) { session.addOutput(output) }
                session.commitConfiguration()
            }
            session.startRunning()
        }
    }
}

/// 收到帧就丢掉——一帧都不留，不解码、不转存。
private final class DiscardingSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {}
}

// MARK: - 外屏上画什么

/// 外屏：一个大问号 + 当前剩余秒数，答对时整屏闪一下。
///
/// 外屏很小（466×678pt，右侧还有 84pt 的系统安全区），所以只放这两样东西，字要够大，
/// 隔着一张桌子也看得清。
struct CoverScreenContent: View {
    @ObservedObject private var model = CoverScreenModel.shared
    @State private var flash: CoverFlash?
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            switch model.mode {
            case .question: QuestionFace(flash: flash)
            case .drawing:  DrawingFace()
            }

            // 答对 / 换词：整屏压一层色 + 一个大符号 + 一句话。
            // 问号那一面自己会换底色换符号（见 QuestionFace），所以这一层只给画板那一面
            if let flash, model.mode == .drawing {
                ZStack {
                    LinearGradient(colors: flash.colors, startPoint: .top, endPoint: .bottom)
                        .opacity(0.92)
                        .ignoresSafeArea()
                    VStack(spacing: 22) {
                        Image(systemName: flash.symbol)
                            .font(.system(size: 150, weight: .black))
                            .foregroundStyle(.white)
                        FlashCaption(flash: flash, scorers: model.scorers)
                    }
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .onChange(of: model.correctPulse) { _, _ in show(.correct) }
        .onChange(of: model.skipPulse) { _, _ in show(.skip) }
    }

    /// 收尾的任务要能被下一次取消。连着两下（间隔不到 850ms，答对接着换词也算）时，
    /// 第一次那个计时会把第二次提前掐掉——屏上就是两个符号半透明叠在一起，
    /// 底下那句话也只闪半下。每次重新计时才对
    private func show(_ kind: CoverFlash) {
        resetTask?.cancel()
        withAnimation(.spring(duration: 0.28)) { flash = kind }
        resetTask = Task {
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { flash = nil }
        }
    }
}

/// 外屏上那一闪是什么事：答对，或者换词。颜色跟内屏那两个按钮对上，
/// 对面看一眼颜色就知道发生了什么，不用读字
enum CoverFlash: Hashable {
    case correct
    case skip

    var colors: [Color] {
        switch self {
        case .correct: return [.green, .mint]
        case .skip:    return [.orange, .yellow]
        }
    }

    /// 用 SF Symbol 而不是 emoji：emoji 自带配色，压在同色背景上会糊成一团
    var symbol: String {
        switch self {
        case .correct: return "checkmark"
        case .skip:    return "arrow.uturn.right"
        }
    }
}

/// 大符号下面那一句。
/// 答对报「谁加了分」；快速模式不记分，`scorers` 是空的，那一下就只有对勾
/// （见 `GameStore.coverScorers`）。换词报一句「换词」，所有玩法一样。
private struct FlashCaption: View {
    let flash: CoverFlash
    let scorers: [CoverScreenModel.Scorer]

    var body: some View {
        switch flash {
        case .correct: ScorerBadge(scorers: scorers)
        case .skip:    CoverCapsule(text: L("cover.skipped"))
        }
    }
}

/// 说 / 演 / 唇语：一个大问号 + 剩余秒数。隔着一张桌子要看得清，所以字给到最大。
private struct QuestionFace: View {
    @ObservedObject private var model = CoverScreenModel.shared
    /// 非 nil 就是正在闪那一下（答对或换词），底色和符号整套跟着换
    let flash: CoverFlash?

    private var urgent: Bool { model.remaining <= 5 && model.remaining > 0 }

    private var background: LinearGradient {
        if let flash {
            return LinearGradient(colors: flash.colors, startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color(red: 0.11, green: 0.09, blue: 0.20),
                                       Color(red: 0.05, green: 0.04, blue: 0.11)],
                              startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 24) {
                // 用 SF Symbol 而不是 ❓/✅ 两个 emoji：emoji 自带配色，
                // ✅ 的绿底压在绿背景上糊成一团。白色符号在几种背景上都清楚。
                //
                // 换符号必须硬切，否则两个字形会半透明叠在一起，糊成一个谁也认不出的形状。
                // 原来写的是 contentTransition(.identity)，模拟器上实测**没挡住**——
                // 状态稳定之后两个字形还是各半，所以改成换 id 整个替换掉这个视图，
                // 再用 transition(.identity) 掐掉插入/移除的淡入淡出
                Image(systemName: flash?.symbol ?? "questionmark")
                    .font(.system(size: 150, weight: .black))
                    .foregroundStyle(.white)
                    .id(flash)
                    .transition(.identity)
                    .scaleEffect(flash != nil ? 1.15 : 1)

                Text("\(model.remaining)")
                    .font(.system(size: 104, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(flash == nil && urgent ? Color.red : .white)
                    .scaleEffect(urgent && flash == nil ? 1.1 : 1)
                    .animation(.spring(duration: 0.25), value: model.remaining)

                if let flash {
                    FlashCaption(flash: flash, scorers: model.scorers)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
    }
}

/// 外屏上那句话的底板。字要够大，隔着一张桌子看得清
private struct CoverCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.22)))
            .padding(.horizontal, 14)
    }
}

/// 「谁加了分」：答对那一下压在对勾下面报一句。
///
/// 一行一个人——轮流模式猜对的和表演的各得一分，两个都要报（猜对的在上面）。
/// 名字是用户自己起的，可能很长，所以单行 + 缩字号，不换行把版面撑开。
private struct ScorerBadge: View {
    let scorers: [CoverScreenModel.Scorer]

    var body: some View {
        if !scorers.isEmpty {
            VStack(spacing: 8) {
                ForEach(scorers) { s in
                    HStack(spacing: 10) {
                        Text(s.emoji).font(.system(size: 34))
                        Text(s.name)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(verbatim: "+\(s.points)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.22)))
                }
            }
            .padding(.horizontal, 14)
        }
    }
}

/// 你画我猜：实时镜像画板，计时缩到右上角。
///
/// 笔画存的是归一化坐标（原点在画布中心、单位是短边），作画区的长宽比在一个词之内
/// 钉死（见 `CanvasFit`），所以内屏那块宽扁的画板和外屏这块屏可以用同一组点，
/// 等比放进来就行，比例不会走样、也不会被切。
private struct DrawingFace: View {
    @ObservedObject private var model = CoverScreenModel.shared

    /// 画板铺满整块外屏，所以底色就是画板自己的白——对面看到的是一整张白纸。
    /// 「画满了没」靠笔画本身说话，不靠给画板画个边框
    private static let board = Color.white
    /// 笔画的裁切圆角，跟内屏那块画板对齐
    private static let corner: CGFloat = 18

    var body: some View {
        ZStack {
            Self.board.ignoresSafeArea()

            // 白底和笔画得分两层：底色可以铺出屏幕，笔画不行。
            // 外屏右侧有一条系统安全区（真机实测 84pt），画到那儿的笔画看不到，
            // 所以这一层故意**不** ignoresSafeArea，笔画只在可视区里等比缩放
            Canvas { context, size in
                let box = CanvasFit.box(aspect: model.canvasAspect, in: size)
                // 内屏那块画板是 clipShape 过的，这里也裁一刀，两块屏才是同一张画
                context.clip(to: Path(roundedRect: box, cornerRadius: Self.corner))
                context.translateBy(x: box.minX, y: box.minY)
                for stroke in model.strokes { Self.draw(stroke, in: &context, size: box.size) }
                if let live = model.liveStroke { Self.draw(live, in: &context, size: box.size) }
            }

            // 还没落笔时给对面一句提示，不然外屏就是一块白板
            if model.strokes.isEmpty && model.liveStroke == nil {
                VStack(spacing: 10) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 44, weight: .semibold))
                    Text(L("cover.waiting_for_drawing"))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color(.systemGray3))
            }
        }
        .overlay(alignment: .topTrailing) { CoverTimerPill(remaining: model.remaining) }
    }

    private static func draw(_ stroke: Stroke, in context: inout GraphicsContext, size: CGSize) {
        context.stroke(DrawView.path(for: stroke.points, in: size),
                       with: .color(stroke.color),
                       style: StrokeStyle(lineWidth: stroke.lineWidth,
                                          lineCap: .round, lineJoin: .round))
    }
}

/// 右上角的小计时。白画布上要压得住，所以是实心深色胶囊。
private struct CoverTimerPill: View {
    let remaining: Int

    private var urgent: Bool { remaining <= 5 && remaining > 0 }

    var body: some View {
        Text("\(remaining)")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(urgent ? Color.red : Color.black.opacity(0.78)))
            .scaleEffect(urgent ? 1.08 : 1)
            .animation(.spring(duration: 0.25), value: remaining)
            .padding(.top, 10)
            .padding(.trailing, 14)
    }
}

// MARK: - 内屏上的小指示器

/// 告诉执机人「对面那块屏现在亮着、他们看得到」。
/// 这件事没有提示的话没人知道——外屏朝外，画的人根本看不见。
struct CoverScreenPill: View {
    @ObservedObject private var model = CoverScreenModel.shared

    var body: some View {
        if model.enabled && model.isAvailable {
            HStack(spacing: 5) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 11, weight: .bold))
                Text(L("cover.live"))
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.green.opacity(0.9)))
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - 挂到视图上

extension View {
    /// 把外屏内容注册给系统。`.sceneAccessory` 是 iOS 27.0，`CameraCaptureAccessory` 是 27.1。
    ///
    /// 注册一次就够了，开关交给 `isEnabled`——系统自己决定什么时候真的显示。
    @ViewBuilder
    func coverScreen(enabled: Binding<Bool>) -> some View {
        if #available(iOS 27.1, *) {
            self.sceneAccessory {
                CameraCaptureAccessory(isEnabled: enabled) { CoverScreenContent() }
                    .onAvailabilityChange { available in
                        CoverScreenModel.shared.isAvailable = available
                    }
            }
        } else {
            self
        }
    }
}
