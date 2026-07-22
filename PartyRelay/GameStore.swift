import SwiftUI
import Combine

@MainActor
final class GameStore: ObservableObject {

    @Published var phase: Phase = .home
    @Published var teams: [Team] = [
        Team(id: 0, name: L("team.red"), emoji: "🦁",
             colors: [Color(red: 1.0, green: 0.35, blue: 0.37), Color(red: 1.0, green: 0.58, blue: 0.25)]),
        Team(id: 1, name: L("team.blue"), emoji: "🐬",
             colors: [Color(red: 0.25, green: 0.52, blue: 1.0), Color(red: 0.25, green: 0.80, blue: 0.96)]),
    ]

    /// 所有语言下的默认队名（用于判断用户是否改过队名）
    private static let defaultTeamNames: [[String]] = [["红队", "Red Team"], ["蓝队", "Blue Team"]]

    /// 语言切换后：未被用户改过的默认队名跟随切换
    func syncTeamNamesToLanguage() {
        let keys = ["team.red", "team.blue"]
        for i in teams.indices {
            if Self.defaultTeamNames[i].contains(teams[i].name) {
                teams[i].name = L(keys[i])
            }
        }
    }
    @Published var settings: GameSettings = .load() {
        didSet { settings.save() }
    }

    // 当前轮状态：每轮转一次盘，两队先后玩同一个游戏，各得小分
    @Published var roundNumber: Int = 1          // 1-based，可超过 totalRounds（加时）
    @Published var isOvertime = false
    @Published var firstTeamIndex: Int = 0       // 本轮先手队
    @Published var playIndex: Int = 0            // 0=先手那一遍，1=后手那一遍
    @Published var playingTeamIndex: Int = 0     // 当前执机队
    @Published var currentGame: GameKind = .describeGuess
    @Published var openBuzz = false              // 开放抢答加成（对方可抢答偷分）
    @Published var roundSmall: [Int] = [0, 0]    // 本轮两队小分
    @Published var roundWords: [[String]] = [[], []]  // 本轮两队各自出现过的词（按队伍下标）
    @Published var catchUp: CatchUp = CatchUp()
    @Published var lastOutcome: RoundOutcome?

    private var usedWords: [String: Set<Int>] = [:]   // "game-tier" -> 已用下标

    var playingTeam: Team { teams[playingTeamIndex] }
    var opponentIndex: Int { 1 - playingTeamIndex }
    var totalRounds: Int { settings.totalRounds }
    var completedRounds: Int { roundNumber - 1 }

    // MARK: - 大分 / 落后判断

    var winnerIndex: Int? {
        if teams[0].score == teams[1].score { return nil }
        return teams[0].score > teams[1].score ? 0 : 1
    }

    var trailingIndex: Int? {
        if teams[0].score == teams[1].score { return nil }
        return teams[0].score < teams[1].score ? 0 : 1
    }

    var bigDiff: Int { abs(teams[0].score - teams[1].score) }

    /// 平衡策略：已进行轮数达到总轮数 2/3 后，落后队可直接指定玩法（不转盘）
    var pickEligibleTeam: Int? {
        guard Double(completedRounds) >= Double(totalRounds) * 2.0 / 3.0 else { return nil }
        return trailingIndex
    }

    // MARK: - 难度档位（随轮次爬升）

    var baseTier: Int {
        let third = max(1, totalRounds / 3)
        let r = min(roundNumber, totalRounds)
        if r <= third { return 1 }
        if r <= third * 2 { return 2 }
        return 3
    }

    var effectiveTier: Int {
        max(1, baseTier - (catchUp.isActive ? catchUp.tierDrop : 0))
    }

    // MARK: - 流程

    func startMatch() {
        for i in teams.indices { teams[i].score = 0 }
        roundNumber = 1
        isOvertime = false
        firstTeamIndex = 0
        usedWords = [:]
        beginRound()
        phase = .wheel
    }

    private func beginRound() {
        playIndex = 0
        roundSmall = [0, 0]
        roundWords = [[], []]
        openBuzz = false
        playingTeamIndex = firstTeamIndex
        catchUp = CatchUp()
    }

    /// 转盘定盘（或落后队指定）。openBuzz 表示经过了抢答扇区二次转盘
    func gameDecided(_ game: GameKind, openBuzz: Bool) {
        currentGame = game
        self.openBuzz = openBuzz
        playingTeamIndex = firstTeamIndex
        refreshCatchUp()
    }

    /// 落后队直接指定玩法（不转盘、无开放抢答加成）
    func pickGame(_ game: GameKind) {
        gameDecided(game, openBuzz: false)
        phase = .handoff
    }

    /// 追分卡：只在落后队（按大分）自己那一遍激活
    private func refreshCatchUp() {
        if let trailing = trailingIndex, trailing == playingTeamIndex {
            catchUp = CatchUp.evaluate(bigDiff: bigDiff)
        } else {
            catchUp = CatchUp()
        }
    }

    func proceedToHandoff() { phase = .handoff }
    func startPlaying() { phase = .playing }

    var roundDuration: Int {
        settings.roundSeconds + (catchUp.isActive ? catchUp.extraSeconds : 0)
    }

    var skipAllowance: Int {
        GameSettings.skipsPerRound + (catchUp.isActive ? catchUp.extraSkips : 0)
    }

    /// 一遍游戏结束：own=己方猜对数，stolen=开放抢答中被对方偷走的分
    func finishPlay(own: Int, stolen: Int) {
        roundSmall[playingTeamIndex] += own
        roundSmall[opponentIndex] += stolen

        if playIndex == 0 {
            // 换后手队玩同一个游戏
            playIndex = 1
            playingTeamIndex = 1 - firstTeamIndex
            refreshCatchUp()
            phase = .handoff
        } else {
            concludeRound()
        }
    }

    /// 两遍都玩完：比小分，定大分
    private func concludeRound() {
        var awards = [0, 0]
        if roundSmall[0] > roundSmall[1] {
            awards[0] = 1
        } else if roundSmall[1] > roundSmall[0] {
            awards[1] = 1
        } else {
            awards = [1, 1]   // 小分打平，双方各 +1 大分
        }
        teams[0].score += awards[0]
        teams[1].score += awards[1]
        lastOutcome = RoundOutcome(game: currentGame, openBuzz: openBuzz,
                                   small: roundSmall, awards: awards,
                                   roundNumber: roundNumber, isOvertime: isOvertime,
                                   words: roundWords)
        phase = .roundResult
    }

    func proceedToScoreboard() { phase = .scoreboard }

    /// 记分板 → 下一轮 / 加时 / 终局
    func nextTurn() {
        if roundNumber >= totalRounds {
            if teams[0].score == teams[1].score {
                // 大分平：加时赛，一轮定胜负（还平就继续加时）
                isOvertime = true
                roundNumber += 1
                firstTeamIndex = 1 - firstTeamIndex
                beginRound()
                phase = .wheel
            } else {
                phase = .victory
            }
            return
        }
        roundNumber += 1
        firstTeamIndex = 1 - firstTeamIndex   // 先手轮换
        beginRound()
        phase = .wheel
    }

    func resetToHome() {
        phase = .home
        for i in teams.indices { teams[i].score = 0 }
        roundNumber = 1
        isOvertime = false
    }

    // MARK: - 词库派发（同一轮两队共用去重池，保证不重复）

    func nextWord() -> String {
        let tier = effectiveTier
        let pool = WordBank.words(for: currentGame, tier: tier)
        let key = "\(LanguageManager.shared.language.rawValue)-\(currentGame.rawValue)-\(tier)"
        var used = usedWords[key] ?? []
        if used.count >= pool.count { used = [] }   // 词库用尽后重置
        var idx = Int.random(in: 0..<pool.count)
        while used.contains(idx) { idx = Int.random(in: 0..<pool.count) }
        used.insert(idx)
        usedWords[key] = used
        let w = pool[idx]
        roundWords[playingTeamIndex].append(w)
        return w
    }
}
