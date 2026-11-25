import SwiftUI

/// 折叠玩法的教学。
///
/// 这个模式有个天然的发现问题：**没人会主动去折手机试试**。而且外屏朝外，
/// 执机人自己看不到那块屏，不告诉他的话他不知道对面已经能看见了。
/// 所以分两步：没折的时候给一句轻提示，第一次真折起来时给一张完整说明。
@MainActor
enum FoldTutorial {
    private static let introKey = "foldIntroSeen"
    private static let hintCountKey = "foldHintShown"
    /// 轻提示最多出现几轮就不再烦人
    private static let maxHints = 3

    static var hasSeenIntro: Bool {
        get { UserDefaults.standard.bool(forKey: introKey) }
        set { UserDefaults.standard.set(newValue, forKey: introKey) }
    }

    private static var hintCount: Int {
        get { UserDefaults.standard.integer(forKey: hintCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: hintCountKey) }
    }

    /// 这台机器有没有铰链——没有的话一个字都别提，免得普通 iPhone 用户看了困惑
    static var deviceCanFold: Bool {
        HingeMonitor.shared.status != .unavailable
    }

    static var shouldShowHint: Bool {
        deviceCanFold && !hasSeenIntro && hintCount < maxHints
    }

    static func noteHintShown() { hintCount += 1 }

    /// 把教学重新武装：下次折到 90° 再讲一遍。
    /// 轻提示的计数也一起清掉——想重看的人多半是忘了怎么玩，那条提示对他同样有用
    static func rearmIntro() {
        hasSeenIntro = false
        hintCount = 0
    }
}

// MARK: - 没折的时候：一句轻提示

/// 玩法页顶部的小提示，告诉用户还有这么个玩法。点一下就不再出现。
struct FoldHintPill: View {
    @ObservedObject private var hinge = HingeMonitor.shared
    @State private var dismissed = false

    var body: some View {
        if !dismissed && !hinge.isLaptopPosture && FoldTutorial.shouldShowHint {
            Button {
                FeedbackManager.shared.tap()
                withAnimation(.easeOut(duration: 0.2)) { dismissed = true }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 13, weight: .bold))
                    Text(L("fold.hint"))
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.6)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.indigo.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear { FoldTutorial.noteHintShown() }
        }
    }
}

// MARK: - 第一次折起来：完整说明

/// 第一次摊成 90° 时盖一层说明，讲清三块屏各自干嘛。只出现一次。
struct FoldIntroOverlay: View {
    /// 你画我猜的分工跟其它玩法反过来（画板在下半屏），所以文案要分开
    let drawing: Bool
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(L("fold.intro_title"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                FoldDiagram(drawing: drawing)
                    .frame(height: 150)

                VStack(alignment: .leading, spacing: 11) {
                    bullet("arrow.up", L(drawing ? "fold.intro_top_draw" : "fold.intro_top"))
                    bullet("arrow.down", L(drawing ? "fold.intro_bottom_draw" : "fold.intro_bottom"))
                    bullet("person.2.fill", L(drawing ? "fold.intro_cover_draw" : "fold.intro_cover"))
                }

                Button {
                    FeedbackManager.shared.tap()
                    onDismiss()
                } label: {
                    Text(L("fold.intro_got_it"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.white))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.10, blue: 0.22))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            )
            .padding(.horizontal, 26)
            // 讲折痕的卡片自己压在折痕上，是第一轮两位评审员都报过的
            .foldedTopHalf()
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(0.18)))
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// 侧视图：一台折成 90° 的手机。上半屏立着朝自己，下半屏平躺当画板/按钮区，背面那块给对面看。
private struct FoldDiagram: View {
    let drawing: Bool

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2 - 10
            let baseY = size.height - 24
            let arm = min(size.height * 0.66, size.width * 0.36)
            let thickness: CGFloat = 17
            // 这一屏是这次的主角就画亮，另一屏压暗——画画时主角是下半屏，其它玩法是上半屏
            let lit = Color.white
            let dim = Color(white: 0.45)

            // 下半屏：平躺的那一半
            let bottom = CGRect(x: cx - thickness / 2, y: baseY - thickness,
                                width: arm, height: thickness)
            context.fill(Path(roundedRect: bottom, cornerRadius: 4),
                         with: .color(drawing ? lit : dim))

            // 上半屏：立起来的那一半
            let top = CGRect(x: cx - thickness / 2, y: baseY - thickness - arm,
                             width: thickness, height: arm)
            context.fill(Path(roundedRect: top, cornerRadius: 4),
                         with: .color(drawing ? dim : lit))

            // 外屏：立起那一半的背面，朝对面。画成一条发光的绿边
            let cover = CGRect(x: cx - thickness / 2 - 7, y: baseY - thickness - arm + 5,
                               width: 6, height: arm - 12)
            context.fill(Path(roundedRect: cover, cornerRadius: 3), with: .color(.green))

            // 桌面
            var desk = Path()
            desk.move(to: CGPoint(x: cx - thickness / 2 - 26, y: baseY + 1))
            desk.addLine(to: CGPoint(x: cx + arm + 14, y: baseY + 1))
            context.stroke(desk, with: .color(.white.opacity(0.3)), lineWidth: 2)
        }
        .overlay(alignment: .trailing) {
            // 右边站个小人代表「你」，外屏朝左边那一侧
            VStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                Text(L("fold.diagram_you"))
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.75))
            .padding(.trailing, 6)
        }
        .overlay(alignment: .leading) {
            VStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20))
                Text(L("fold.diagram_them"))
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.green.opacity(0.9))
            .padding(.leading, 6)
        }
    }
}

/// 折起来了，但屏幕还是横的时候盖的一层。
///
/// 90° 分屏是按**屏幕中线横着劈**的（见 `CreaseSplit`），这条线只有竖着拿的时候才压在
/// 物理折痕上。横着的时候劈出来的两半跟折痕是垂直的，整页内容正好骑在弯折带上。
///
/// 正常情况下折起来那一下 `OrientationLock` 就把屏转回竖的了，轮不到这一层。
/// 它是兜底：系统拒掉几何更新请求的时候，宁可挡住整页也别渲染一个劈错地方的版面。
/// 转回来它自己就走；转不回来（真机内屏可能根本不认竖屏）还有「就这样用」这个出口。
struct RotateToLaptopOverlay: View {
    /// 把手机转到竖屏，是顺时针还是逆时针。由 `RootView` 按**当前界面方向**算，
    /// 不是写死的——两种横屏要转的方向正好相反，写死必然有一半是反的
    let clockwise: Bool
    /// 「就这样用」：退回整屏版面。
    /// 没有这个出口的话，万一真机内屏根本不认竖屏，这一层就是个关不掉的死胡同
    let onKeepSideways: () -> Void

    @Environment(\.screenSafeAreaInsets) private var insets

    var body: some View {
        GeometryReader { geo in
            // 横着拿的时候折痕是**竖**的，所以两半是左右分的（竖屏时才是上下）。
            // 和 CreaseSplit 同一个套路：安全区左右不对称，折痕不在可用区正中
            let crease = geo.size.width / 2 + (insets.trailing - insets.leading) / 2

            ZStack {
                Color.black.opacity(0.82).ignoresSafeArea()

                // 提示要在**两半各放一个**：折起来之后这两半是朝着不同方向的，
                // 一个放正中只会正好骑在弯折带上，两边都看不清
                HStack(spacing: 0) {
                    hint.frame(width: crease)
                    hint.frame(width: max(0, geo.size.width - crease))
                }
            }
        }
    }

    private var hint: some View {
        VStack(spacing: 14) {
            RotateDiagram(clockwise: clockwise)
                .frame(width: 132, height: 132)

            Text(L("fold.rotate_title"))
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(L("fold.rotate_body"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                FeedbackManager.shared.tap()
                onKeepSideways()
            } label: {
                Text(L("fold.rotate_keep"))
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.85))
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
    }
}

/// 转动示意：一台折成 90° 的手机转到竖屏，循环演示。
///
/// 两件事必须对，否则这张图反而把人带偏：
/// **方向**——顺/逆时针由调用方按当前界面方向算，照着转一定落在竖屏（而不是倒过来的竖屏）；
/// **哪一半立起来**——绿色那条边是外屏，转完之后它必须在上面，也就是立起来朝着对面的那半。
private struct RotateDiagram: View {
    let clockwise: Bool

    /// 一个循环：转过去、停一下、淡出重来
    private static let turn: Double = 1.1
    private static let hold: Double = 0.55
    private static let out: Double = 0.35
    private static var cycle: Double { turn + hold + out }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.cycle)
            let p = Self.progress(t)
            let fade = Self.fade(t)

            ZStack {
                // 环形箭头指出转的方向。用 SF Symbol 而不是自己画弧：
                // 这两个符号的箭头形状本来就是大家认的「转这边」
                Image(systemName: clockwise ? "arrow.clockwise" : "arrow.counterclockwise")
                    .font(.system(size: 124, weight: .light))
                    .foregroundStyle(.white.opacity(0.35))

                phone
                    .rotationEffect(.degrees((clockwise ? 90 : -90) * p))
            }
            .opacity(fade)
        }
    }

    /// 折成 90° 的手机：机身 + 中间那条折痕 + 绿色的外屏那一边。
    /// 起始姿态画成**横**的（现在就是这样拿的），转完正好竖起来
    private var phone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white, lineWidth: 3.5)
                .frame(width: 74, height: 50)

            // 折痕：横着拿的时候它是竖的
            Rectangle()
                .fill(.white.opacity(0.55))
                .frame(width: 2, height: 50)

            // 外屏那一边。和 FoldDiagram 一样用绿色，转完之后它应该在上面
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.green)
                .frame(width: 5, height: 40)
                .offset(x: -39)
        }
    }

    /// 0 → 1 的转动进度，带缓动；停顿期间保持 1
    private static func progress(_ t: Double) -> Double {
        guard t < turn else { return 1 }
        let x = t / turn
        // easeInOut
        return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }

    /// 最后那一小段淡出，免得从 90° 硬切回 0° 看着像跳帧
    private static func fade(_ t: Double) -> Double {
        guard t > turn + hold else { return 1 }
        return 1 - (t - turn - hold) / out
    }
}

/// 这个玩法折起来没法玩，请摊开。
///
/// 名人堂是两队**左右对坐**、同时看同一块屏的：一块屏劈成红蓝两半，各按各的加分键。
/// 折成 90° 之后屏幕横着劈，立起来那半只有执机人看得见，对面那队什么都看不到。
/// 硬塞进半屏只会更糟，所以直接说清楚：这一局要摊平玩。
struct OpenToPlayOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "rectangle.portrait.and.arrow.forward")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)

                Text(L("fold.open_title"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(L("fold.open_body"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.10, blue: 0.22))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            )
            .padding(.horizontal, 36)
            // 这几张卡正是出事那一刻唯一要读的字，自己骑在折痕上就白写了。
            // 只框卡片、不框整层：底下那层暗色照旧铺满
            .foldedTopHalf()
        }
    }
}

/// 手机在玩到一半时被合上了。
///
/// 合上之后 App 会被系统搬到**外屏**上继续显示——而这一页上正印着答案。
/// 仓库自己的说明里把「合上」当成交接手势，那下一个人拿起手机，一眼就是答案。
/// 防窥模式（姿态感应隐词）默认是关的，兜不住这一下。
///
/// 所以合上就把整页盖掉，顺便停表：谁也没法在合着的手机上玩，这几秒不该从本队扣。
struct FoldedShutOverlay: View {
    var body: some View {
        ZStack {
            // 不透明，不是半透明——底下那层印着词，透出来就白盖了
            LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.22),
                                    Color(red: 0.05, green: 0.04, blue: 0.11)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.iphone")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)

                Text(L("fold.shut_title"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(L("fold.shut_body"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(26)
            .padding(.horizontal, 10)
        }
    }
}

#if DEBUG
extension FoldTutorial {
    /// 模拟器合不上，用它把「合上了」那一层调出来看：FORCE_SHUT=1（真身在 HingeMonitor）
    static var debugForceShut: Bool { HingeMonitor.debugForceShut }

    /// 「折着还横拿」这个状态在模拟器上造不出来，用它直接把提示层调出来看版式
    static let debugForceSideways = ProcessInfo.processInfo.environment["FORCE_SIDEWAYS"] == "1"
}
#endif
