// 宣传片只在带 TRAILER 标志的构建里编译：日常 Debug 一直有，
// 录制脚本给 Release 加上这个标志（画面要跑满 60fps），而上架的归档不带它，
// 所以这几千行动画和素材不会进商店包。
#if DEBUG || TRAILER
import SwiftUI
import UIKit

/// 宣传片里用到的所有图片：模拟器实拍的 App 画面，和 Blender 渲出来的三张 3D。
///
/// 图片不打进 App 包（上架的包里不该带几十兆宣传素材），录制脚本在装好之后
/// 把 `media/duo-video/` 下的图拷进 `Documents/trailer/`，这里按名字读。
/// 读不到就画一个占位框，预览时一眼看得出少了哪张。
enum TrailerAssets {
    enum Name: String, CaseIterable {
        /// Blender：斜侧全景，两个人加中间折成 90° 的手机
        case wide3D = "3d-wide"
        /// Blender：内屏那一侧，词卡 + 画板
        case inner3D = "3d-inner"
        /// Blender：推近外屏
        case cover3D = "3d-cover"
        /// 外屏横版（678×466）：画板镜像 / 答对报分 / 换词
        case cover
        case coverCorrect = "cover-correct"
        case coverSkip = "cover-skip"
        /// 笔记本模式下的内屏（上半词卡、下半画板）
        case laptop = "inner"
        /// 普通竖屏的 App 页面
        case menu = "app-menu"
        case draw = "app-draw"
        case word = "app-word"
        case home = "app-home"
        /// App 图标（片尾）
        case icon
    }

    private static var cache: [String: UIImage] = [:]

    static func image(_ name: Name) -> UIImage? {
        if let hit = cache[name.rawValue] { return hit }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("trailer", isDirectory: true)
        guard let loaded = UIImage(contentsOfFile: dir.appendingPathComponent("\(name.rawValue).png").path)
        else { return nil }
        // UIImage(contentsOfFile:) 是**懒**的：真正解码发生在第一次画的时候。
        // 不先解好的话，开场那几张一上画面就是一两秒的卡顿，而片子的时钟走的是墙上时间，
        // 卡完之后画面会直接跳过去——录出来就是画面比旁白早两秒。
        let ready = loaded.preparingForDisplay() ?? loaded
        cache[name.rawValue] = ready
        return ready
    }

    /// 趁开场黑板那几秒把所有图解码好（见上面 image(_:) 里的说明）
    static func warmUp() {
        for name in Name.allCases { _ = image(name) }
    }
}

/// 一张素材图，带缓慢推近。读不到图时画一个标着名字的占位框。
@available(iOS 18.0, *)
struct TrailerShot: View {
    let name: TrailerAssets.Name
    /// 画多大
    var size: CGSize
    var corner: CGFloat = 26
    /// 0 → 1 的推近进度（配合 `zoomFrom` / `zoomTo`）
    var zoom: Double = 0
    var zoomFrom: CGFloat = 1.0
    var zoomTo: CGFloat = 1.0
    /// `.fill` 裁满框，`.fit` 完整放进框
    var mode: ContentMode = .fill
    var shadow = true

    var body: some View {
        let scale = TrailerMath.mix(zoomFrom, zoomTo, TrailerMath.easeInOut(zoom))
        Group {
            if let ui = TrailerAssets.image(name) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: mode)
                    .scaleEffect(scale)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(TrailerStyle.purple.opacity(0.12))
                    .overlay {
                        Text(verbatim: name.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(TrailerStyle.purple)
                    }
                    .frame(width: size.width, height: size.height)
            }
        }
        .shadow(color: TrailerStyle.purple.opacity(shadow ? 0.2 : 0), radius: 24, x: 0, y: 14)
    }
}

/// 取素材图上下方向的一段来画（比如笔记本模式那张的上半屏 / 下半屏）。
///
/// `band` 是归一化的纵向区间，0 是图顶、1 是图底。宽度铺满给定的 `width`，
/// 高度按这一段在原图里的实际比例算，所以画出来不变形。
@available(iOS 18.0, *)
struct TrailerSlice: View {
    let name: TrailerAssets.Name
    let band: ClosedRange<CGFloat>
    var width: CGFloat
    var corner: CGFloat = 14

    private var ratio: CGFloat {
        guard let ui = TrailerAssets.image(name), ui.size.width > 0 else { return 1 }
        return ui.size.height / ui.size.width
    }

    var body: some View {
        let span = max(band.upperBound - band.lowerBound, 0.01)
        let height = width * ratio * span
        Group {
            if let ui = TrailerAssets.image(name) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: width * ratio)
                    // 把要的那一段挪到窗口正中：区间中点相对图中点的偏移
                    .offset(y: -(band.lowerBound + span / 2 - 0.5) * width * ratio)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    // 画板那一半几乎全白，压在奶油色的底上会整个消失，描一圈才看得出是块屏
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(TrailerStyle.purple.opacity(0.22), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(TrailerStyle.purple.opacity(0.12))
                    .frame(width: width, height: height)
            }
        }
        .shadow(color: TrailerStyle.purple.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

/// 画出来的 iPhone（17 Pro 比例），里面放一张 App 截图。
///
/// 真机 402 × 874pt，长宽比 0.46；屏幕圆角约为宽的 13%。
@available(iOS 18.0, *)
struct TrailerPhoneFrame: View {
    /// 屏幕宽度（pt，画布坐标）
    var screenWidth: CGFloat = 176
    var name: TrailerAssets.Name?
    /// 屏幕上盖一层自定义内容（比如手指、遮挡提示）
    var overlay: AnyView? = nil

    var screenSize: CGSize { CGSize(width: screenWidth, height: screenWidth * 874 / 402) }
    private var bezel: CGFloat { max(screenWidth * 0.033, 4) }
    private var screenCorner: CGFloat { screenWidth * 0.13 }

    var body: some View {
        let s = screenSize
        ZStack {
            // 钛金边
            RoundedRectangle(cornerRadius: screenCorner + bezel, style: .continuous)
                .fill(LinearGradient(colors: [Color(trailerHex: 0xD8D3DE), Color(trailerHex: 0x9A94A6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: s.width + bezel * 2, height: s.height + bezel * 2)
                .shadow(color: TrailerStyle.purple.opacity(0.26), radius: 26, x: 0, y: 16)
            Group {
                if let name, let ui = TrailerAssets.image(name) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
                } else {
                    TrailerStyle.paper
                }
            }
            .frame(width: s.width, height: s.height)
            .clipShape(RoundedRectangle(cornerRadius: screenCorner, style: .continuous))
            if let overlay {
                overlay.frame(width: s.width, height: s.height)
            }
            // 灵动岛
            Capsule(style: .continuous)
                .fill(Color.black)
                .frame(width: screenWidth * 0.31, height: screenWidth * 0.092)
                .offset(y: -s.height / 2 + screenWidth * 0.09)
            // 玻璃高光
            RoundedRectangle(cornerRadius: screenCorner, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                                     startPoint: .topLeading, endPoint: .center))
                .frame(width: s.width, height: s.height)
                .allowsHitTesting(false)
        }
    }
}

/// 深色代码卡：等宽字，一行一行地落进来。
@available(iOS 18.0, *)
struct TrailerCodeCard: View {
    struct Line: Identifiable {
        let id = UUID()
        let text: String
        /// 高亮这一行（重点那句）
        var hot = false
        /// 这一行是注释 / 被划掉的那条路
        var dim = false
    }

    let lines: [Line]
    var width: CGFloat = 340
    var size: CGFloat = 14
    /// 0 → 1：按行依次出现
    var reveal: Double
    var title: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title {
                Text(verbatim: title)
                    .font(.system(size: size - 1, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.bottom, 2)
            }
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                let start = Double(index) / Double(max(lines.count, 1)) * 0.75
                let local = TrailerMath.easeOut(TrailerMath.clamp((reveal - start) / 0.25))
                Text(verbatim: line.text)
                    .font(.system(size: size, weight: line.hot ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(line.hot ? AnyShapeStyle(TrailerStyle.accent)
                                     : AnyShapeStyle(Color.white.opacity(line.dim ? 0.38 : 0.82)))
                    .strikethrough(line.dim, color: Color.white.opacity(0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(local)
                    .offset(x: CGFloat(1 - local) * -10)
            }
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(TrailerStyle.codeBack)
                .shadow(color: TrailerStyle.ink.opacity(0.35), radius: 24, x: 0, y: 14)
        }
    }
}

/// 「系统给 / 不给」那张表的一行
@available(iOS 18.0, *)
struct TrailerRow: View {
    let want: String
    let answer: String
    /// true 给了，false 没给
    let granted: Bool
    var width: CGFloat = 340
    /// 0 → 1 的出场
    var appear: Double

    var body: some View {
        let a = TrailerMath.spring(appear * 0.55, response: 0.5, damping: 0.8)
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(granted ? TrailerStyle.green : TrailerStyle.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: want)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(TrailerStyle.ink)
                Text(verbatim: answer)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TrailerStyle.inkSoft)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: TrailerStyle.purple.opacity(0.14), radius: 12, x: 0, y: 6)
        }
        .opacity(TrailerMath.clamp(appear * 3))
        .scaleEffect(0.92 + 0.08 * a)
        .offset(y: CGFloat(1 - a) * 16)
    }
}
#endif
