import SwiftUI
import UniformTypeIdentifiers

// MARK: - 准备页：人数 + 每个人

/// 轮流模式准备页上的玩家面板：− / + 定人数；点某个人展开成编辑卡片（改名、换头像、删除）；
/// 名字旁边的 ✕ 直接删；长按拖动调整顺序（开局随机抽一个人先来，之后按这个顺序轮）
struct PlayerSetupPanel: View {
    @EnvironmentObject var store: GameStore
    /// 正在编辑的那个人：卡片画在 HomeView 最上层（要盖住整页），所以状态放在外面
    @Binding var editing: UUID?
    var namespace: Namespace.ID

    /// 正在拖的人。只用来判断「经过谁就挪到谁的位置」，每次开始拖都会重设
    @State private var dragging: UUID?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Label(L("rotation.player_count"), systemImage: "person.3.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                countButton("minus", delta: -1,
                            disabled: store.players.count <= Player.countRange.lowerBound)
                Text("\(store.players.count)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(PlayMode.rotation.gradient)
                    .contentTransition(.numericText())
                    .frame(minWidth: 40)
                countButton("plus", delta: 1,
                            disabled: store.players.count >= Player.countRange.upperBound)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                      spacing: 10) {
                ForEach(store.players) { player in
                    PlayerPill(player: player,
                               namespace: namespace,
                               hidden: editing == player.id,
                               removable: store.players.count > Player.countRange.lowerBound,
                               onEdit: {
                                   FeedbackManager.shared.tap()
                                   withAnimation(PlayerEditCard.spring) { editing = player.id }
                               },
                               onRemove: {
                                   FeedbackManager.shared.tap()
                                   withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                       store.removePlayer(id: player.id)
                                   }
                               })
                    .onDrag {
                        dragging = player.id
                        FeedbackManager.shared.tap()
                        return NSItemProvider(object: player.id.uuidString as NSString)
                    } preview: {
                        PlayerPillLabel(player: player)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(width: 160)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(player.gradient))
                    }
                    .onDrop(of: [.text], delegate: PlayerDropDelegate(target: player.id,
                                                                     dragging: $dragging,
                                                                     store: store))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            // 拖到格子外面松手也要把「拿起」的状态清掉
            .onDrop(of: [.text], isTargeted: nil) { _ in
                dragging = nil
                return false
            }

            Text(L("rotation.rename_hint"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func countButton(_ symbol: String, delta: Int, disabled: Bool) -> some View {
        Button {
            FeedbackManager.shared.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                store.setPlayerCount(store.players.count + delta)
            }
        } label: {
            Image(systemName: "\(symbol).circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(disabled ? AnyShapeStyle(Color(.systemGray4))
                                          : AnyShapeStyle(PlayMode.rotation.gradient))
        }
        .disabled(disabled)
        .accessibilityIdentifier("players.\(symbol)")
    }
}

/// 拖动排序：拖着的人经过谁，就挪到谁的位置上（边拖边让位，松手即定）
private struct PlayerDropDelegate: DropDelegate {
    let target: UUID
    @Binding var dragging: UUID?
    let store: GameStore

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.movePlayer(dragging, to: target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

/// 一个玩家的胶囊：点它展开编辑卡片，✕ 直接删掉
private struct PlayerPill: View {
    var player: Player
    var namespace: Namespace.ID
    /// 编辑卡片开着时，这颗胶囊让位给卡片（卡片从它的位置长出来、再缩回来）。
    /// 拖动时不另做淡化：系统已经画了拿起来的预览，而且松手落回自己原位时
    /// 系统不会回调 performDrop，自己记的「拿起」状态会卡住
    var hidden: Bool
    /// 只剩 2 个人时不显示 ✕
    var removable: Bool
    var onEdit: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onEdit) {
                PlayerPillLabel(player: player, avatarID: "avatar-\(player.id)", namespace: namespace,
                                isSource: !hidden)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editPlayer.\(player.avatar)")

            if removable {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)   // 图标小，点击区域放大一点
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("rotation.remove_player"))
                .accessibilityIdentifier("removePlayer.\(player.avatar)")
            }
        }
        // ✕ 自带 28pt 的点击区域，有它的时候上下和右边的留白相应收一点，胶囊高度不变
        .padding(.leading, 12)
        .padding(.trailing, removable ? 6 : 12)
        .padding(.vertical, removable ? 6 : 9)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(player.gradient)
                .matchedGeometryEffect(id: "card-\(player.id)", in: namespace, isSource: !hidden)
                .shadow(color: player.colors[0].opacity(0.35), radius: 5, y: 2)
        )
        .opacity(hidden ? 0 : 1)
    }
}

/// 胶囊里的头像 + 名字（拖动预览也用它）
private struct PlayerPillLabel: View {
    var player: Player
    var avatarID: String? = nil
    var namespace: Namespace.ID? = nil
    var isSource = true

    var body: some View {
        HStack(spacing: 6) {
            avatar
            Text(player.name)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var avatar: some View {
        let emoji = Text(player.emoji).font(.system(size: 22))
        if let avatarID, let namespace {
            emoji.matchedGeometryEffect(id: avatarID, in: namespace, isSource: isSource)
        } else {
            emoji
        }
    }
}

// MARK: - 编辑卡片：改名、换头像、删除

/// 点玩家胶囊后，胶囊原地展开成的卡片（画在 HomeView 最上层）
struct PlayerEditCard: View {
    @EnvironmentObject var store: GameStore
    var playerID: UUID
    var namespace: Namespace.ID
    var onClose: () -> Void

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    /// 卡片展开 / 收起用同一条弹簧，两个方向手感对称
    static let spring: Animation = .spring(response: 0.42, dampingFraction: 0.84)

    private var player: Player? { store.players.first { $0.id == playerID } }

    var body: some View {
        if let player {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)

                VStack(spacing: 16) {
                    Text(player.emoji)
                        .font(.system(size: 64))
                        .matchedGeometryEffect(id: "avatar-\(player.id)", in: namespace)

                    nameField(player)
                    avatarGrid(player)
                    buttons(player)
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(player.gradient)
                        .matchedGeometryEffect(id: "card-\(player.id)", in: namespace)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
                )
                .padding(.horizontal, 28)
                .frame(maxWidth: 480)
            }
            .onAppear { name = player.hasDefaultName ? "" : player.name }
        }
    }

    private func nameField(_ player: Player) -> some View {
        TextField("", text: $name,
                  prompt: Text(Player.defaultName(player.avatar)).foregroundStyle(.white.opacity(0.6)))
            .font(.title2.bold())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit { close() }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.18)))
            .transition(.opacity)
    }

    /// 12 个头像：别人用着的置灰点不了（头像同时决定颜色，两个人撞色在圈里就分不清了）
    private func avatarGrid(_ player: Player) -> some View {
        VStack(spacing: 6) {
            Text(L("rotation.pick_avatar"))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(0..<Player.emojis.count, id: \.self) { avatar in
                    let mine = avatar == player.avatar
                    let taken = !mine && store.players.contains { $0.avatar == avatar }
                    Button {
                        FeedbackManager.shared.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            store.setAvatar(avatar, for: player.id)
                        }
                    } label: {
                        Text(Player.emoji(avatar))
                            .font(.system(size: 24))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Circle().fill(Player.gradient(avatar)))
                            .overlay(Circle().stroke(.white, lineWidth: mine ? 3 : 0))
                            .opacity(taken ? 0.3 : 1)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(taken)
                }
            }
        }
        .transition(.opacity)
    }

    private func buttons(_ player: Player) -> some View {
        HStack(spacing: 10) {
            if store.players.count > Player.countRange.lowerBound {
                Button {
                    FeedbackManager.shared.tap()
                    let id = player.id
                    nameFocused = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        onClose()
                        store.removePlayer(id: id)
                    }
                } label: {
                    Label(L("rotation.delete_player"), systemImage: "trash.fill")
                }
                .buttonStyle(BigButtonStyle(colors: [.white.opacity(0.22), .white.opacity(0.18)],
                                            font: .headline))
            }

            Button {
                FeedbackManager.shared.tap()
                close()
            } label: {
                Text(L("settings.done"))
            }
            .buttonStyle(BigButtonStyle(colors: [.white.opacity(0.95), .white],
                                        textColor: player.colors[0], font: .headline))
        }
        .transition(.opacity)
    }

    /// 存名字（空着就退回默认名）再收起卡片
    private func close() {
        if let i = store.players.firstIndex(where: { $0.id == playerID }) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            store.players[i].name = trimmed.isEmpty ? Player.defaultName(store.players[i].avatar) : trimmed
        }
        nameFocused = false
        withAnimation(Self.spring) { onClose() }
    }
}

// MARK: - 游戏中：所有猜的人围着这个词

/// 表演者看到的画面：词在中间，其他人的名字分成上下两排弧线围着它，
/// 像大家围坐在一个房间里。谁猜对了就点谁——没有单独的「猜对」按钮
struct GuesserRing<Center: View>: View {
    @EnvironmentObject var store: GameStore
    var onGuess: (UUID) -> Void
    @ViewBuilder var center: Center

    private var guessers: [Player] {
        store.players.filter { $0.id != store.performer.id }
    }

    var body: some View {
        let top = Array(guessers.prefix((guessers.count + 1) / 2))
        let bottom = Array(guessers.dropFirst(top.count))
        // 两端的名字往词那边弯、还带一点转角，间距留宽一些，免得角压到词卡上
        VStack(spacing: 26) {
            GuesserArc(players: top, towardCenter: .down, onGuess: onGuess)
            center
            GuesserArc(players: bottom, towardCenter: .up, onGuess: onGuess)
        }
    }
}

/// 一组名字排成弧：两端往词那边弯、并且微微转向中间。
/// 每排最多 3 个（4 个时一排排下），一组最多 6 个（12 人局去掉表演者剩 11 个）
private struct GuesserArc: View {
    enum Direction { case up, down }

    var players: [Player]
    /// 词在这一组的哪一边：上面那组的两端往下弯，下面那组往上弯
    var towardCenter: Direction
    var onGuess: (UUID) -> Void

    /// 弧的弯曲程度：最两端的名字比中间的偏移多少、转多少度
    private static let depth: CGFloat = 14
    private static let tilt: Double = 9

    private var rows: [[Player]] {
        let perRow = players.count == 4 ? 4 : 3
        return stride(from: 0, to: players.count, by: perRow).map {
            Array(players[$0..<min($0 + perRow, players.count)])
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows.indices, id: \.self) { r in
                let row = rows[r]
                HStack(spacing: 8) {
                    ForEach(row.indices, id: \.self) { j in
                        let nx = Self.position(j, of: row.count)
                        let sign: CGFloat = towardCenter == .down ? 1 : -1
                        GuesserChip(player: row[j]) { onGuess(row[j].id) }
                            .frame(maxWidth: 132)
                            .rotationEffect(.degrees(Double(nx * sign) * Self.tilt))
                            .offset(y: sign * Self.depth * nx * nx)
                    }
                }
                .padding(.vertical, Self.depth / 2)
            }
        }
        .padding(.horizontal, 16)
    }

    /// 第 j 个在这一排里的横向位置，-1（最左）… 1（最右）。
    /// 一排只有两个时弯一半，不然两个名字会像被掰开一样
    private static func position(_ j: Int, of count: Int) -> CGFloat {
        guard count > 1 else { return 0 }
        let raw = CGFloat(2 * j) / CGFloat(count - 1) - 1
        return raw * min(1, CGFloat(count - 1) / 2)
    }
}

/// 一个猜的人：头像 + 名字 + 当前总分。点一下冒出 +1
private struct GuesserChip: View {
    var player: Player
    var action: () -> Void

    @State private var pop = false
    @State private var plusRise = false
    @State private var plusVisible = false

    var body: some View {
        Button {
            action()
            celebrate()
        } label: {
            VStack(spacing: 1) {
                Text("\(player.emoji) \(player.name)")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(L("rotation.points", player.score))
                    .font(.caption.bold())
                    .opacity(0.9)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(player.gradient)
                    .shadow(color: player.colors[0].opacity(0.4), radius: 6, y: 3)
            )
            .scaleEffect(pop ? 1.15 : 1)
        }
        .buttonStyle(PressableStyle())
        .overlay(alignment: .top) {
            Text("+1")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(player.colors[0])
                .shadow(color: .white, radius: 2)
                .offset(y: plusRise ? -34 : -4)
                .opacity(plusVisible ? 1 : 0)
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("guesser.\(player.avatar)")
    }

    private func celebrate() {
        plusRise = false
        plusVisible = true
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pop = true }
        withAnimation(.easeOut(duration: 0.6)) { plusRise = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pop = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.2)) { plusVisible = false }
        }
    }
}

/// 名字的紧凑版（表情管理那种屏幕本来就挤的玩法用）：一行一行排开，点谁谁 +1
struct GuesserStrip: View {
    @EnvironmentObject var store: GameStore
    var onGuess: (UUID) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(store.players.filter { $0.id != store.performer.id }) { p in
                Button {
                    onGuess(p.id)
                } label: {
                    Text("\(p.emoji) \(p.name) · \(p.score)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(p.gradient))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 交接：把手机递给下一个人

struct RotationHandoffView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Rectangle()
                .fill(store.performer.gradient)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HomeExitBar(light: true)

                Spacer()

                Text(L("rotation.progress", store.rotationCycle,
                       store.rotationTurn + 1, store.players.count))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.85))

                // 开局第一位是随机抽的，说一声，免得大家以为是按名单从头开始
                if store.rotationTurn == 0 && store.rotationCycle == 1 {
                    Text(L("rotation.random_first"))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.18)))
                }

                Text(L("handoff.pass_to"))
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(store.performer.emoji) \(store.performer.name)")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 20)

                Text(L("rotation.handoff_body"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                if store.turnGameReady {
                    Text("\(store.currentGame.emoji) \(store.currentGame.title)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.18)))
                }

                if let turn = store.previousTurn {
                    PreviousTurnRecap(turn: turn)
                }

                Spacer()

                Button {
                    FeedbackManager.shared.tap()
                    store.leaveRotationHandoff()
                } label: {
                    Label(L(store.turnGameReady ? "handoff.start" : "rotation.to_wheel"),
                          systemImage: store.turnGameReady ? "play.fill" : "arrow.clockwise.circle.fill")
                }
                .buttonStyle(BigButtonStyle(colors: [.white, .white.opacity(0.92)],
                                            textColor: store.performer.colors[0]))
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
            }
            .pageFrame()
        }
    }
}

/// 上一位刚表演完的那一轮：得了几分、出过哪些词、各是谁猜出来的
private struct PreviousTurnRecap: View {
    @EnvironmentObject var store: GameStore
    var turn: RotationTurn

    var body: some View {
        let who = store.players.indices.contains(turn.performer) ? store.players[turn.performer] : nil
        VStack(spacing: 8) {
            Text(L("rotation.recap_title", "\(who?.emoji ?? "") \(who?.name ?? "")", turn.points))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if !turn.words.isEmpty {
                let chips = FlowLayout(spacing: 6) {
                    ForEach(turn.words) { w in
                        PlayedWordChip(word: labelled(w),
                                       tint: AnyShapeStyle(Color.white),
                                       textColor: .black.opacity(0.8),
                                       font: .footnote.bold())
                    }
                }
                if turn.words.count > 8 {
                    ScrollView { chips }.frame(maxHeight: 130)
                } else {
                    chips
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.black.opacity(0.18)))
        .padding(.horizontal, 22)
    }

    /// 猜对的词后面跟上是谁猜的
    private func labelled(_ w: PlayedWord) -> PlayedWord {
        guard let by = w.guessedBy else { return w }
        var copy = w
        copy.text = "\(w.text) · \(by)"
        return copy
    }
}

// MARK: - 一整轮结束：所有人的总分

struct RotationResultView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var appeared = false

    /// 宽屏（iPhone Duo 内屏横放、iPad）排两列：单列的话内屏只看得到四个人，右边三分之二是空的
    private var wide: Bool { hSize == .regular }

    /// 按总分从高到低；同分同名次
    private var ranked: [(rank: Int, player: Player)] {
        // 同分按座位顺序排（谁先表演谁在前）
        let sorted = store.players.enumerated()
            .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
            .map(\.element)
        var result: [(Int, Player)] = []
        for (i, p) in sorted.enumerated() {
            let rank = (i > 0 && sorted[i - 1].score == p.score) ? result[i - 1].0 : i + 1
            result.append((rank, p))
        }
        return result
    }

    var body: some View {
        ZStack {
            PartyBackground()

            VStack(spacing: 14) {
                HomeExitBar()

                VStack(spacing: 6) {
                    Text("🏆")
                        .font(.system(size: 52))
                        .scaleEffect(appeared ? 1 : 0.3)
                    Text(L("rotation.result_title", store.rotationCycle))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(PlayMode.rotation.gradient)
                    Text(L("rotation.result_subtitle"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: wide ? 2 : 1),
                              spacing: 10) {
                        ForEach(Array(ranked.enumerated()), id: \.element.player.id) { i, entry in
                            RankRow(rank: entry.rank, player: entry.player)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.spring(response: 0.45, dampingFraction: 0.8)
                                    .delay(0.08 * Double(i)), value: appeared)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 4)
                }
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: 10) {
                    Button {
                        FeedbackManager.shared.tap()
                        store.nextRotationCycle()
                    } label: {
                        Label(L("rotation.again"), systemImage: "arrow.counterclockwise.circle.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: PlayMode.rotation.colors, shadowedText: true))

                    Text(L("rotation.again_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button(L("victory.home")) { store.resetToHome() }
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 32)
                .padding(.bottom, wide ? 12 : 24)
            }
            .pageFrame(maxWidth: wide ? 860 : 560)

            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            FeedbackManager.shared.roundSettle()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.1)) { appeared = true }
        }
    }
}

private struct RankRow: View {
    var rank: Int
    var player: Player

    private var medal: String? {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let medal {
                    Text(medal).font(.system(size: 28))
                } else {
                    Text("\(rank)")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36)

            Text(player.emoji)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(Circle().fill(player.gradient))

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(L("rotation.breakdown", player.performPoints, player.guessPoints))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("\(player.score)")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(player.gradient)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(rank == 1 ? AnyShapeStyle(player.gradient) : AnyShapeStyle(Color.clear),
                                lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        )
    }
}
