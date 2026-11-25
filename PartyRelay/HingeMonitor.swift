import SwiftUI
import UIKit

/// 铰链状态（iPhone Duo 的折叠角度）。
///
/// 系统只给两样东西：`status`（闭合 / 半开 / 全开）和 `angle`（弧度）。
/// 折痕在屏幕上的位置、两半各占多少，系统**不告诉你**——没有任何公开 API 提供折痕几何，
/// 所以 90° 分屏只能按屏幕中线自己劈（物理折痕就在正中，这个假设对 Duo 成立）。
@MainActor
final class HingeMonitor: ObservableObject {
    static let shared = HingeMonitor()

    enum Status {
        case unavailable   // 没有铰链，或视图不在能收到铰链更新的层级里
        case closed
        case partiallyOpen
        case fullyOpen
    }

    /// 算「笔记本模式」的角度区间（度）。
    ///
    /// 这两个数是自己定的，不是系统定的——`UIHinge` 只有四档 status 和一个角度，
    /// 没有「笔记本模式」这个概念。真机实测：折到大约 90° 时读数 90.9°。
    /// 低于下界上半屏仰得太靠后，高于上界接近摊平，该回到整屏布局。
    static let laptopAngleRange: ClosedRange<Double> = 60...135

    /// 折痕两侧各自留空多少（pt）。
    ///
    /// 系统不给折痕几何（见上），这个数只能自己定。摊成 90° 时折痕就是那个内折角，
    /// 压在上面的东西一半被折进去、一半只能斜着看，所以两个半屏都要往外让一截。
    /// 30pt 在这块屏上大约 5mm，够把内容推出弯折带，又不至于把两个半屏挤瘦。
    static let creaseGutter: CGFloat = 30

    /// 退出用的宽区间：进了笔记本模式之后，角度要明显越界才算真的离开。
    /// 手托着机器时角度一直在抖，拿同一条线进出会让布局在边界上反复横跳。
    private static let laptopExitRange: ClosedRange<Double> = 50...145

    /// 新姿态要连续站住这么久才生效。
    ///
    /// 这不是为了手感，是为了**不让一帧坏读数掀翻整页布局**：姿态一变，内屏要换版、
    /// 外屏那个 accessory 场景要跟着重配，闪一下代价很大，而 handler 每一帧都在回调。
    private static let settleDelay: TimeInterval = 0.3

    /// **只有这个值驱动布局。** 视图只观察这个布尔量和 `status`。
    ///
    /// ⚠️ 往这个类上加 `@Published` 之前先想清楚：`@ObservedObject` 订阅的是整个对象的
    /// `objectWillChange`，**任何**一个 `@Published` 变了都会让所有观察者重绘。角度是每帧都在
    /// 变的，所以它绝不能是 `@Published`——以前就是这么埋的雷：玩法页和 RootView 每帧重算，
    /// 连外屏那个 accessory 闭包都跟着每帧重新求值。
    @Published private(set) var rawLaptopPosture = false

    /// 用户按了「就这样用」之后不再按 90° 排版。
    ///
    /// 作用范围是「这一次折叠」：姿态真的变了（摊开又折回去）就作废，重新按正常逻辑走。
    /// 不做成整次启动有效，是因为那样会把「这台机器转不过来」和「刚才那一下没转过来」
    /// 混为一谈；而真机内屏若根本不认竖屏，每折一次会多按一次——代价是一次点击，
    /// 换来的是姿态恢复正常时折叠版面能自己回来。
    ///
    /// 兜底用的：90° 分屏是按屏幕中线**横着**劈的，只有竖着拿才压在物理折痕上。
    /// 要是真机内屏根本不认 App 声明的方向（仓库自己的 docs/iphone-duo.md 就是这么写的，
    /// 说内屏跑的是横的 951×669），`isSideways` 会恒为真，整个 App 被一层提示盖死。
    /// 与其让人完全玩不了，不如让他退回整屏版面——折叠那套不生效，但游戏能继续。
    @Published var foldLayoutSuppressed = false

    /// **只有这个值驱动布局。**
    var isLaptopPosture: Bool { rawLaptopPosture && !foldLayoutSuppressed }

    @Published private(set) var status: Status = .unavailable

    /// 铰链角度，度。没有铰链时为 nil。**故意不是 `@Published`**（见上）。
    private(set) var angleDegrees: Double?

    /// 还在等待坐稳的候选姿态，以及到时间后提交它的任务
    private var pendingLaptop: Bool?
    private var settleTask: DispatchWorkItem?

#if DEBUG
    /// 模拟器折不了，用环境变量强制进入 90° 姿态来验布局：
    /// `SIMCTL_CHILD_FORCE_LAPTOP=1 xcrun simctl launch booted com.partyrelay.app`
    nonisolated(unsafe) static let debugForceLaptop =
        ProcessInfo.processInfo.environment["FORCE_LAPTOP"] == "1"
#endif

    private init() {
#if DEBUG
        if Self.debugForceLaptop {
            rawLaptopPosture = true
            // 顺带把 status 也摆成「有铰链」。强制 90° 却还报 unavailable 的话，
            // FoldTutorial.deviceCanFold 是 false，轻提示、外屏指示器这些
            // 恰恰是这次新增的可发现性 UI，一张截图都拍不到
            status = .partiallyOpen
        }
        if Self.debugForceShut { status = .closed }
#endif
    }

#if DEBUG
    /// 模拟器合不上：FORCE_SHUT=1 直接把状态摆成「合上了」
    nonisolated(unsafe) static let debugForceShut =
        ProcessInfo.processInfo.environment["FORCE_SHUT"] == "1"
#endif

    fileprivate func update(status newStatus: Status, angleDegrees newAngle: Double?) {
#if DEBUG
        // 强制姿态要**连 status 一起**顶掉，而且必须在赋值之前返回。
        // 两台 Duo 模拟器都停在闭合姿态，真实回调报的是 .closed——
        // 放它进来的话 FORCE_LAPTOP 下每一个玩法页都会被「手机合上了」那一层盖住
        if Self.debugForceLaptop || Self.debugForceShut { return }
#endif
        if status != newStatus {
            let hadHinge = status != .unavailable
            status = newStatus
            // 「这台机器有没有铰链」是相机会话的开关条件，而它要等铰链第一次回调才知道。
            // 玩法页的 onAppear 常常跑在前面，所以状态一变就捅一下相机那边
            if hadHinge != (newStatus != .unavailable) {
                CoverScreenCamera.shared.hingeAvailabilityChanged()
            }
        }
        angleDegrees = newAngle
        settle(on: laptopReading(status: newStatus, angle: newAngle))
    }

    /// 这一帧的读数算不算笔记本模式。
    ///
    /// 两条滞回：**读不到铰链不算姿态变化**（`nil` 是传感器掉帧，不是用户把机器摊开了），
    /// 以及进出用不同的角度区间。
    private func laptopReading(status: Status, angle: Double?) -> Bool {
        guard let angle, status != .unavailable else { return rawLaptopPosture }
        guard status == .partiallyOpen else { return false }
        return rawLaptopPosture
            ? Self.laptopExitRange.contains(angle)
            : Self.laptopAngleRange.contains(angle)
    }

    /// 读数要连续站住 `settleDelay` 才改 `isLaptopPosture`。
    ///
    /// 用一次性任务而不是在下一帧回调里比时间：静止摊着的时候 handler 可能就不再回调了，
    /// 那样等待中的姿态会永远提交不了。
    private func settle(on laptop: Bool) {
        if laptop == rawLaptopPosture {
            // 读数回到了当前姿态，之前那个候选作废
            pendingLaptop = nil
            settleTask?.cancel()
            settleTask = nil
            return
        }
        guard pendingLaptop != laptop else { return }   // 同一个候选已经在等了
        pendingLaptop = laptop
        settleTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.pendingLaptop == laptop else { return }
                self.pendingLaptop = nil
                self.settleTask = nil
                guard self.rawLaptopPosture != laptop else { return }
                self.rawLaptopPosture = laptop
                // 姿态真的变了，之前那个「就这样用」也跟着作废
                self.foldLayoutSuppressed = false
                // 折起来要转回竖屏，摊开要把横屏放回去——两头都得捅一下系统
                OrientationLock.apply()
            }
        }
        settleTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay, execute: task)
    }
}

/// 把 `UIHingeInteraction` 挂进视图层级，铰链更新写回 `HingeMonitor.shared`。
///
/// 铰链状态只能通过挂在视图上的 interaction 拿到（没有全局单例可查），
/// 所以这个视图要一直待在层级里。给它 1×1 而不是 0×0：零尺寸视图不一定会被真正加进 UIKit 层级。
struct HingeReader: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        guard #available(iOS 27.1, *) else { return view }
        let interaction = UIHingeInteraction { _, update in
            guard let hinge = update.hinge else {
                HingeMonitor.shared.update(status: .unavailable, angleDegrees: nil)
                return
            }
            let status: HingeMonitor.Status
            switch hinge.status {
            case .closed:        status = .closed
            case .partiallyOpen: status = .partiallyOpen
            case .fullyOpen:     status = .fullyOpen
            default:             status = .unavailable
            }
            HingeMonitor.shared.update(status: status,
                                       angleDegrees: hinge.angle * 180 / .pi)
        }
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
