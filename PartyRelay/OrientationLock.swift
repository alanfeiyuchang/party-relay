import SwiftUI
import UIKit

/// 折成笔记本模式时把界面钉在竖屏。
///
/// 为什么要锁：90° 分屏是按**屏幕中线横着劈**的（见 `CreaseSplit`），这条中线只有竖着拿
/// 的时候才和物理折痕重合。横着折起来折痕是竖的，整页内容正好压在弯折带上，
/// 两半都看不清。指望用户自己转回来不现实——折的那一下手上本来就有两种拿法，
/// 所以折起来就直接把方向转过去，并且在折着的时候不再放行横屏。
@MainActor
final class OrientationLock: NSObject, UIApplicationDelegate {

    /// Info.plist 里本来声明的方向。
    /// 没折的时候照旧：这个类只在折起来那一刻**收紧**，不去放宽任何原本不允许的方向。
    private static let declared: UIInterfaceOrientationMask = {
        guard let names = Bundle.main
            .object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String] else {
            return .portrait   // 读不到就按最保守的来
        }
        var mask: UIInterfaceOrientationMask = []
        for name in names {
            switch name {
            case "UIInterfaceOrientationPortrait":           mask.insert(.portrait)
            case "UIInterfaceOrientationPortraitUpsideDown": mask.insert(.portraitUpsideDown)
            case "UIInterfaceOrientationLandscapeLeft":      mask.insert(.landscapeLeft)
            case "UIInterfaceOrientationLandscapeRight":     mask.insert(.landscapeRight)
            default: break
            }
        }
        return mask.isEmpty ? .portrait : mask
    }()

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // 外屏那路内容不归这儿管，它的方向由系统定
        guard window?.windowScene?.session.role == .windowApplication else { return .all }
        return HingeMonitor.shared.isLaptopPosture ? .portrait : Self.declared
    }

    /// 姿态变了之后调用。
    ///
    /// 光换 mask 不够：系统只在它自己想转的时候才来问，已经横着的那一屏不会自己回来。
    /// 所以要先让它重新读一遍 mask，再明确请求一次几何更新把屏转回竖的。
    static func apply() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes
        where scene.session.role == .windowApplication {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            guard HingeMonitor.shared.isLaptopPosture else { continue }
            // 请求被系统拒掉也不致命：mask 已经收紧，下一次它来问的时候还是只有竖屏
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
}
