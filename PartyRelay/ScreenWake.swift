import UIKit

/// 玩的时候别让屏幕自己暗下去。
///
/// 这个 App 的玩法天生就是「手机放着没人碰」：说/演/唇语的时候执机人举着或摊在桌上，
/// 一整轮 60 秒（最长可设到 600 秒）一次触摸都没有，iOS 的自动锁定就会先把亮度压暗一截
/// 当作预告，再过几秒直接锁屏。摊成 90° 立在桌上之后这个问题更明显——那时候大家看的是
/// 外屏，根本不会去碰内屏。
///
/// 你画我猜不会暗，是因为画的人手指一直在屏上，每一笔都把空闲计时器清零了。
/// 这不是折叠屏独有的毛病，只是笔记本模式把它暴露出来了。
@MainActor
enum ScreenWake {
    /// 只在真正「手机被放着」的阶段开。菜单、交接、记分这些页面都要人点一下才往下走，
    /// 用户正盯着屏幕，没必要替系统做决定。
    static func update(for phase: Phase) {
        keepAwake(phase == .playing)
    }

    static func keepAwake(_ on: Bool) {
        guard UIApplication.shared.isIdleTimerDisabled != on else { return }
        UIApplication.shared.isIdleTimerDisabled = on
    }
}
