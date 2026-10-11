import SwiftUI

/// 启动页：模式三选一（对战 / 快速 / 轮流），选完进该模式的准备页
struct ModeMenuView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PartyBackground()

            FittingScroll { _ in
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Text("🎉")
                            .font(.system(size: 44))
                        Text(L("app.title"))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.pink, .orange, .purple],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                        Text(L("menu.subtitle"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        ForEach(PlayMode.allCases) { mode in
                            ModeCard(mode: mode) {
                                FeedbackManager.shared.tap()
                                store.chooseMode(mode)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 68)
            }

            LanguageToggleButton()
                .padding(.trailing, 20)
                .padding(.top, 18)
        }
    }
}

private struct ModeCard: View {
    var mode: PlayMode
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(mode.emoji)
                    .font(.system(size: 38))
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.title2.bold())
                    Text(mode.blurb)
                        .font(.subheadline.bold())
                        .opacity(0.92)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(mode.gradient)
                    .shadow(color: mode.colors[0].opacity(0.4), radius: 10, y: 5)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("mode.\(mode.rawValue)")
    }
}

/// 按下时轻微缩小，跟大按钮的手感一致
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 右上角的中 / 英切换（启动页和准备页共用）
struct LanguageToggleButton: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared

    var body: some View {
        Button {
            FeedbackManager.shared.tap()
            langManager.toggle()
            store.syncTeamNamesToLanguage()
        } label: {
            Label(langManager.language.toggleLabel, systemImage: "globe")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(LinearGradient(colors: [.indigo, .purple],
                                                  startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .purple.opacity(0.35), radius: 5, y: 2)
                )
        }
    }
}
