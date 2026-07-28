import SwiftUI
import UIKit

/// 只收表情的输入框：直接唤起系统 emoji 键盘（自带搜索，找表情比自制键盘快得多），
/// 同时把非表情的输入（打字、粘贴、听写）全部挡在门外——这个玩法唯一的规则就是只能用表情。
struct EmojiField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var maxCount: Int
    var placeholder: String

    func makeUIView(context: Context) -> EmojiOnlyTextField {
        let field = EmojiOnlyTextField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 34)
        field.textAlignment = .center
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartInsertDeleteType = .no
        field.tintColor = .systemIndigo
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.editingChanged(_:)),
                        for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: EmojiOnlyTextField, context: Context) {
        if field.text != text { field.text = text }
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                         .foregroundColor: UIColor.secondaryLabel]
        )
        // 放到下一次 runloop：更新阶段里直接改第一响应者会打断 SwiftUI 的布局
        let wantsFocus = focused
        DispatchQueue.main.async {
            if wantsFocus, !field.isFirstResponder {
                field.becomeFirstResponder()
            } else if !wantsFocus, field.isFirstResponder {
                field.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: EmojiField
        /// 正在重建键盘：这期间的失去焦点是我们自己造成的，别同步回 SwiftUI
        private var isResettingKeyboard = false

        init(_ parent: EmojiField) { self.parent = parent }

        /// 兜底再筛一遍：听写、第三方键盘之类不走 shouldChangeCharactersIn 的输入途径也漏不进来
        @objc func editingChanged(_ field: UITextField) {
            let raw = field.text ?? ""
            let cleaned = String(raw.filter(\.isEmojiCharacter).prefix(parent.maxCount))
            if raw != cleaned { field.text = cleaned }
            parent.text = cleaned
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            guard !isResettingKeyboard else { return }
            parent.focused = false
        }

        /// 选完一个表情就把系统键盘重建一次，好让 emoji 键盘的搜索框回到空白，
        /// 不用先手动删掉上一次的搜索词才能搜下一个。
        ///
        /// 搜索框是系统键盘的一部分，没有任何 API 能直接读写它，只能整个重建；
        /// 交还再立刻拿回第一响应者是同一次 runloop 内完成的，键盘不会有收起再弹出的动画。
        func resetKeyboard(_ field: UITextField) {
            guard field.isFirstResponder else { return }
            isResettingKeyboard = true
            field.resignFirstResponder()
            field.becomeFirstResponder()
            isResettingKeyboard = false
        }

        /// 只放行表情，并卡住长度上限
        func textField(_ field: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            guard !string.isEmpty else { return true }   // 退格
            guard string.allSatisfy(\.isEmojiCharacter) else {
                FeedbackManager.shared.locked()
                return false
            }
            let current = field.text ?? ""
            guard let r = Range(range, in: current) else { return false }
            guard current.replacingCharacters(in: r, with: string).count <= parent.maxCount else {
                FeedbackManager.shared.locked()
                return false
            }
            FeedbackManager.shared.tap()
            // 等这次插入落定后再重建键盘，免得打断键盘自己的输入流程
            DispatchQueue.main.async { [weak field] in
                guard let field else { return }
                self.resetKeyboard(field)
            }
            return true
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

/// 强制使用系统 emoji 键盘的输入框
final class EmojiOnlyTextField: UITextField {
    // iOS 13 起必须给一个非 nil 的标识，键盘才会记住这里要用 emoji 模式
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        // 玩家真把 emoji 键盘从系统里删掉时返回 nil（退回默认键盘），
        // 打的字照样会被 shouldChangeCharactersIn 挡下来
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
    }

    /// 不给复制/粘贴/听写留口子
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
}

extension Character {
    /// 是不是一个表情：
    /// - 多标量的（ZWJ 组合、带变体选择符、数字键帽、旗帜）看首标量是不是 emoji；
    /// - 单标量的要求它本身「默认就以表情呈现」，这样字母、数字、标点、空格都会被挡下。
    var isEmojiCharacter: Bool {
        guard let first = unicodeScalars.first else { return false }
        if unicodeScalars.count > 1 { return first.properties.isEmoji }
        return first.properties.isEmojiPresentation
    }
}
