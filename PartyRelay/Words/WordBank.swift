import Foundation

/// 词库统一入口：每玩法一个词池（不分难度档位），中英双套（随当前语言自动切换）
///
/// 词池大小按玩法难度反着排：越好猜的玩法一局过词越快，词池就越大——
/// 你说我猜 > 你画我猜 > 动作 > 唇语 > 表情管理。
enum WordBank {

    static func words(for kind: GameKind) -> [String] {
        let en = LanguageManager.shared.language == .en
        switch kind {
        case .describeGuess:
            return en ? DescribeWordsEN.pool : DescribeWords.pool
        case .drawGuess:
            return en ? DrawWordsEN.pool : DrawWords.pool
        case .lipRead:
            return en ? LipWordsEN.pool : LipWords.pool
        case .act:
            return en ? ActWordsEN.pool : ActWords.pool
        case .emojiCode:
            return en ? EmojiWordsEN.pool : EmojiWords.pool
        case .hallOfFame:
            return []   // 名人堂另有名字池，见 hallOfFameNames()
        case .quiz:
            return []   // 抢答是转盘修饰符扇区，从不作为可玩玩法取词
        }
    }

    /// 名人堂名字池（随当前语言切换）
    static func hallOfFameNames() -> [String] {
        LanguageManager.shared.language == .en ? HallOfFameNamesEN.pool : HallOfFameNames.pool
    }
}
