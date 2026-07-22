import UIKit
import AVFoundation
import AudioToolbox

/// 统一的震动 + 音效反馈管理器，受设置总开关控制
@MainActor
final class FeedbackManager {
    static let shared = FeedbackManager()

    /// 由 GameStore 同步的总开关
    var isEnabled = true

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }

    private func sound(_ id: SystemSoundID) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }

    // MARK: - 场景反馈

    /// 转盘开始转
    func wheelStart() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
        sound(1104) // Tock
    }

    /// 转盘转动中的"哒哒"声（频率随减速降低）
    func wheelTick(intensity: CGFloat) {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: max(0.3, intensity))
    }

    /// 转盘停下
    func wheelStop() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
        sound(1103) // Tink
    }

    /// 猜对 / 答对
    func correct() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        sound(1054)
    }

    /// 跳过 / 答错
    func skip() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred()
        sound(1155)
    }

    /// 倒计时最后几秒滴答
    func countdownTick() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred(intensity: 0.8)
        sound(1103)
    }

    /// 时间到
    func timeUp() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        sound(1005)
    }

    /// 抢答拍下
    func buzz() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
        sound(1520)
    }

    /// 被锁定
    func locked() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        sound(1053)
    }

    /// 回合结算
    func roundSettle() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
        sound(1114)
    }

    /// 获胜撒花
    func victory() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        sound(1025)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.heavyImpact.impactOccurred()
        }
    }

    /// 通用按钮轻触
    func tap() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }
}
