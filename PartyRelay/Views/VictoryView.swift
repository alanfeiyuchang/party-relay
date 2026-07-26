import SwiftUI

struct VictoryView: View {
    @EnvironmentObject var store: GameStore
    @State private var pop = false

    var body: some View {
        ZStack {
            if let w = store.winnerIndex {
                let team = store.teams[w]
                Rectangle()
                    .fill(team.gradient)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer()
                    Text("🏆")
                        .font(.system(size: 100))
                        .scaleEffect(pop ? 1 : 0.3)
                        .rotationEffect(.degrees(pop ? 0 : -20))
                    Text("\(team.emoji) \(team.name)")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 24)
                    Text(L("victory.wins"))
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .scaleEffect(pop ? 1 : 0.5)

                    HStack(spacing: 20) {
                        ForEach(store.teams) { t in
                            VStack(spacing: 4) {
                                Text("\(t.emoji) \(t.name)").font(.headline)
                                Text("\(store.matchScore(t.id))")
                                    .font(.system(size: 40, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .opacity(t.id == w ? 1 : 0.6)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 30)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.2)))

                    Spacer()

                    Button {
                        FeedbackManager.shared.tap()
                        store.startMatch()
                    } label: {
                        Label(L("victory.again"), systemImage: "arrow.counterclockwise.circle.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: [.white, .white.opacity(0.9)],
                                                textColor: team.colors[0]))
                    .padding(.horizontal, 32)

                    Button(L("victory.home")) { store.resetToHome() }
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 30)
                }

                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            FeedbackManager.shared.victory()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.5).delay(0.1)) {
                pop = true
            }
        }
    }
}
