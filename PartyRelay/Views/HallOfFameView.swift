import SwiftUI

/// 名人堂：两队各被秘密指定一个名人，全队一起轮流问是非题，猜出对方队伍的名人
/// 流程：红队私下看名字 → 蓝队私下看名字 → 左红右蓝分屏（再看一次名字 / 得分）
/// 没有计时、没有交接遮挡：两队同时进行，谁先猜中谁点自己那半边的得分按钮
struct HallOfFameView: View {
    @EnvironmentObject var store: GameStore

    /// 分屏前的私下看名字阶段
    private enum Stage: Equatable {
        case pass(Int)   // 把手机交给某队（还没揭晓）
        case peek(Int)   // 该队正在看自己的名人
        case split       // 两队都看完了，进入问答分屏
    }

    /// 遮罩页用途：再看一次名字 / 确认得分
    private enum CoverMode { case name, score }

    @State private var stage: Stage = .pass(0)
    @State private var coverTeam: Int?
    @State private var coverMode: CoverMode = .name
    @State private var coverExpanded = false
    @State private var coverNameShown = false

    var body: some View {
        ZStack {
            switch stage {
            case .pass(let t):  privateScreen(team: t, revealed: false)
            case .peek(let t):  privateScreen(team: t, revealed: true)
            case .split:        splitScreen
            }

            if let t = coverTeam {
                coverPage(team: t)
            }
        }
        .onAppear { applyScreenshotMode() }
    }

    // MARK: - 私下看名字（红队先，再蓝队）

    private func privateScreen(team index: Int, revealed: Bool) -> some View {
        let team = store.teams[index]
        return ZStack {
            Rectangle().fill(team.gradient).ignoresSafeArea()

            VStack(spacing: 18) {
                HomeExitBar(light: true)
                Spacer()

                Text(GameKind.hallOfFame.emoji).font(.system(size: 54))
                Text(GameKind.hallOfFame.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.9))

                if revealed {
                    Text(L("hof.your_name_is", team.name))
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    NameCard(name: store.hofNames[index])

                    Text(L("hof.remember_it"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                } else {
                    Text(L("hof.pass_to"))
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.9))
                    Text("\(team.emoji) \(team.name)")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 20)
                    Text(L("hof.pass_body"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                Button {
                    FeedbackManager.shared.tap()
                    withAnimation(.easeInOut(duration: 0.25)) { advance(from: index, revealed: revealed) }
                } label: {
                    Text(buttonTitle(team: index, revealed: revealed))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .buttonStyle(BigButtonStyle(colors: [.white, .white.opacity(0.92)],
                                            textColor: team.colors[0]))
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
            }
        }
    }

    private func buttonTitle(team index: Int, revealed: Bool) -> String {
        guard revealed else { return L("hof.reveal_btn") }
        return index == 0
            ? L("hof.next_team", "\(store.teams[1].emoji) \(store.teams[1].name)")
            : L("hof.to_questions")
    }

    private func advance(from index: Int, revealed: Bool) {
        if !revealed {
            stage = .peek(index)
        } else if index == 0 {
            stage = .pass(1)
        } else {
            stage = .split
        }
    }

    // MARK: - 分屏：红队在左，蓝队在右

    private var splitScreen: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                teamHalf(index: 0)
                teamHalf(index: 1)
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                HomeExitBar(light: true)
                Text(L("hof.split_hint"))
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.9)))
                    .padding(.horizontal, 20)
            }
        }
    }

    private func teamHalf(index: Int) -> some View {
        let team = store.teams[index]
        return VStack(spacing: 12) {
            Spacer()

            Text(team.emoji).font(.system(size: 40))
            Text(team.name)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(L("hof.ask_prompt"))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()

            VStack(spacing: 10) {
                HalfButton(title: L("hof.see_again"),
                           systemImage: "eye.fill",
                           filled: false,
                           tint: team.colors[0]) {
                    openCover(team: index, mode: .name)
                }
                HalfButton(title: L(store.smallScoreWin ? "hof.score_btn_small" : "hof.score_btn_big"),
                           systemImage: "star.fill",
                           filled: true,
                           tint: team.colors[0]) {
                    openCover(team: index, mode: .score)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Rectangle().fill(team.gradient))
    }

    // MARK: - 遮罩页：从该队那一侧展开铺满整页

    private func coverPage(team index: Int) -> some View {
        let team = store.teams[index]
        return GeometryReader { geo in
            ZStack(alignment: index == 0 ? .leading : .trailing) {
                Color.black.opacity(coverExpanded ? 0.3 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(team.gradient)
                    .frame(width: coverExpanded ? geo.size.width : geo.size.width / 2)
                    .ignoresSafeArea()

                coverContent(team: index)
                    .frame(width: geo.size.width)
                    .opacity(coverExpanded ? 1 : 0)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func coverContent(team index: Int) -> some View {
        let team = store.teams[index]
        VStack(spacing: 18) {
            Spacer()

            if coverMode == .name {
                if coverNameShown {
                    Text("🌟").font(.system(size: 44))
                    Text(L("hof.your_name_is", team.name))
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    NameCard(name: store.hofNames[index])
                } else {
                    Text("🤫").font(.system(size: 60))
                    Text(L("hof.confirm_title", team.name))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 24)
                    Text(L("hof.confirm_body"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            } else {
                Text("🏆").font(.system(size: 60))
                Text(L("hof.score_title", team.name))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 24)
                Text(L(store.smallScoreWin ? "hof.score_body_small" : "hof.score_body_big"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    primaryCoverAction(team: index)
                } label: {
                    Text(primaryCoverTitle(team: index))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .buttonStyle(BigButtonStyle(colors: [.white, .white.opacity(0.92)],
                                            textColor: team.colors[0]))

                // 名字揭晓后主按钮本身就是「收起」，不再重复一个取消
                if !(coverMode == .name && coverNameShown) {
                    Button {
                        FeedbackManager.shared.tap()
                        closeCover()
                    } label: {
                        Text(L("common.cancel"))
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(.white.opacity(0.18)))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func primaryCoverTitle(team index: Int) -> String {
        if coverMode == .score { return L("hof.score_confirm") }
        return coverNameShown ? L("hof.close_cover") : L("hof.confirm_btn", store.teams[index].name)
    }

    private func primaryCoverAction(team index: Int) {
        if coverMode == .score {
            FeedbackManager.shared.correct()
            store.finishHallOfFame(winner: index)
            return
        }
        if coverNameShown {
            FeedbackManager.shared.tap()
            closeCover()
        } else {
            FeedbackManager.shared.tap()
            withAnimation(.easeInOut(duration: 0.25)) { coverNameShown = true }
        }
    }

    private func openCover(team index: Int, mode: CoverMode) {
        FeedbackManager.shared.tap()
        coverMode = mode
        coverNameShown = false
        coverExpanded = false
        coverTeam = index
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { coverExpanded = true }
        }
    }

    private func closeCover() {
        withAnimation(.easeInOut(duration: 0.28)) { coverExpanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            coverTeam = nil
            coverNameShown = false
        }
    }

    // MARK: - 截图模式

    private func applyScreenshotMode() {
        switch ScreenshotMode.mode {
        case "hof":       stage = .pass(0)
        case "hofpeek":   stage = .peek(0)
        case "hofsplit", "hofsmall": stage = .split
        case "hofname":   stage = .split; openCover(team: 0, mode: .name)
        case "hofreveal": stage = .split; openCover(team: 0, mode: .name); coverNameShown = true
        case "hofscore", "hofsmallscore": stage = .split; openCover(team: 0, mode: .score)
        default: break
        }
    }
}

// MARK: - 名人姓名卡

private struct NameCard: View {
    var name: String

    var body: some View {
        Text(name)
            .font(.system(size: 42, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.black.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.6), lineWidth: 2))
            )
            .padding(.horizontal, 26)
    }
}

// MARK: - 分屏半边用的紧凑按钮

private struct HalfButton: View {
    var title: String
    var systemImage: String
    var filled: Bool
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline.bold())
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(filled ? tint : .white)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(filled ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.2)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(filled ? 0 : 0.6), lineWidth: 1.5))
                    .shadow(color: .black.opacity(filled ? 0.18 : 0), radius: 6, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}
