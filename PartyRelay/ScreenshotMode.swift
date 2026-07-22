import SwiftUI

/// 截图模式：通过环境变量 SCREENSHOT_MODE 直达指定页面（供 simctl 自动截图用）
/// 例：SIMCTL_CHILD_SCREENSHOT_MODE=wheel simctl launch booted <bundle-id>
@MainActor
enum ScreenshotMode {

    static var mode: String? {
        ProcessInfo.processInfo.environment["SCREENSHOT_MODE"]
    }

    static func apply(to store: GameStore, showSettings: Binding<Bool>) {
        guard let mode else { return }

        store.teams[0].name = L("team.red")
        store.teams[1].name = L("team.blue")
        store.settings.totalRounds = 6

        switch mode {
        case "home":
            store.phase = .home

        case "wheel":
            store.teams[0].score = 2
            store.teams[1].score = 2
            store.roundNumber = 4
            store.firstTeamIndex = 1
            store.phase = .wheel

        case "openbuzz":
            // 开放抢答加成下的比手画脚：多一个"被抢答"按钮
            MotionManager.debugOverride = .upright
            store.teams[0].score = 2
            store.teams[1].score = 1
            store.roundNumber = 4
            store.currentGame = .act
            store.openBuzz = true
            store.playingTeamIndex = 0
            store.firstTeamIndex = 0
            store.phase = .playing

        case "privacy":
            // 防偷窥模式开启 + 放平 → 防窥屏
            MotionManager.debugOverride = .flat
            store.settings.privacyGuardOn = true
            store.teams[0].score = 2
            store.teams[1].score = 1
            store.roundNumber = 3
            store.currentGame = .describeGuess
            store.playingTeamIndex = 1
            store.firstTeamIndex = 1
            store.phase = .playing

        case "pick":
            // 决胜阶段：落后队可指定玩法
            store.teams[0].score = 1
            store.teams[1].score = 4
            store.roundNumber = 6
            store.firstTeamIndex = 1
            store.phase = .wheel

        case "draw", "drawcanvas":
            // draw = 看词界面（开始作画/答对/换一个）；drawcanvas = 画布界面（收起画布）
            store.teams[0].score = 2
            store.teams[1].score = 3
            store.roundNumber = 3
            store.currentGame = .drawGuess
            store.playingTeamIndex = 0
            store.phase = .playing

        case "scoreboard":
            store.teams[0].score = 3
            store.teams[1].score = 2
            store.roundNumber = 5
            store.currentGame = .lipRead
            store.lastOutcome = RoundOutcome(game: .lipRead, openBuzz: false,
                                             small: [6, 4], awards: [1, 0],
                                             roundNumber: 5, isOvertime: false,
                                             words: LanguageManager.shared.language == .en
                                                ? [["mom", "cheers", "yummy"], ["thank you", "good night"]]
                                                : [["妈妈", "干杯", "真好吃"], ["谢谢你", "晚安"]])
            store.phase = .scoreboard

        case "result":
            store.teams[0].score = 3
            store.teams[1].score = 2
            store.lastOutcome = RoundOutcome(game: .act, openBuzz: true,
                                             small: [5, 5], awards: [1, 1],
                                             roundNumber: 4, isOvertime: false,
                                             words: LanguageManager.shared.language == .en
                                                ? [["brush teeth", "dance"], ["cook", "photographer"]]
                                                : [["刷牙", "跳舞"], ["炒菜", "摄影师"]])
            store.phase = .roundResult

        case "settings":
            store.phase = .home
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showSettings.wrappedValue = true
            }

        case "victory":
            store.teams[0].score = 4
            store.teams[1].score = 2
            store.roundNumber = 6
            store.phase = .victory

        default:
            break
        }
    }

    /// 画板演示笔画：一个雪人 ⛄️
    static func demoStrokes() -> [Stroke] {
        func circle(cx: CGFloat, cy: CGFloat, r: CGFloat, color: Color, width: CGFloat) -> Stroke {
            let pts = stride(from: 0.0, through: 2 * Double.pi + 0.1, by: 0.15).map {
                CGPoint(x: cx + r * cos($0), y: cy + r * sin($0))
            }
            return Stroke(points: pts, color: color, lineWidth: width)
        }
        var s: [Stroke] = []
        s.append(circle(cx: 185, cy: 330, r: 95, color: .black, width: 6))      // 身体
        s.append(circle(cx: 185, cy: 180, r: 60, color: .black, width: 6))      // 头
        s.append(circle(cx: 165, cy: 165, r: 5, color: .black, width: 6))       // 左眼
        s.append(circle(cx: 205, cy: 165, r: 5, color: .black, width: 6))       // 右眼
        s.append(Stroke(points: [CGPoint(x: 185, y: 180), CGPoint(x: 215, y: 192),
                                 CGPoint(x: 185, y: 196)],
                        color: .orange, lineWidth: 6))                          // 胡萝卜鼻子
        s.append(Stroke(points: [CGPoint(x: 128, y: 128), CGPoint(x: 242, y: 128)],
                        color: .red, lineWidth: 12))                            // 帽檐
        s.append(Stroke(points: [CGPoint(x: 150, y: 128), CGPoint(x: 152, y: 70),
                                 CGPoint(x: 220, y: 70), CGPoint(x: 222, y: 128)],
                        color: .red, lineWidth: 12))                            // 帽筒
        s.append(Stroke(points: [CGPoint(x: 95, y: 290), CGPoint(x: 30, y: 240)],
                        color: .black, lineWidth: 6))                           // 左手
        s.append(Stroke(points: [CGPoint(x: 275, y: 290), CGPoint(x: 340, y: 240)],
                        color: .black, lineWidth: 6))                           // 右手
        for (i, y) in [280.0, 330.0, 380.0].enumerated() {
            s.append(circle(cx: 185, cy: y, r: 6, color: i == 0 ? .blue : .black, width: 5)) // 扣子
        }
        return s
    }
}
