#if DEBUG
import SwiftUI
import AVFoundation
import UIKit

/// 在**任何**模拟器上按指定点数和安全区排整个 App，用来验 90° 笔记本布局。
///
/// 为什么需要这么一条旁路：Duo 模拟器折不了（`simctl` 没有改姿态的命令，只能在
/// DeviceHub 里点），而折起来那一下 App 跑的是**内屏** 669×951。模拟器停在闭合姿态时
/// 给的是外屏 466×678，尺寸差了一大截，照着它排出来的版面不算数。
///
/// 所以这里把 RootView 塞进一个钉死尺寸的画布，再用 `safeAreaPadding` 把安全区补回去，
/// 然后整体缩放到当前屏幕里。布局是在**目标点数**下协商完的，缩放只发生在最后一步，
/// 所以版面比例和真机一致，只是像素被等比缩了。
///
/// ```bash
/// # 内屏 90° 姿态（配 FORCE_LAPTOP=1 才会走分屏那条路）
/// SIMCTL_CHILD_FOLD_SIZE=669x951 SIMCTL_CHILD_FORCE_LAPTOP=1 \
///   xcrun simctl launch booted com.partyrelay.app
/// ```
///
/// ⚠️ **内屏安全区是假设值，不是实测值。** 外屏实测是 `0,0,34,84`（顶上没有横条，
/// 状态栏是右边那条 84pt 的竖带）。内屏按同样的形状假设，真机到手必须重新量一次
/// ——这条旁路本身是对的，喂给它的那组数才是待验的。
enum FoldPreview {

    /// `FOLD_SIZE=669x951`。没给就不启用这条旁路，App 照常铺满屏幕。
    static var size: CGSize? {
        guard let raw = ProcessInfo.processInfo.environment["FOLD_SIZE"] else { return nil }
        let parts = raw.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    /// Duo 外屏实测：顶上 0、底下 34（home indicator）、右边 84（状态栏竖带）。
    /// 这是唯一一组量到过的真实数字，内屏那组照它的形状推。
    static let measuredOuter = EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84)

    /// `FOLD_INSETS=top,leading,bottom,trailing`。缺省沿用外屏那组实测值。
    static var insets: EdgeInsets {
        guard let raw = ProcessInfo.processInfo.environment["FOLD_INSETS"] else {
            return measuredOuter
        }
        let p = raw.split(separator: ",").compactMap { Double($0) }
        guard p.count == 4 else { return measuredOuter }
        return EdgeInsets(top: p[0], leading: p[1], bottom: p[2], trailing: p[3])
    }

    /// `FOLD_PROBE=1`：把真实量到的尺寸和安全区打到 stderr。
    /// 配 `xcrun simctl launch --console` 读，这是拿到真机数字的唯一办法。
    static let probe = ProcessInfo.processInfo.environment["FOLD_PROBE"] == "1"

    /// `FOLD_PROBE=1` 时把这台机器上**所有**摄像头和当前界面方向打出来。
    ///
    /// 这两件事都不该靠推：哪颗是「外屏那颗」只有真机知道（折叠机的前摄可能不止一颗），
    /// 而 landscapeLeft/Right 和「该往哪边转」的对应关系，推错了一半用户就是反的。
    @MainActor
    static func reportDevice() {
        guard probe else { return }
        var out = ""
        // 把能枚举到的全列出来，连 uniqueID 一起——「外屏那颗」到底是哪一个
        // 光看 position 判断不出来：前后各一颗广角的话，内屏和外屏那两颗都会报 front。
        // uniqueID 里一般带着序号，能把它们区分开
        var types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera,
            .builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera,
            .builtInTrueDepthCamera,
        ]
        if #available(iOS 17.0, *) { types.append(.external) }
        if #available(iOS 17.0, *) { types.append(.continuityCamera) }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: .unspecified)
        for (i, d) in session.devices.enumerated() {
            let pos: String
            switch d.position {
            case .back: pos = "back"
            case .front: pos = "front"
            default: pos = "unspecified"
            }
            out += "FOLDCAM[\(i)] pos=\(pos) type=\(d.deviceType.rawValue)"
                + " name=\(d.localizedName) model=\(d.modelID)"
                + " uid=\(d.uniqueID) connected=\(d.isConnected) suspended=\(d.isSuspended)\n"
        }
        out += "FOLDCAM default-front="
            + (AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)?.uniqueID ?? "nil")
            + " default-back="
            + (AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?.uniqueID ?? "nil")
            + "\n"
        out += "FOLDCAM hinge=\(HingeMonitor.shared.status) "
            + "angle=\(HingeMonitor.shared.angleDegrees.map { String(format: "%.1f", $0) } ?? "nil")\n"
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            out += "FOLDORIENT role=\(scene.session.role.rawValue) "
                + "interface=\(scene.interfaceOrientation.rawValue) "
                + "device=\(UIDevice.current.orientation.rawValue)\n"
        }
        FileHandle.standardError.write(Data(out.utf8))
    }

    static func report(size: CGSize, insets: EdgeInsets) {
        guard probe else { return }
        let line = "FOLDPROBE size=\(Int(size.width))x\(Int(size.height)) "
            + "insets=\(Int(insets.top)),\(Int(insets.leading)),"
            + "\(Int(insets.bottom)),\(Int(insets.trailing))\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}

extension View {
    /// 把这棵视图钉在 `FOLD_SIZE` 上排版，再整体缩进当前屏幕。没设环境变量时原样返回。
    @ViewBuilder
    func foldPreview() -> some View {
        if let target = FoldPreview.size {
            GeometryReader { host in
                let scale = min(host.size.width / target.width,
                                host.size.height / target.height)
                self
                    // 安全区要在钉尺寸**之前**补：这样内容是在「扣掉安全区之后」的那块地方
                    // 协商的，和真机上的顺序一致
                    .safeAreaPadding(FoldPreview.insets)
                    .frame(width: target.width, height: target.height)
                    .clipped()
                    // 缩放只影响最终像素，布局已经按目标点数算完了
                    .scaleEffect(scale)
                    .frame(width: host.size.width, height: host.size.height)
            }
            .ignoresSafeArea()
            // 宿主机自己的状态栏不跟着缩，留着只会骑在画面上
            .statusBarHidden(true)
        } else {
            self
        }
    }
}
#endif
