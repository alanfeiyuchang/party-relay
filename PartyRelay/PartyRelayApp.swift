import SwiftUI

@main
struct PartyRelayApp: App {
    /// 折起来的时候要把方向钉在竖屏，这件事只能从 UIKit 那一侧做（见 OrientationLock）
    @UIApplicationDelegateAdaptor(OrientationLock.self) private var orientation
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
#if DEBUG || TRAILER
            // 宣传片顶掉整个界面：-ML_trailer YES（见 Trailer/TrailerView.swift）。
            // 片子用了 MeshGradient 和 TextRenderer，都是 iOS 18 才有的，而 App 本身还支持 17
            if #available(iOS 18.0, *), UserDefaults.standard.bool(forKey: "ML_trailerCover") {
                TrailerCoverView()
            } else if #available(iOS 18.0, *), UserDefaults.standard.bool(forKey: "ML_trailer") {
                TrailerView()
            } else {
                root
            }
#else
            root
#endif
        }
    }

    private var root: some View {
        RootView()
            .environmentObject(store)
            .preferredColorScheme(.light)
#if DEBUG
            // 模拟器折不了，90° 那套布局只能钉着内屏的点数排一遍来看（见 FoldPreview）
            .foldPreview()
#endif
    }
}
