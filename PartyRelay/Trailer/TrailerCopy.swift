// 宣传片只在带 TRAILER 标志的构建里编译：日常 Debug 一直有，
// 录制脚本给 Release 加上这个标志（画面要跑满 60fps），而上架的归档不带它，
// 所以这几千行动画和素材不会进商店包。
#if DEBUG || TRAILER
import Foundation

/// 片子里出现的**所有**文字都在这儿，一处改完全片生效。
///
/// 旁白不画在画面上，只用来对时间：`trailer/voiceover.srt` 是这支片子的规格书，
/// 每一条字幕对应下面一段画面，最后一条的结束时间就是成片长度（见 `TrailerCanvas.duration`）。
enum TrailerCopy {

    // 0–11.5s 开场：一台手机三个人 → 这是什么游戏 → 以前怎么玩
    enum Hook {
        static let title = "一台手机，三个人"
        static let subtitle = "各看一块屏"
        static let gameTitle = "一台手机就能玩的派对游戏"
        static let gameSubtitle = "猜词派对"
        static let modes = ["你画我猜", "猜词", "比划"]
        static let oldTitle = "以前只有一块屏"
        static let oldSubtitle = "传来传去，轮流捂着"
        static let oldPills = ["手机传一圈", "出题的得捂屏", "围着一块屏挤"]
    }

    // 11.5–31s 折起来之后三块屏各干什么
    enum Fold {
        static let title = "折叠 iPhone 来了"
        static let subtitle = "外屏能不能也上场？"
        static let foldLabel = "折到 90°"
        static let lidTitle = "上半屏 · 立着"
        static let lidBody = "朝出题的人，只有他看得到词"
        static let deckTitle = "下半屏 · 平躺"
        static let deckBody = "正好当画板"
        static let coverTitle = "外屏 · 朝对面"
        static let coverBody = "实时同步这幅画，答对报谁加分"
    }

    // 31–58.5s 外屏唯一的那条路
    enum Door {
        static let title = "听起来很顺"
        static let subtitle = "系统只留了一扇窄门"
        static let apiTitle = "想往外屏放自己的内容"
        static let apiSubtitle = "公开 API 只有这一个"
        static let api = "UISceneAccessory"
        static let factoryTitle = "它只有两个工厂方法"
        static let factorySubtitle = "一个根本不是给你的"
        static let quoteTitle = "门槛写死在头文件里"
        static let quote = "while the app is in the foreground\nand has an active camera capture session"
        static let quoteNote = "前台 · 而且有一个活跃的相机会话"
        static let denyTitle = "不开相机会话"
        static let denySubtitle = "系统直接不给你外屏"
        static let deny = "isAvailable = false"
        static let denyPill = "折到 90° 也一样"
    }

    // 58.5–75s 那个假相机
    enum Camera {
        static let title = "所以这里跑着一个相机会话"
        static let subtitle = "不显示 · 不保存 · 不读帧"
        static let traits = ["不显示预览", "不保存文件", "收到帧直接扔"]
        static let purposeTitle = "它唯一的用处"
        static let purposeSubtitle = "让系统放行外屏"
        static let from = "假相机"
        static let to = "外屏"
        static let costTitle = "代价也是真的"
        static let costSubtitle = "一个画画游戏要申请相机"
        static let costs = ["相机权限", "状态栏绿点", "一点耗电", "审核要解释"]
    }

    // 75–91s 剩下的坑
    enum Pitfall {
        static let title = "剩下的坑"
        static let subtitle = "也都得自己填"
        static let rows: [(want: String, answer: String, granted: Bool)] = [
            ("折痕在屏幕哪个位置", "没有任何 API，只能假设在正中自己劈", false),
            ("「笔记本模式」这个状态", "自己从铰链角度推：60–135° 进，50–145° 退", false),
            ("外屏能用多大", "466×678pt，右边 84pt 还是系统的", false),
        ]
        static let fitTitle = "画搬到外屏"
        static let fitSubtitle = "不按比例 fit，左右各切掉四成"
        static let fitBad = "直接搬过去"
        static let fitGood = "按画板长宽比 fit"
    }

    // 91–101.5s 呼吁 + 片尾
    enum End {
        static let title = "希望苹果把外屏"
        static let subtitle = "开放给非相机类的 App"
        static let closing = "不然每个想用外屏的人"
        static let closingAccent = "都得挂一个假的相机"
        static let appName = "猜词派对"
        static let appLine = "PartyRelay · 一台手机的派对游戏"
    }
}
#endif
