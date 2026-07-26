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
    @Published var firstTeamIndex: Int = 0       // 本轮先手队：红队恒定先手（不再轮换）
    @Published var playIndex: Int = 0            // 0=先手那一遍，1=后手那一遍
    @Published var playingTeamIndex: Int = 0     // 当前执机队
    @Published var currentGame: GameKind = .describeGuess
    @Published var openBuzz = false              // 开放抢答加成（对方可抢答偷分）
    @Published var roundSmall: [Int] = [0, 0]    // 本轮两队小分
    @Published var roundWords: [[String]] = [[], []]  // 本轮两队各自出现过的词（按队伍下标）
    @Published var catchUp: CatchUp = CatchUp()
    @Published var lastOutcome: RoundOutcome?
    @Published var hofNames: [String] = ["", ""]      // 名人堂：两队各自被指定的名人

    private var usedWords: [String: Set<Int>] = [:]   // "game-tier" -> 已用下标
    private var usedHofNames: Set<String> = []        // 名人堂：本局已用过的名字（跨轮不重复）

    var playingTeam: Team { teams[playingTeamIndex] }
    var opponentIndex: Int { 1 - playingTeamIndex }
    var totalRounds: Int { settings.totalRounds }
    var completedRounds: Int { roundNumber - 1 }

    // MARK: - 比分 / 落后判断（大分制看大分，小分制看累计小分）

    /// 小分制：不设大分，累计小分决定胜负
    var smallScoreWin: Bool { settings.smallScoreWin }

    /// 当前计分制下用于排名的比分
    func matchScore(_ index: Int) -> Int {
        smallScoreWin ? teams[index].smallTotal : teams[index].score
    }

    var winnerIndex: Int? {
        if matchScore(0) == matchScore(1) { return nil }
        return matchScore(0) > matchScore(1) ? 0 : 1
    }

    var trailingIndex: Int? {
        if matchScore(0) == matchScore(1) { return nil }
        return matchScore(0) < matchScore(1) ? 0 : 1
    }

    var scoreDiff: Int { abs(matchScore(0) - matchScore(1)) }

    /// 追分卡用的归一化差值：小分制下小分差按每轮约 3 分折算成「大分档位」
    var catchUpDiff: Int { smallScoreWin ? scoreDiff / 3 : scoreDiff }

    /// 平衡策略：已进行轮数达到总轮数 2/3 后，落后队可直接指定玩法（不转盘）
    /// 只有一个玩法时没有可选项，直接不给这个特权
    var pickEligibleTeam: Int? {
        guard settings.soleGame == nil else { return nil }
        guard Double(completedRounds) >= Double(totalRounds) * 2.0 / 3.0 else { return nil }
        return trailingIndex
    }

    // MARK: - 玩法开关（设置页与主界面标签弹窗共用同一份状态）

    /// 普通玩法至少保留 1 个（抢答是加成扇区，不算数）
    func gameEnabledBinding(for kind: GameKind) -> Binding<Bool> {
        Binding { [weak self] in
            self?.settings.enabled.contains(kind) ?? false
        } set: { [weak self] on in
            guard let self else { return }
            if on {
                FeedbackManager.shared.tap()
                self.settings.enabled.insert(kind)
            } else if kind == .quiz || self.settings.playableList.count > 1 {
                FeedbackManager.shared.tap()
                self.settings.enabled.remove(kind)
            } else {
                FeedbackManager.shared.locked()   // 拒绝关掉最后一个普通玩法
            }
        }
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
        for i in teams.indices {
            teams[i].score = 0
            teams[i].smallTotal = 0
        }
        roundNumber = 1
        isOvertime = false
        firstTeamIndex = 0
        lastOutcome = nil
        usedWords = [:]
        usedHofNames = []
        beginRound()
        enterGameSelection()
    }

    /// 进入玩法选择：转盘只有一种结果时（只开了一个普通玩法）直接进那个游戏，不转盘
    private func enterGameSelection() {
        if let only = settings.soleGame {
            gameDecided(only, openBuzz: false)
            enterDecidedGame()
        } else {
            phase = .wheel
        }
    }

    /// 定盘后进入正式流程：同时进行的玩法（名人堂）没有交接页，直接进自己的整局流程
    func enterDecidedGame() {
        phase = currentGame.isSimultaneous ? .hallOfFame : .handoff
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
        if game.isSimultaneous {
            // 两队同时玩：没有先后手，也就没有落后队专属的追分加成
            self.openBuzz = false
            catchUp = CatchUp()
            assignHallOfFameNames()
        } else {
            refreshCatchUp()
        }
    }

    /// 落后队直接指定玩法（不转盘、无开放抢答加成）
    func pickGame(_ game: GameKind) {
        gameDecided(game, openBuzz: false)
        enterDecidedGame()
    }

    /// 追分卡：只在落后队自己那一遍激活
    private func refreshCatchUp() {
        if let trailing = trailingIndex, trailing == playingTeamIndex {
            catchUp = CatchUp.evaluate(diff: catchUpDiff)
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
        settings.maxSkips + (catchUp.isActive ? catchUp.extraSkips : 0)
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

    /// 两遍都玩完：大分制比小分定大分；小分制只累计小分
    private func concludeRound() {
        let awards = Self.awards(forSmall: roundSmall)
        if smallScoreWin {
            // 小分制：没有大分，本轮小分直接进累计；awards 只用于结算页高亮本轮领先方
            teams[0].smallTotal += roundSmall[0]
            teams[1].smallTotal += roundSmall[1]
        } else {
            teams[0].score += awards[0]
            teams[1].score += awards[1]
        }
        lastOutcome = RoundOutcome(game: currentGame, openBuzz: openBuzz,
                                   small: roundSmall, awards: awards,
                                   roundNumber: roundNumber, isOvertime: isOvertime,
                                   words: roundWords)
        phase = .roundResult
    }

    /// 本轮小分 → 大分归属（小分打平则双方各 +1）
    private static func awards(forSmall small: [Int]) -> [Int] {
        if small[0] > small[1] { return [1, 0] }
        if small[1] > small[0] { return [0, 1] }
        return [1, 1]
    }

    func proceedToScoreboard() { phase = .scoreboard }

    // MARK: - 名人堂（两队同时进行：各拿一个名人，互猜对方的名人）

    /// 名人堂一局的得分：小分制 +3 小分，大分制 +1 大分
    static let hallOfFameSmallPoints = 3

    /// 给两队各指定一个名人（当前语言的名字池，同一局内不重复，两队必不相同）
    func assignHallOfFameNames() {
        let pool = WordBank.hallOfFameNames()
        guard pool.count >= 2 else { return }
        var available = pool.filter { !usedHofNames.contains($0) }
        if available.count < 2 {      // 名字池用尽后重置
            usedHofNames = []
            available = pool
        }
        let first = available.randomElement()!
        let second = available.filter { $0 != first }.randomElement()!
        usedHofNames.formUnion([first, second])
        hofNames = [first, second]
        // 结算页/记分板的「本轮词」回顾即是两队的名人揭晓
        roundWords = [[first], [second]]
    }

    /// 名人堂结束：winner 队猜中对方的名人，直接结算本轮
    func finishHallOfFame(winner: Int) {
        var small = [0, 0]
        small[winner] = Self.hallOfFameSmallPoints
        var awards = [0, 0]
        awards[winner] = 1

        roundSmall = small
        if smallScoreWin {
            teams[winner].smallTotal += Self.hallOfFameSmallPoints
        } else {
            teams[winner].score += 1
        }
        lastOutcome = RoundOutcome(game: .hallOfFame, openBuzz: false,
                                   small: small, awards: awards,
                                   roundNumber: roundNumber, isOvertime: isOvertime,
                                   words: roundWords)
        phase = .roundResult
    }

    // MARK: - 主持人手动调分（纠错/裁决用，不影响自动计分流程）

    /// 手动调整总分：大分制调大分，小分制调累计小分
    func adjustTotal(team: Int, delta: Int) {
        if smallScoreWin {
            let newVal = max(0, teams[team].smallTotal + delta)
            guard newVal != teams[team].smallTotal else { return }
            FeedbackManager.shared.tap()
            teams[team].smallTotal = newVal
        } else {
            let newVal = max(0, teams[team].score + delta)
            guard newVal != teams[team].score else { return }
            FeedbackManager.shared.tap()
            teams[team].score = newVal
        }
    }

    /// 手动调整上轮小分：大分制下同步重算该轮大分归属（先撤销原奖励再按新小分重发）；
    /// 小分制下直接把差值同步到累计小分
    func adjustLastSmall(team: Int, delta: Int) {
        guard var o = lastOutcome else { return }
        let newVal = max(0, o.small[team] + delta)
        guard newVal != o.small[team] else { return }
        FeedbackManager.shared.tap()
        let applied = newVal - o.small[team]
        o.small[team] = newVal

        let newAwards = Self.awards(forSmall: o.small)
        if smallScoreWin {
            teams[team].smallTotal = max(0, teams[team].smallTotal + applied)
        } else {
            for i in teams.indices {
                teams[i].score = max(0, teams[i].score - o.awards[i] + newAwards[i])
            }
        }
        o.awards = newAwards
        lastOutcome = o
        roundSmall = o.small
    }

    /// 记分板 → 下一轮 / 加时 / 终局。红队恒定先手，不再轮换
    func nextTurn() {
        if roundNumber >= totalRounds {
            if winnerIndex == nil {
                // 比分平：加时赛，一轮定胜负（还平就继续加时）
                isOvertime = true
                roundNumber += 1
                beginRound()
                enterGameSelection()
            } else {
                phase = .victory
            }
            return
        }
        roundNumber += 1
        beginRound()
        enterGameSelection()
    }

    func resetToHome() {
        phase = .home
        for i in teams.indices {
            teams[i].score = 0
            teams[i].smallTotal = 0
        }
        roundNumber = 1
        isOvertime = false
        firstTeamIndex = 0
        lastOutcome = nil
        catchUp = CatchUp()
        roundSmall = [0, 0]
        roundWords = [[], []]
        openBuzz = false
        playIndex = 0
        playingTeamIndex = 0
        hofNames = ["", ""]
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
