import Foundation

/// 词库统一入口：每玩法独立、3档难度、中英双套（随当前语言自动切换）
enum WordBank {

    static func words(for kind: GameKind, tier: Int) -> [String] {
        let t = min(3, max(1, tier))
        let en = LanguageManager.shared.language == .en
        switch kind {
        case .describeGuess:
            return en ? [DescribeWordsEN.tier1, DescribeWordsEN.tier2, DescribeWordsEN.tier3][t - 1]
                      : [DescribeWords.tier1, DescribeWords.tier2, DescribeWords.tier3][t - 1]
        case .drawGuess:
            return en ? [DrawWordsEN.tier1, DrawWordsEN.tier2, DrawWordsEN.tier3][t - 1]
                      : [DrawWords.tier1, DrawWords.tier2, DrawWords.tier3][t - 1]
        case .lipRead:
            return en ? [LipWordsEN.tier1, LipWordsEN.tier2, LipWordsEN.tier3][t - 1]
                      : [LipWords.tier1, LipWords.tier2, LipWords.tier3][t - 1]
        case .act:
            return en ? [ActWordsEN.tier1, ActWordsEN.tier2, ActWordsEN.tier3][t - 1]
                      : [ActWords.tier1, ActWords.tier2, ActWords.tier3][t - 1]
        case .hallOfFame:
            return []   // 名人堂不按难度档位取词，见 hallOfFameNames()
        case .quiz:
            return []   // 抢答是转盘修饰符扇区，从不作为可玩玩法取词
        }
    }

    /// 名人堂名字池（随当前语言切换，不分难度档位）
    static func hallOfFameNames() -> [String] {
        LanguageManager.shared.language == .en ? HallOfFameNamesEN.pool : HallOfFameNames.pool
    }
}
