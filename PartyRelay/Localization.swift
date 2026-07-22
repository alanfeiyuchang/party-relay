import Foundation
import Combine

// MARK: - 应用语言

enum AppLanguage: String, CaseIterable {
    case zh = "zh-Hans"
    case en = "en"

    /// 主界面切换按钮上显示的"目标语言"标签
    var toggleLabel: String {
        switch self {
        case .zh: return "EN"      // 当前中文 → 按钮显示 EN
        case .en: return "中文"     // 当前英文 → 按钮显示 中文
        }
    }
}

// MARK: - 语言管理器（切换即时全局生效，UserDefaults 持久化）

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let storageKey = "PartyRelay.language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
            reloadBundle()
        }
    }

    private(set) var bundle: Bundle = .main

    private init() {
        // 优先级：截图环境变量 > 用户手动选择 > 系统语言（中文→中文，其余→英文）
        if let env = ProcessInfo.processInfo.environment["SCREENSHOT_LANG"],
           let lang = AppLanguage(rawValue: env == "zh" ? "zh-Hans" : "en") {
            language = lang
        } else if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
                  let lang = AppLanguage(rawValue: stored) {
            language = lang
        } else {
            let sys = Locale.preferredLanguages.first ?? "en"
            language = sys.hasPrefix("zh") ? .zh : .en
        }
        reloadBundle()
    }

    private func reloadBundle() {
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = .main
        }
    }

    func toggle() {
        language = language == .zh ? .en : .zh
    }
}

// MARK: - 取词辅助

/// 本地化字符串
func L(_ key: String) -> String {
    LanguageManager.shared.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// 带格式参数的本地化字符串
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
