// 宣传片只在带 TRAILER 标志的构建里编译：日常 Debug 一直有，
// 录制脚本给 Release 加上这个标志（画面要跑满 60fps），而上架的归档不带它，
// 所以这几千行动画和素材不会进商店包。
#if DEBUG || TRAILER
import SwiftUI

/// 小红书封面：`-ML_trailerCover YES` 启动时画这一张，录制脚本截图后裁成 1080×1440。
///
/// 和片子共用一套配色和素材，封面和视频才像一套东西。
/// 文案走反差句（「想用外屏？得先挂一个假相机」），标题那条留给笔记本身。
@available(iOS 18.0, *)
struct TrailerCoverView: View {
    /// 3:4，和画布一样 390pt 宽
    private static let size = CGSize(width: 390, height: 520)

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / Self.size.width
            ZStack {
                TrailerStyle.paper
                card
                    .frame(width: Self.size.width, height: Self.size.height)
                    .clipped()
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: Self.size.height * scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { TrailerAssets.warmUp() }
    }

    private var card: some View {
        ZStack {
            TrailerStyle.paper
            if let ui = TrailerAssets.image(.wide3D) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.12)
                    .frame(width: Self.size.width, height: Self.size.height)
                    .clipped()
            }
            // 上下各压一层，标题和角标才读得出来
            LinearGradient(colors: [.white.opacity(0.97), .white.opacity(0.72), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: Self.size.height * 0.56)
                .frame(maxHeight: .infinity, alignment: .top)
            LinearGradient(colors: [.clear, TrailerStyle.paper.opacity(0.95)],
                           startPoint: .center, endPoint: .bottom)
                .frame(height: Self.size.height * 0.34)
                .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(spacing: 10) {
                Text(verbatim: "想用折叠屏的外屏？")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(TrailerStyle.ink)
                Text(verbatim: "得先挂一个假相机")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(TrailerStyle.accent)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: 350)
            .shadow(color: .white.opacity(0.9), radius: 10)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 44)

            HStack(spacing: 8) {
                TrailerPill(text: "iOS 27 · UISceneAccessory", tint: TrailerStyle.purple,
                            size: 14, filled: true)
                TrailerPill(text: "一台手机 · 三块屏", tint: TrailerStyle.teal, size: 14, filled: true)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 30)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }
}
#endif
