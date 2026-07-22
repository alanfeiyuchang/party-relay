import SwiftUI

/// 交接遮挡屏：防止对方偷看词；后手上场时显示先手的小分
struct HandoffView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Rectangle()
                .fill(store.playingTeam.gradient)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text(store.currentGame.emoji)
                    .font(.system(size: 64))
                Text("\(store.currentGame.title)\(store.openBuzz ? " ⚡️" : "")")
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.9))

                Text(L("handoff.pass_to"))
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(store.playingTeam.emoji) \(store.playingTeam.name)")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 20)

                if store.playIndex == 1 {
                    Text(L("handoff.beat_them", store.roundSmall[1 - store.playingTeamIndex]))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.black.opacity(0.2)))
                } else {
                    Text(L("handoff.you_first"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                if store.openBuzz {
                    Text(L("handoff.openbuzz"))
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.yellow))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                if store.currentGame == .drawGuess {
                    Text(L("handoff.draw_flow"))
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else if store.settings.privacyGuardOn {
                    Text(L("handoff.posture"))
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)

                Spacer()

                Button {
                    FeedbackManager.shared.tap()
                    store.startPlaying()
                } label: {
                    Text(L("handoff.start"))
                }
                .buttonStyle(BigButtonStyle(colors: [.white, .white.opacity(0.92)],
                                            textColor: store.currentGame.colors[0]))
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
            }
        }
    }
}
