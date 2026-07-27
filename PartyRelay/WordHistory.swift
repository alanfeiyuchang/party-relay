import Foundation

/// 出词历史：记录每个词库 / 名人堂名字池「已经出现过」的条目，永久保留。
///
/// 设计要点：
/// - **跨对局、跨启动、跨 App 更新都不清空**：存储键不带版本号，也没有任何启动迁移会删它。
///   老用户升级后历史照旧，新装用户读不到键、自然从空开始。
/// - **存词本身而不是下标**：词库改版增删条目后下标会整体错位，字符串不会；
///   已经不在词库里的旧词读取时顺手剔除。
/// - 池子抽干后重新洗牌，但把最近出现的一批挡在门外，避免「刚出过又出」。
final class WordHistory {
    static let shared = WordHistory()

    // 键名固定，不带版本号：App 更新后仍指向同一份历史
    private static let seenKey = "PartyRelay.wordHistory.seen"
    private static let recentKey = "PartyRelay.wordHistory.recent"

    private var seen: [String: Set<String>]
    private var recent: [String: [String]]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawSeen = defaults.dictionary(forKey: Self.seenKey) as? [String: [String]] ?? [:]
        seen = rawSeen.mapValues(Set.init)
        recent = defaults.dictionary(forKey: Self.recentKey) as? [String: [String]] ?? [:]
    }

    // MARK: - 取词

    /// 词库键：同一玩法同一档位、按语言各自独立
    static func wordKey(game: GameKind, tier: Int, language: AppLanguage) -> String {
        "\(language.rawValue)|\(game.rawValue)|\(tier)"
    }

    /// 名人堂名字池键：中英两套名字各自独立
    static func hallOfFameKey(language: AppLanguage) -> String {
        "hof|\(language.rawValue)"
    }

    /// 从 pool 里取 count 个互不相同、且此前没出现过的条目，并记入历史。
    /// 未出现过的不足 count 个时重新洗牌（排除最近出现的一批）。
    func take(_ count: Int, from pool: [String], key: String) -> [String] {
        guard count > 0, !pool.isEmpty else { return [] }

        let poolSet = Set(pool)
        // 顺手剔除词库改版后已经不存在的旧词，避免历史无限膨胀
        var used = seen[key].map { $0.intersection(poolSet) } ?? []
        var available = pool.filter { !used.contains($0) }

        if available.count < count {
            // 池子抽干：重新洗牌，但最近出现过的一批这一轮先不参与
            let blocked = Set(recent[key] ?? [])
            used = []
            available = pool.filter { !blocked.contains($0) }
            if available.count < count { available = pool }   // 池子本身太小时的兜底
        }

        var picked: [String] = []
        for _ in 0..<count {
            guard let i = available.indices.randomElement() else { break }
            picked.append(available.remove(at: i))
        }

        used.formUnion(picked)
        seen[key] = used
        recent[key] = Array(((recent[key] ?? []) + picked).suffix(Self.recentWindow(poolSize: pool.count)))
        save()
        return picked
    }

    /// 重新洗牌时要挡住的「最近出现过」条目数：池子的 1/4，最多 24 个
    private static func recentWindow(poolSize: Int) -> Int {
        max(1, min(poolSize / 4, 24))
    }

    private func save() {
        defaults.set(seen.mapValues(Array.init), forKey: Self.seenKey)
        defaults.set(recent, forKey: Self.recentKey)
    }

    /// 仅供调试 / 测试：清空历史（正式流程里没有任何地方调用它）
    func clearAll() {
        seen = [:]
        recent = [:]
        defaults.removeObject(forKey: Self.seenKey)
        defaults.removeObject(forKey: Self.recentKey)
    }
}
