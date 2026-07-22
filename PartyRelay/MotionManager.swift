import Foundation
import CoreMotion
import Combine

/// 设备姿态检测：立起 = 显示词语；放平 = 防窥屏
@MainActor
final class MotionManager: ObservableObject {
    static let shared = MotionManager()

    enum Posture {
        case upright   // 立着（竖直）
        case flat      // 放平（桌面）
        case unknown   // 无法获取（模拟器等）
    }

    @Published var posture: Posture = .unknown

    /// 截图/调试用强制姿态
    nonisolated(unsafe) static var debugOverride: Posture?

    private let manager = CMMotionManager()
    private var running = false

    private init() {}

    func start() {
        if let o = Self.debugOverride {
            posture = o
            return
        }
        guard !running else { return }
        guard manager.isDeviceMotionAvailable else {
            posture = .unknown
            return
        }
        running = true
        manager.deviceMotionUpdateInterval = 0.15
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            let z = abs(g.z)   // 1 ≈ 平放（屏幕朝上/下），0 ≈ 竖直
            // 滞回区间防抖动
            switch self.posture {
            case .flat:
                if z < 0.55 { self.posture = .upright }
            case .upright:
                if z > 0.78 { self.posture = .flat }
            case .unknown:
                self.posture = z > 0.78 ? .flat : .upright
            }
        }
    }

    func stop() {
        guard Self.debugOverride == nil else { return }
        running = false
        manager.stopDeviceMotionUpdates()
    }

    /// 姿态数据是否可用（模拟器上不可用，界面需给手动开关兜底）
    var isAvailable: Bool {
        Self.debugOverride != nil || manager.isDeviceMotionAvailable
    }
}
