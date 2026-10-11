import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 队伍

struct Team: Identifiable {
    let id: Int
    var name: String
    var score: Int = 0          // 大分（赛点）
    var smallTotal: Int = 0     // 累计小分（小分制下用它定胜负）
    var emoji: String
    var colors: [Color]

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 队伍色的浅色版（整页背景用：红队 → 浅红，蓝队 → 浅蓝）
    /// 只往白里混一半，保证一眼看得出是哪个队，同时上面的文字还读得清
    var tintedBackground: [Color] {
        colors.map { $0.lightened(0.5) }
    }
}

extension Color {
    /// 与白色混合得到浅色版本（0 = 原色，1 = 纯白）
    func lightened(_ amount: Double) -> Color {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let mix = { (c: CGFloat) in c + (1 - c) * CGFloat(amount) }
        return Color(red: mix(r), green: mix(g), blue: mix(b))
        #else
        return self.opacity(1 - amount)
        #endif
    }
}

// MARK: - 出现过的词（附猜对 / 跳过状态，供交接页与记分板回顾）

struct PlayedWord: Identifiable, Equatable {
    let id = UUID()
    var text: String
    /// true = 被猜对（含被对方抢答猜对）；false = 跳过，或时间到时还没猜出来
    var guessed: Bool = false
    /// 轮流模式：是谁猜出来的（交接页回顾里跟在词后面显示）
    var guessedBy: String? = nil
}

// MARK: - 游戏模式（主页三选一）

enum PlayMode: String, CaseIterable, Identifiable {
    case match      // 对战：红蓝两队，多轮比分
    case quick      // 快速：不分队、不记分，转一次盘打一局
    case rotation   // 轮流：每人轮流拿手机表演，猜对的人和表演者各 +1

    var id: String { rawValue }

    /// 快速和轮流都没有队伍：名人堂（两队同时进行）和抢答（偷对方的分）都用不上
    var hasTeams: Bool { self == .match }

    var title: String { L("mode.\(rawValue).title") }
    var blurb: String { L("mode.\(rawValue).blurb") }

    var emoji: String {
        switch self {
        case .match:    return "⚔️"
        case .quick:    return "⚡️"
        case .rotation: return "🔄"
        }
    }

    var colors: [Color] {
        switch self {
        // 对战卡就是红蓝两队的队色拼在一起
        case .match:    return [Color(red: 1.0, green: 0.35, blue: 0.37), Color(red: 0.25, green: 0.52, blue: 1.0)]
        case .quick:    return [Color(red: 0.19, green: 0.69, blue: 0.78), Color(red: 0.36, green: 0.86, blue: 0.82)]
        case .rotation: return [Color(red: 1.0, green: 0.62, blue: 0.10), Color(red: 0.98, green: 0.36, blue: 0.56)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 轮流模式的玩家

struct Player: Identifiable, Equatable {
    /// 身份：改名、换头像、拖动换位置都不变（SwiftUI 列表和拖动排序靠它认人）
    let id: UUID
    /// 头像编号（0 起，同一局里不重复）：头像、颜色、默认名都跟着它走。
    /// 不按座位顺序分配——删掉或挪动某个人时，其他人的头像和颜色不能跟着错位
    var avatar: Int
    var name: String
    var performPoints = 0   // 自己表演时被别人猜对的次数
    var guessPoints = 0     // 猜对别人表演的次数

    var score: Int { performPoints + guessPoints }

    static let countRange = 2...12
    static let defaultCount = 4

    static let emojis = ["🦊", "🐼", "🐨", "🐯", "🐸", "🐙", "🦄", "🐧", "🐰", "🐻", "🐵", "🦉"]

    /// 12 个座位各一套颜色，彼此拉得开，名字围成一圈时一眼分得清谁是谁
    static let palette: [[Color]] = [
        [Color(red: 1.00, green: 0.42, blue: 0.42), Color(red: 1.00, green: 0.62, blue: 0.45)],
        [Color(red: 0.25, green: 0.56, blue: 1.00), Color(red: 0.35, green: 0.80, blue: 1.00)],
        [Color(red: 0.58, green: 0.34, blue: 0.95), Color(red: 0.84, green: 0.45, blue: 0.95)],
        [Color(red: 0.16, green: 0.72, blue: 0.42), Color(red: 0.52, green: 0.86, blue: 0.30)],
        [Color(red: 1.00, green: 0.60, blue: 0.08), Color(red: 1.00, green: 0.80, blue: 0.22)],
        [Color(red: 0.96, green: 0.32, blue: 0.62), Color(red: 1.00, green: 0.55, blue: 0.75)],
        [Color(red: 0.06, green: 0.64, blue: 0.68), Color(red: 0.28, green: 0.84, blue: 0.78)],
        [Color(red: 0.32, green: 0.34, blue: 0.88), Color(red: 0.50, green: 0.56, blue: 1.00)],
        [Color(red: 0.80, green: 0.42, blue: 0.18), Color(red: 0.94, green: 0.62, blue: 0.30)],
        [Color(red: 0.42, green: 0.48, blue: 0.56), Color(red: 0.62, green: 0.68, blue: 0.76)],
        [Color(red: 0.86, green: 0.20, blue: 0.30), Color(red: 0.98, green: 0.40, blue: 0.40)],
        [Color(red: 0.36, green: 0.62, blue: 0.20), Color(red: 0.62, green: 0.80, blue: 0.24)],
    ]

    init(avatar: Int, name: String) {
        self.id = UUID()
        self.avatar = avatar
        self.name = name
    }

    var emoji: String { Self.emoji(avatar) }
    var colors: [Color] { Self.colors(avatar) }
    static func emoji(_ avatar: Int) -> String { emojis[avatar % emojis.count] }
    static func colors(_ avatar: Int) -> [Color] { palette[avatar % palette.count] }
    static func gradient(_ avatar: Int) -> LinearGradient {
        LinearGradient(colors: colors(avatar), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 名字还是默认名（没改过）
    var hasDefaultName: Bool { name == Self.defaultName(avatar) }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func defaultName(_ seat: Int) -> String { L("player.default_name", seat + 1) }

    /// 还没被占用的最小头像编号（加人时用）
    static func nextFreeAvatar(in players: [Player]) -> Int {
        let used = Set(players.map(\.avatar))
        return (0..<emojis.count).first { !used.contains($0) } ?? players.count
    }

    // MARK: 持久化（存名字和头像编号：同一群朋友下次打开不用重新输入）
    private static let key = "PartyRelay.players.v2"
    private static let legacyKey = "PartyRelay.players.v1"   // 只存了名字，编号就是座位顺序

    static func save(_ players: [Player]) {
        UserDefaults.standard.set(players.map { ["avatar": $0.avatar, "name": $0.name] as [String: Any] },
                                  forKey: key)
    }

    static func load() -> [Player] {
        var stored: [(Int, String)] = []
        if let rows = UserDefaults.standard.array(forKey: key) as? [[String: Any]] {
            stored = rows.compactMap { row in
                // 早期开发版存的键叫 id
                guard let avatar = (row["avatar"] ?? row["id"]) as? Int,
                      (0..<emojis.count).contains(avatar) else { return nil }
                return (avatar, row["name"] as? String ?? "")
            }
            // 编号重复（不该发生）就当存档坏了
            if Set(stored.map(\.0)).count != stored.count { stored = [] }
        } else if let names = UserDefaults.standard.stringArray(forKey: legacyKey) {
            stored = names.enumerated().map { ($0.offset, $0.element) }
        }
        guard countRange.contains(stored.count) else {
            return (0..<defaultCount).map { Player(avatar: $0, name: defaultName($0)) }
        }
        return stored.map { avatar, name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return Player(avatar: avatar, name: trimmed.isEmpty ? defaultName(avatar) : trimmed)
        }
    }
}

/// 轮流模式里一个人刚表演完的那一轮（交接给下一个人时回顾用）
struct RotationTurn {
    var performer: Int
    var points: Int
    var words: [PlayedWord]
}

// MARK: - 玩法

enum GameKind: String, CaseIterable, Identifiable, Codable {
    case describeGuess   // 你说我猜
    case drawGuess       // 你画我猜
    case lipRead         // 唇语
    case act             // 动作
    case emojiCode       // 表情管理（只用 emoji 拼出词语；rawValue 保持不变，别动存档）
    case hallOfFame      // 名人堂（两队同时进行，没有交接与计时）
    case quiz            // 开放抢答（修饰符扇区，不是独立游戏）

    var id: String { rawValue }

    /// 暂时下架的玩法：转盘、主页标签、设置列表里都不出现。
    /// 代码、词库、本地化文案全部原样留着——想放回去，把它从这个集合里删掉就行
    static let hidden: Set<GameKind> = [.emojiCode]

    var isHidden: Bool { Self.hidden.contains(self) }

    /// 可以实际游玩的玩法（抢答只是转盘上的加成扇区）
    var isPlayable: Bool { self != .quiz }

    /// 两队同时进行、不分先后手的玩法（不走交接页 / 计时 / 两遍比小分）
    var isSimultaneous: Bool { self == .hallOfFame }

    /// 能否作为开放抢答二次转盘的结果：抢答本身不行，
    /// 名人堂也不行（两队同时全员参与，没有「对方偷分」的位置）
    var allowsOpenBuzz: Bool { isPlayable && !isSimultaneous }

    var title: String {
        L("game.\(rawValue).title")
    }

    var emoji: String {
        switch self {
        case .describeGuess: return "🗣️"
        case .drawGuess:     return "🎨"
        case .lipRead:       return "🤐"
        case .act:           return "🕺"
        case .emojiCode:     return "😜"
        case .hallOfFame:    return "🌟"
        case .quiz:          return "⚡️"
        }
    }

    var rule: String {
        L("game.\(rawValue).rule")
    }

    var colors: [Color] {
        switch self {
        // 前两个玩法刻意避开红/橙与蓝/青：那两套是红队和蓝队的队色，撞色会让人以为转盘在指定队伍
        case .describeGuess: return [Color(red: 0.06, green: 0.71, blue: 0.65), Color(red: 0.31, green: 0.89, blue: 0.72)]
        case .drawGuess:     return [Color(red: 0.34, green: 0.08, blue: 0.42), Color(red: 0.65, green: 0.21, blue: 0.76)]
        case .lipRead:       return [Color(red: 0.66, green: 0.36, blue: 0.97), Color(red: 0.96, green: 0.45, blue: 0.90)]
        case .act:           return [Color(red: 0.13, green: 0.77, blue: 0.49), Color(red: 0.62, green: 0.90, blue: 0.22)]
        case .emojiCode:     return [Color(red: 0.96, green: 0.27, blue: 0.47), Color(red: 0.55, green: 0.25, blue: 0.90)]
        case .hallOfFame:    return [Color(red: 0.28, green: 0.26, blue: 0.82), Color(red: 0.60, green: 0.36, blue: 0.96)]
        case .quiz:          return [Color(red: 1.00, green: 0.76, blue: 0.12), Color(red: 1.00, green: 0.45, blue: 0.26)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 设置

struct GameSettings {
    var enabled: Set<GameKind> = Set(GameKind.allCases)
    var totalRounds: Int = 6          // 总轮数 3~10（每轮两队同玩比小分）
    var roundSeconds: Int = 60        // 每队单局时长
    /// 表情管理专用加时：这个玩法要先在键盘里翻表情，同样的单局时长能猜的词更少，
    /// 所以轮到它时在单局时长上再加这么多秒。调到 0 就是不加时
    var emojiBonusSeconds: Int = 30
    var maxSkips: Int = 3             // 每局可跳过次数（可调）
    var feedbackOn: Bool = true       // 震动+音效总开关
    var privacyGuardOn: Bool = false  // 防偷窥模式（姿态感应隐词），默认关闭
    var smallScoreWin: Bool = false   // 小分制：不设大分，累计小分高者胜
    /// 主页上最后选的模式。快速 / 轮流都没有队伍，
    /// 名人堂和抢答都用不上（两个都要有对手），玩法列表里直接不出现
    var playMode: PlayMode = .match

    static let skipsRange = 0...10
    static let handoffCountdown = 5   // 交接页「开始」按钮的等待秒数

    /// 每队单局时长的可调范围：最长 10 分钟，步进 30 秒（不然从 30 调到 600 要按到手酸）
    static let roundSecondsRange = 30...600
    static let roundSecondsStep = 30

    /// 表情管理加时的可调范围（步进 10 秒，0 = 不加时）
    static let emojiBonusRange = 0...120
    static let emojiBonusStep = 10

    var enabledList: [GameKind] {
        GameKind.allCases.filter { enabled.contains($0) && !$0.isHidden }
    }

    /// 可实际游玩的已启用玩法
    var playableList: [GameKind] {
        enabledList.filter(\.isPlayable)
    }

    /// 不分队的模式（快速 / 轮流）能玩的玩法：名人堂要两队同时进行，这两个模式里没有对手
    var soloPool: [GameKind] {
        playableList.filter { !$0.isSimultaneous }
    }

    /// 当前模式下真正用得上的玩法（列表和开关都只显示这些）：
    /// 不分队时名人堂和抢答都需要对手，直接不出现
    var relevantGames: [GameKind] {
        GameKind.allCases.filter {
            guard !$0.isHidden else { return false }
            return playMode.hasTeams ? true : ($0.isPlayable && !$0.isSimultaneous)
        }
    }

    /// 当前模式下「至少要留一个」的那批玩法：关到只剩一个时不许再关
    var requiredPool: [GameKind] {
        playMode.hasTeams ? playableList : soloPool
    }

    /// 开放抢答二次转盘的候选池（名人堂不参与抢答）
    var openBuzzPool: [GameKind] {
        playableList.filter(\.allowsOpenBuzz)
    }

    /// 转盘扇区：抢答扇区只有在「二次转盘还有玩法可转」时才有意义
    var wheelList: [GameKind] {
        if playableList.isEmpty { return [] }
        if openBuzzPool.isEmpty { return enabledList.filter { $0 != .quiz } }
        return enabledList
    }

    /// 转盘实际只有一种结果时的那个玩法（抢答不算独立玩法，它只会二次转盘回到普通玩法）
    var soleGame: GameKind? {
        playableList.count == 1 ? playableList[0] : nil
    }

    // MARK: 持久化
    private static let key = "PartyRelay.settings.v2"

    func save() {
        let dict: [String: Any] = [
            "enabled": enabledList.map(\.rawValue),
            // 记下这次存档「见过」哪些玩法，新版本新增的玩法默认为开启
            "known": GameKind.allCases.map(\.rawValue),
            "totalRounds": totalRounds,
            "roundSeconds": roundSeconds,
            "emojiBonusSeconds": emojiBonusSeconds,
            "maxSkips": maxSkips,
            "feedbackOn": feedbackOn,
            "privacyGuardOn": privacyGuardOn,
            "smallScoreWin": smallScoreWin,
            "playMode": playMode.rawValue,
        ]
        UserDefaults.standard.set(dict, forKey: Self.key)
    }

    static func load() -> GameSettings {
        var s = GameSettings()
        guard let dict = UserDefaults.standard.dictionary(forKey: key) else { return s }
        if let raw = dict["enabled"] as? [String] {
            var set = Set(raw.compactMap(GameKind.init(rawValue:)))
            // 老存档里还没有的玩法（版本更新新增的）默认开启
            let known = Set((dict["known"] as? [String] ?? raw).compactMap(GameKind.init(rawValue:)))
            set.formUnion(GameKind.allCases.filter { !known.contains($0) })
            if !set.filter(\.isPlayable).isEmpty { s.enabled = set }
        }
        if let r = dict["totalRounds"] as? Int, (3...10).contains(r) { s.totalRounds = r }
        if let t = dict["roundSeconds"] as? Int, roundSecondsRange.contains(t) { s.roundSeconds = t }
        // 老存档里没有这项（后加的设置）→ 保持默认 30 秒
        if let e = dict["emojiBonusSeconds"] as? Int, emojiBonusRange.contains(e) { s.emojiBonusSeconds = e }
        if let k = dict["maxSkips"] as? Int, skipsRange.contains(k) { s.maxSkips = k }
        if let f = dict["feedbackOn"] as? Bool { s.feedbackOn = f }
        if let p = dict["privacyGuardOn"] as? Bool { s.privacyGuardOn = p }
        if let m = dict["smallScoreWin"] as? Bool { s.smallScoreWin = m }
        if let m = (dict["playMode"] as? String).flatMap(PlayMode.init(rawValue:)) {
            s.playMode = m
        } else if dict["soloMode"] as? Bool == true {
            // 1.1 存的是快速模式开关
            s.playMode = .quick
        }
        return s
    }
}

// MARK: - 追分卡（落后补偿，按大分差；只在落后队自己那一遍生效）

struct CatchUp {
    var level: Int = 0          // 0=未激活
    var extraSeconds: Int = 0   // 时间加成
    var extraSkips: Int = 0     // 额外跳过次数

    var isActive: Bool { level > 0 }

    /// diff 是「归一化后的落后幅度」：大分制下直接是大分差，小分制下按每轮约 3 小分折算
    static func evaluate(diff: Int) -> CatchUp {
        var c = CatchUp()
        guard diff >= 2 else { return c }
        c.level = 1
        c.extraSeconds = 15
        if diff >= 3 {
            c.level = 2
            c.extraSkips = 2
        }
        return c
    }

    /// 玩家可见的加成提示
    var perks: [String] {
        var p: [String] = []
        if extraSeconds > 0 { p.append(L("catchup.time", extraSeconds)) }
        if extraSkips > 0 { p.append(L("catchup.skips", extraSkips)) }
        return p
    }
}

// MARK: - 回合结果（一轮 = 两队同玩一个游戏，比小分定大分）

struct RoundOutcome {
    var game: GameKind
    var openBuzz: Bool
    var small: [Int]        // 两队本轮小分
    var awards: [Int]       // 两队本轮获得的大分（0或1；平小分则双方各1）
    var roundNumber: Int
    var isOvertime: Bool
    var words: [[PlayedWord]]   // 两队本轮各自出现过的词（按队伍下标）
}

// MARK: - 流程状态机

enum Phase: Equatable {
    case menu        // 模式三选一（启动页）
    case home        // 选好模式后的准备页（分队 / 填玩家 / 选玩法）
    case wheel       // 转盘（含落后队指定玩法入口）
    case handoff     // 交接遮挡屏
    case playing     // 游戏中（当前队那一遍）
    case hallOfFame  // 名人堂（两队同时进行的整局流程）
    case soloResult  // 不分队快速局的成绩页
    case rotationResult // 轮流模式一整轮的个人总分
    case roundResult // 本轮小分对比 & 大分结算
    case scoreboard  // 记分板（大分 + 上轮小分）
    case victory     // 终局
}
