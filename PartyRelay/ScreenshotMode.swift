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
            store.phase = .wheel

        case "handoff":
            // 换手交接页：「开始」按钮带 5 秒倒计时，倒计时结束前不可按
            store.teams[0].score = 2
            store.teams[1].score = 1
            store.roundNumber = 4
            store.currentGame = .act
            store.roundSmall = [4, 0]
            store.playIndex = 1
            store.playingTeamIndex = 1
            store.phase = .handoff

        case "smallboard":
            // 小分制记分板：没有大分，只有累计小分
            store.settings.smallScoreWin = true
            store.teams[0].smallTotal = 17
            store.teams[1].smallTotal = 13
            store.roundNumber = 4
            store.currentGame = .lipRead
            store.lastOutcome = RoundOutcome(game: .lipRead, openBuzz: false,
                                             small: [5, 3], awards: [1, 0],
                                             roundNumber: 4, isOvertime: false,
                                             words: LanguageManager.shared.language == .en
                                                ? [["mom", "cheers", "yummy"], ["thank you", "good night"]]
                                                : [["妈妈", "干杯", "真好吃"], ["谢谢你", "晚安"]])
            store.phase = .scoreboard

        case "onegame":
            // 只开了一个普通玩法：开始游戏后不转盘，直达该玩法
            store.settings.enabled = [.act, .quiz]
            store.phase = .home

        case "direct":
            // 只开了一个普通玩法 → startMatch 走 enterGameSelection，应直接落在交接页而非转盘
            store.settings.enabled = [.act, .quiz]
            store.startMatch()

        case "gametag":
            // 主界面玩法标签弹窗（唇语被移出转盘 → 首页标签置灰），弹窗由 HomeView 自动打开
            store.settings.enabled = [.describeGuess, .drawGuess, .act, .quiz]
            store.phase = .home

        case "hofresult", "hofboard":
            // 名人堂结算：红队猜中 → 走真实计分（大分 +1 / 小分 +3），本轮两个名人在回顾里揭晓
            store.teams[0].score = 2
            store.teams[1].score = 1
            store.roundNumber = 4
            store.gameDecided(.hallOfFame, openBuzz: false)
            store.finishHallOfFame(winner: 0)
            if mode == "hofboard" { store.proceedToScoreboard() }

        case "hoftag":
            // 主界面「名人堂」标签弹窗（规则 + 加入/移出转盘开关），弹窗由 HomeView 自动打开
            store.phase = .home

        case "exitconfirm":
            // 游戏中页面顶部「返回主页」的二次确认弹窗，由 HomeExitButton 自动打开
            MotionManager.debugOverride = .upright
            store.settings.privacyGuardOn = false
            store.teams[0].score = 2
            store.teams[1].score = 1
            store.roundNumber = 4
            store.currentGame = .act
            store.openBuzz = false
            store.playingTeamIndex = 0
            store.phase = .playing

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

        case "act":
            // 普通比手画脚（不带开放抢答、不带防偷窥），用于宣传素材单独展示这个玩法
            MotionManager.debugOverride = .upright
            store.settings.privacyGuardOn = false
            store.teams[0].score = 2
            store.teams[1].score = 1
            store.roundNumber = 4
            store.currentGame = .act
            store.openBuzz = false
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
            store.firstTeamIndex = 0
            store.phase = .playing

        case "pick":
            // 决胜阶段：落后队可指定玩法
            store.teams[0].score = 1
            store.teams[1].score = 4
            store.roundNumber = 6
            store.firstTeamIndex = 0
            store.phase = .wheel

        case "draw", "drawcanvas":
            // draw = 看词界面（开始作画/答对/换一个）；drawcanvas = 画布界面（收起画布）
            store.teams[0].score = 2
            store.teams[1].score = 3
            store.roundNumber = 3
            store.currentGame = .drawGuess
            store.playingTeamIndex = 0
            store.phase = .playing

        case "hofsmall", "hofsmallscore":
            // 小分制下的名人堂：得分按钮与确认页都改成 +3 小分
            store.settings.smallScoreWin = true
            store.teams[0].smallTotal = 9
            store.teams[1].smallTotal = 6
            store.roundNumber = 4
            store.gameDecided(.hallOfFame, openBuzz: false)
            store.phase = .hallOfFame

        case "hof", "hofpeek", "hofsplit", "hofname", "hofreveal", "hofscore":
            // 名人堂：私下看名字 / 左红右蓝分屏 / 遮罩页（再看一次·揭晓·确认得分）
            store.teams[0].score = 2
            store.teams[1].score = 1
            store.roundNumber = 4
            store.gameDecided(.hallOfFame, openBuzz: false)
            store.phase = .hallOfFame

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

        case "smallvictory":
            // 小分制终局：胜负与终局比分都取累计小分
            store.settings.smallScoreWin = true
            store.teams[0].smallTotal = 26
            store.teams[1].smallTotal = 21
            store.roundNumber = 6
            store.phase = .victory

        case "victory":
            store.teams[0].score = 4
            store.teams[1].score = 2
            store.roundNumber = 6
            store.phase = .victory

        default:
            break
        }
    }

    /// 截图模式下需要自动弹出的弹窗（simctl 无法注入点击）
    static func autoPresents(_ name: String) -> Bool { mode == name }

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
