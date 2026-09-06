import SwiftUI

/// 不分队快速局的成绩页：只报这一局猜对了几个，附出现过的词
struct SoloResultView: View {
    @EnvironmentObject var store: GameStore
    @State private var pop = false

    private var score: Int { store.roundSmall[0] }
    private var words: [PlayedWord] { store.roundWords[0] }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(store.currentGame.gradient)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HomeExitBar(light: true)

                Spacer()

                Text(store.currentGame.emoji)
                    .font(.system(size: 64))
                Text(store.currentGame.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(score)")
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(pop ? 1 : 0.3)
                Text(L("solo.result_label"))
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.9))

                if !words.isEmpty {
                    VStack(spacing: 8) {
                        Text(L("solo.words_label"))
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.9))
                        ScrollView {
                            FlowLayout(spacing: 6) {
                                ForEach(words) { w in
                                    PlayedWordChip(word: w,
                                                   tint: AnyShapeStyle(Color.white),
                                                   textColor: .black.opacity(0.8),
                                                   font: .footnote.bold())
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                        Text(L("handoff.recap_legend"))
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.black.opacity(0.18)))
                    .padding(.horizontal, 22)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        FeedbackManager.shared.tap()
                        store.startSolo()
                    } label: {
                        Label(L("solo.again"), systemImage: "arrow.counterclockwise.circle.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: [.white, .white.opacity(0.92)],
                                                textColor: store.currentGame.colors[0]))

                    Button(L("victory.home")) { store.resetToHome() }
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            FeedbackManager.shared.roundSettle()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.15)) {
                pop = true
            }
        }
    }
}
