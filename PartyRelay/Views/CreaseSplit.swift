import SwiftUI

/// 整块屏的安全区，由 `RootView` 在最外层量一次往下发。
///
/// 为什么要发下来：`GeometryReader` 报的 `safeAreaInsets` 是**它自己那块区域**的。
/// 玩法页已经被排在安全区里面了，再嵌一个 GeometryReader 读到的是 0，
/// 量不到状态栏那条竖边，也量不到上下的不对称。
private struct ScreenSafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

extension EnvironmentValues {
    var screenSafeAreaInsets: EdgeInsets {
        get { self[ScreenSafeAreaInsetsKey.self] }
        set { self[ScreenSafeAreaInsetsKey.self] = newValue }
    }
}

/// 摊成 90° 时按**物理屏幕中线**把页面劈成两半，并在折痕两侧各留出一条空白。
///
/// 关键的一个坑：直接拿 `geo.size.height / 2` 劈是**错的**。GeometryReader 量到的是安全区，
/// 而安全区上下并不对称（顶上状态栏、底下 home indicator），它的中线不是折痕。
/// 实测过：按安全区中线分屏时，画板上边压到了折痕下方 23pt 处，而留白本该有 30pt——
/// 也就是说下半屏整体往上越过了折痕。
///
/// 所以这里按整块屏算中线：安全区中线 + 上下安全区差额的一半，换算回本地坐标正好是
/// `S/2 - top`。安全区本身继续交给系统（不 `ignoresSafeArea`），右边那条状态栏竖边
/// 才不会被内容压住。
struct CreaseSplit<Top: View, Bottom: View>: View {
    @Environment(\.screenSafeAreaInsets) private var insets

    /// 折痕两侧各留多少空白
    var gutter: CGFloat = HingeMonitor.creaseGutter
    /// 立起来那半屏，朝着执机人
    @ViewBuilder var top: () -> Top
    /// 平躺那半屏，朝着天花板
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        GeometryReader { geo in
            let crease = geo.size.height / 2 + (insets.bottom - insets.top) / 2
            // 高度要钉死（min 和 max 给同一个数），不能只给 maxHeight：那只是个上限，真正分多少由 VStack 协商，
            // 两半都是弹性的时候它会按自己的算法均摊，落点不保证就是折痕。
            // 实测过：用 maxHeight 时下半屏比该在的位置高了 8.7pt，留白被吃掉近三分之一。
            VStack(spacing: 0) {
                top()
                    .padding(.bottom, gutter)
                    .frame(maxWidth: .infinity, minHeight: crease, maxHeight: crease)

                bottom()
                    .padding(.top, gutter)
                    .frame(maxWidth: .infinity,
                           minHeight: geo.size.height - crease,
                           maxHeight: geo.size.height - crease)
            }
        }
    }
}

/// 摊成 90° 时，把**正文**收进立起来那半屏，背景不受影响。
///
/// 用在页面自己的内容容器上（`pageFrame`、`FittingScroll`、遮罩层里的卡片），
/// 而不是整页：这些容器都是 ZStack 里背景的**兄弟节点**，框住它们只影响正文，
/// 背景照旧 `ignoresSafeArea` 铺满整块屏。
///
/// ⚠️ 上一版用的是 `safeAreaPadding(.bottom, …)`，**那是错的**：
/// 安全区垫在滚动视图上会变成 content inset，正文一点都不会上移。
/// `HomeView` / `ModeMenuView` 走 `FittingScroll`（内含 ScrollView），
/// 而 `pageFrame` 折叠时也套了一层 ScrollView——两个修法互相抵消，
/// 结果「开始游戏」「Start」「Scoreboard」这些主按钮全压在折痕上或落到平躺半屏。
/// 现在改成**钉高度**：只有钉死的 frame 才真的把正文关进半屏。
struct FoldedTopHalf: ViewModifier {
    @ObservedObject private var hinge = HingeMonitor.shared
    @Environment(\.screenSafeAreaInsets) private var insets
    @Environment(\.isInsideFoldedTopHalf) private var alreadyApplied

    /// 比这更矮就不可能是「半屏」，只能是量错了（最常见的就是量在滚动视图里面）。
    /// 这种时候**原样放行**，别去框——框出来是一条看不懂的缝，比不框更难查。
    private static let minPlausibleHeight: CGFloat = 320

    func body(content: Content) -> some View {
        // 页面可能把两种容器套在一起（`ScoreboardView` 就是 FittingScroll 里面再套 pageFrame）。
        // 套两层的话，里面那层的 GeometryReader 活在 ScrollView 里，量不到可用高度，
        // 于是正文被钉成一条缝。所以只认最外面那一层。
        if hinge.isLaptopPosture && !alreadyApplied {
            GeometryReader { geo in
                // 和 CreaseSplit 同一条中线：安全区上下不对称，折痕不在可用区正中
                let crease = geo.size.height / 2 + (insets.bottom - insets.top) / 2
                let half = crease - HingeMonitor.creaseGutter
                Group {
                    if geo.size.height >= Self.minPlausibleHeight {
                        content
                            .frame(width: geo.size.width, height: half)
                            .frame(height: geo.size.height, alignment: .top)
                    } else {
                        content
                    }
                }
                .environment(\.isInsideFoldedTopHalf, true)
            }
        } else {
            content
        }
    }
}

/// 外层是不是已经把正文收进半屏了。见 `FoldedTopHalf`。
private struct InsideFoldedTopHalfKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isInsideFoldedTopHalf: Bool {
        get { self[InsideFoldedTopHalfKey.self] }
        set { self[InsideFoldedTopHalfKey.self] = newValue }
    }
}

extension View {
    /// 见 `FoldedTopHalf`。没折的时候原样返回。
    func foldedTopHalf() -> some View { modifier(FoldedTopHalf()) }
}

/// 折到 90° 时整块拿掉。
///
/// 立起来那半屏只有四百多点高，而主行动按钮必须在里面看得见——
/// 交接页的「刚才那些词」回顾卡本身就有两百多点，留着它 Start 就被挤到滚动区外面去了，
/// 折起来一眼看不到能按的地方。这块回顾是锦上添花，主按钮不是。
/// 摊开时照常显示，什么都不少。
struct HiddenWhenFolded: ViewModifier {
    @ObservedObject private var hinge = HingeMonitor.shared

    func body(content: Content) -> some View {
        if !hinge.isLaptopPosture { content }
    }
}

extension View {
    /// 见 `HiddenWhenFolded`。
    func hiddenWhenFolded() -> some View { modifier(HiddenWhenFolded()) }
}

/// 折起来时，滚动区默认停在**底部**。
///
/// 立起来那半屏放不下整页，于是正文要滚。但默认停在顶部意味着主行动按钮
/// （开始游戏 / 下一轮转盘 / 再来一局 / Start）滚到了屏外——页面看着就是个死胡同，
/// 而且没有任何东西提示还能滑。这些页面的主按钮都在最后，所以停在底部正好：
/// 按钮一定看得见，往上滑才是那些可看可不看的信息。
struct FoldedBottomAnchor: ViewModifier {
    @ObservedObject private var hinge = HingeMonitor.shared

    func body(content: Content) -> some View {
        if hinge.isLaptopPosture {
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
    }
}

extension View {
    /// 见 `FoldedBottomAnchor`。
    func foldedBottomAnchor() -> some View { modifier(FoldedBottomAnchor()) }
}
