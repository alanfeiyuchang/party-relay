# Sign-off loop: iPhone Duo 适配（PartyRelay）

Round: 3（第二轮的修已做完并逐条验过，第三轮还没跑）        Panel: 3 (新手 / 中手 / 老手)
Last round: **0/3 signed**（第一轮也是 0/3）        Stopped because: 等用户决定要不要再跑一轮
Exercise: `scripts/fold-shots.sh`（四种姿态扫图）+ 读源码
Harness verified: **yes** — 同尺寸下和真机截图 SSIM≈0.996，残差是它隐掉的状态栏

## 被审的东西

Duo 折叠适配这一整套，外加「可以加新功能」的授权：

| 文件 | 管什么 |
| --- | --- |
| `PartyRelay/HingeMonitor.swift` | 铰链角度 → `isLaptopPosture`，滞回 + 0.3s 坐稳 |
| `PartyRelay/Views/CreaseSplit.swift` | 按**物理屏幕中线**劈两半，折痕两侧各留 30pt |
| `PartyRelay/OrientationLock.swift` | 折起来钉竖屏 |
| `PartyRelay/CoverScreen.swift` | 外屏内容 + 那个只为解锁外屏而跑的相机会话 |
| `PartyRelay/FoldTutorial.swift` | 轻提示 / 第一次折起来的说明 / 横拿兜底层 |
| `PartyRelay/Views/RootView.swift` | 侧边栏暂停键、安全区下发、各层挂载 |
| `PartyRelay/Views/PlayView.swift` `DrawView.swift` | 仅有的两个做了 90° 版面的玩法 |
| `PartyRelay/FoldPreview.swift` 🆕 | 这一轮新建的脚手架（见下） |
| `scripts/fold-shots.sh` 🆕 | 这一轮新建的扫图脚本 |

## 这一轮开工前就量到的硬事实

- **Duo 外屏实测**：整块 466×678pt，可用 **382×644**，安全区 `top0 / leading0 / bottom34 / trailing84`
  ——顶上没有横条，状态栏是右边那条 84pt 竖带。（`FOLD_PROBE=1` + `simctl launch --console`）
- **Duo 内屏**：`simctl io enumerate` 报 2007×2853 @3x = **669×951pt**。
  安全区**没量到**，脚手架里按外屏那组形状假设，真机到手必须重量。
- **模拟器折不了**：`simctl` 没有改姿态的命令（只能点 DeviceHub），两台 Duo 都停在闭合姿态，
  所以内屏是黑的，App 实际跑在外屏上。这是建脚手架的原因。
- `docs/iphone-duo.md` 里「外屏 1398×2034 / 内屏 1878×2670」——内屏那个数和 enumerate 对不上。

## 查过但**不是** bug 的

- 90° 版面右上角那颗黑圆点：是 Duo 外屏的**摄像头挖孔**，模拟器把它渲成黑的，
  就在状态栏 9:41 的正上方。四种配置下位置不变，去掉 FORCE_LAPTOP 也在。不是 App 画的。

## 第一轮：2/3 已回，两人都 **signed: false**

### 核实为真（已复现）

- [blocker] **相机权限文案只有中文**，英文用户看到纯中文系统弹窗。
  `project.pbxproj` 的 `INFOPLIST_KEY_NSCameraUsageDescription` 是中文硬编码，
  `InfoPlist.xcstrings` 里只有 `CFBundleDisplayName` 一条，没有这个 key。**新手**
- [blocker] **大部分页面没有折叠版面**。laptop 与 flat 两套截图逐张比对：
  `menu` / `home` / `wheel` / `scoreboard` md5 完全相同，`handoff` SSIM 0.996（等同相同）。
  只有 PlayView 和 DrawView 用了 CreaseSplit。**新手 + 中手（收敛）**
- [blocker] **表情管理 / 名人堂从不点亮外屏**，但折叠教学第三条明确承诺「外屏朝着其他人」。
  `CoverScreenModel.enabled` 只在 PlayView:47 和 DrawView:141 被设过。**新手 + 中手（收敛）**
- [blocker] **折叠教学不区分玩法**。`RootView.swift:17` 只判断 `phase == .playing`，
  不看 `currentGame`，所以表情管理也会弹，而且讲的是别的玩法的分工。**新手**
- [major] **拒绝相机权限后全程静默**。`CoverScreenCamera.denied` 在 CoverScreen.swift 之外零引用，
  没有任何视图消费它，设置里也没有任何折叠/外屏条目。**新手**
- [major] **合上手机时答案留在外屏上**。`outer/draw.png` 实拍：「Artist's eyes only! snowman」
  60pt 大字。`privacyGuardOn` 默认 **false**（Models.swift:270），没有任何兜底；
  铰链 `.closed` 状态除了 `deviceCanFold` 之外无人消费。**新手**
  ※ 新手的措辞「打在对面人脸上」不成立——合上时外屏朝向持机人。真正的问题是
  docs 把「合上」当作交接手势，那下一个人拿起来就直接看到答案。
- [blocker] **折叠教学盖在正在跑表的那一局上**。`RootView.swift:16-20` 置 `showFoldIntro`
  但不动 `store.turnPaused`，PlayView 的计时照常递减。**中手**
- [major] **你画我猜中途摊开会被踢回看词页**。`DrawView.swift:128-131` 只在进入 laptop 时
  置 `showCanvas = false`，退出时不恢复。**中手**

### 核实为假 —— 不修

- 中手报的 [blocker]「开放抢答在 90° 下整页空白」**不成立**。
  同一个 5s 取图点，openbuzz 和 act 各跑 3 次独立复现，6 次全部正常
  （1.2MB＝教学遮罩在场，2.0MB＝完整玩法页），倒计时页在 t=2.2s 也完整渲染
  （`Charades` + Open Buzz 胶囊 + 大字 3）。那张 333KB 的空白图是模拟器当时在
  并发构建下的一次取图抖动，不是确定性状态。扫图脚本固定 sleep 5 正好压在
  倒计时结束的切换点上——这是**脚本的毛病**，不是 App 的。

## 这一轮改掉的工具缺陷

- `fold-shots.sh` 取设备 UDID 时取到了 `(Booted)`，`simctl io Booted` 落到别的模拟器上，
  拍出一块 3840×2160 的外接屏。改成按 UUID 正则取，并在每张图后核验几何。
- `--cover` 那几张是躺着的：CoverPreview 为塞进竖屏窗口先转了 +90°，脚本没转回来。
  加了 `UNROTATE=-90`。
- 加了 `--no-build`，几个评审员并发拍图不再互相踩同一个 SYMROOT。
- 已知仍未修：固定 `sleep 5` 压在倒计时切换点上，会偶发拍到中间态（见上）。

## 第一轮之后改掉的（全部已编译通过）

1. **相机只在真有铰链的机器上开** —— 老手的头号 blocker，也是审核风险最高的一条。
   `CoverScreenCamera.start()` 改成只记下「想开」，真开与否由 `evaluate()` 判
   `HingeMonitor.status != .unavailable`。铰链状态要等 `UIHingeInteraction` 第一次回调才知道，
   而玩法页 onAppear 常跑在前面，所以 `HingeMonitor` 在状态变化时回调
   `hingeAvailabilityChanged()` 补一次。普通 iPhone 从此不弹权限、不亮绿点。
2. **相机权限文案补上英文**。加进 `InfoPlist.xcstrings`（en + zh-Hans），
   并把 pbxproj 里的基准串同步成新的中文（开发语言是 zh-Hans）。
   已验证：构建产物的 `en.lproj/InfoPlist.strings` 和 `zh-Hans.lproj/` 两边都有这条。
   文案也重写了——讲功能，不讲 API 绕法。
3. **折叠教学停表 + 只给做了版面的玩法弹**。`GameKind.hasFoldedLayout` 新增；
   `maybeShowFoldIntro` 记下原来的 `turnPaused` 再置 true，`dismissFoldIntro` 还原
   （不能无脑置 false，否则会把用户自己按的暂停一起解掉）。
4. **合上手机不再把答案留在屏上**。新增 `FoldedShutOverlay`：铰链报 `.closed` 且在玩法页时
   整页盖掉（不透明）并停表，摊开自动消失。已截图验证，词完全看不到。
   配 `FORCE_SHUT=1` 可在模拟器上调出来。
5. **画着画着摊开不再丢笔画**。`CanvasFit.box(aspect:in:)` 提到共用层，
   DrawView 在一个词之内把作画区长宽比**钉死**，笔画按这个方框归一化。
   量化验证（`swift` 跑的纯逻辑脚本，沿画板四边取 84 个点）：
   **修前 62/84 个点（74%）落到可见区外，x 从 −236 跑到 797（可见 0…561）；修后 0/84，x 正好 0…561。**
6. **其余页面整页收进立起来那半屏**（`FoldToTopHalf`，在 RootView 的 phase switch 上一处接线）。
   用垫安全区而不是 `CreaseSplit` 包一层：页面背景大多 `ignoresSafeArea`，垫安全区只顶内容，
   背景继续铺满；拿 CreaseSplit 裹的话下半屏是一整块白的，看着像渲染坏了。
7. **脚手架也补了**：`FORCE_LAPTOP` 现在同时把 `status` 摆成 `.partiallyOpen`，
   否则 `deviceCanFold` 为假，轻提示和外屏指示器这些新增的可发现性 UI 一张图都拍不到。

8. **横屏兜底不再是死胡同**（老手的第二条 blocker）。真机内屏到底是竖是横没法在没有
   真机的情况下定论，但原来的 `RotateToLaptopOverlay` **没有任何按钮**——假如内屏真的
   不认竖屏，`isSideways` 恒真，整个 App 被这一层盖死，一局都玩不了。现在多了一个
   「转不过来？就这样用整屏」：按下去 `HingeMonitor.foldLayoutSuppressed = true`，
   退回整屏版面（折叠那套不生效，但游戏能继续），姿态真的变化时自动作废。
   把一个可能的完全锁死降级成了可降级的体验。
9. **设置里常驻一个「折叠玩法」分区**（只在有铰链的机器上出现）：
   一行「再讲一遍折叠玩法」把教学重新武装（派对游戏每局换人，「只弹一次」对第二个人
   起就等于没说明）；脚注在相机权限被拒时换成一段解释，讲清「对面那块屏为什么不亮」
   以及去哪儿打开——这是此前 `CoverScreenCamera.denied` 全程无人消费的那条。
10. **折叠时正文可以滚**。`pageFrame()` 改成在 90° 姿态下套一层
   `ScrollView` + `.scrollBounceBehavior(.basedOnSize)`：放得下时完全不像滚动视图，
   放不下才真的能滚。关键是它在页面 ZStack **里面**，背景是兄弟节点且 ignoresSafeArea，
   所以背景照样铺满，只有正文被收进半屏。这解决的是下面原本列为「还没解决」的那条。

11. **名人堂折着时直接说清楚要摊平**（`OpenToPlayOverlay`）。这个玩法是两队左右对坐、
   同看一块屏的，横着劈开之后对面那队什么都看不到。硬塞进半屏只会更糟，
   所以不做折叠版面，而是明确告诉用户这一局要摊平。
12. **去掉 RootView 对外屏 model 的订阅**（中手报的 minor，其实是坑）。
   `CoverScreenModel` 上挂着 `remaining`（每秒一次）、`liveStroke`（画画时每个触摸点一次），
   RootView 一旦 `@ObservedObject` 它，整棵 phaseView 每次都重建；而 `PlayView`/`DrawView`
   的 `Timer.publish(...)` 是 view struct 的存储属性，重建等于**重新起表**，一局会被拖长。
   改成不订阅、直接读单例。`HingeMonitor` 文件里早就为同一件事留过警告，这是同一个坑的另一半。
13. **摊开不再被踢回看词页**（中手）。DrawView 记下折之前停在哪一页，摊开时还原。

### 自己改出来的回归（已修）

- 加了「合上手机」那一层之后，整轮扫图里**每一个玩法页**都被它盖住了。
  原因：两台 Duo 模拟器都停在闭合姿态，真实铰链回调报 `.closed`，而 `FORCE_LAPTOP`
  的早返回写在 `status` 赋值**之后**，顶不掉它。改成赋值前返回。
  已验证：FORCE_LAPTOP → 1.97MB 完整玩法页；FORCE_SHUT → 365KB 遮罩。

### 已知还没解决

- 内屏安全区仍是**假设值**。老手指出 `CoverScreen.swift:60` 注释里的「真机内屏实测画板 645×350」
  反推 trailing=0，和脚手架假设的 84 矛盾——两者不可能同时对，真机到手必须重量。
- 老手的 [blocker]「内屏可能是横的 951×669」没法在没有真机的情况下定论。
  `docs/iphone-duo.md` 说内屏不认 declared orientation、跑横屏；若成立则 `isSideways` 恒真，
  整个折叠模式被一层没有关闭按钮的提示盖死。**这条必须在真机上验，或者给横屏也排一版。**
- 名人堂（两队左右对坐）没动：它的左右分屏和横着的折痕天然打架，塞进半屏只会更糟。
- 老手说 `OrientationLock` 在发布包里是空操作——这条只对了一半：
  `supportedInterfaceOrientationsFor` 两个分支确实同值，但 `requestGeometryUpdate(.portrait)`
  是实打实的动作，不是查询。真机上它是否生效同样待验。

## 第二轮：0/3 signed

三个人都认下来的真修：相机门禁、CanvasFit（老手独立复跑了那 84 个点，数字和我的一致）、
合上遮词、名人堂提示、hasFoldedLayout、RootView 不再订阅外屏 model。

**但第二轮的头号 blocker 是我自己改出来的**：「正文收进立起来那半屏」没生效。
新手和中手各自独立量出同一条——中手还直接点出了机制错在哪，和我自己查到的一模一样：

> `safeAreaPadding` 垫在滚动视图上会被当成 **content inset**，正文一点都不会上移。
> `HomeView` / `ModeMenuView` 走 `FittingScroll`（内含 ScrollView），
> 而我给 `pageFrame` 折叠分支也套了一层 ScrollView——**两个修法互相抵消**。
> 算出来的 pad=471 是对的，可它什么也没做。

老手又在此之上发现第二层：`ScoreboardView` 是 `FittingScroll` 里面再套 `pageFrame`，
改成钉高度之后 `foldedTopHalf` 被**套了两层**，里面那层的 GeometryReader 活在 ScrollView 里
量不到高度，`max(140, …)` 这个兜底把它钉成一条 140pt 的缝——
兜底值把「量错了」变成了静悄悄的半成品，而不是当场露馅。

## 第二轮之后改的（逐条在像素上验过）

1. **改成钉高度**（`FoldedTopHalf`，`.frame(height: crease - gutter, alignment: .top)`）。
   只框页面自己的内容容器（`pageFrame` / `FittingScroll` / 遮罩层里的卡片），
   它们是背景的兄弟节点，所以背景照旧铺满。
   量化：折痕以下的灰度标准差 σ，menu 29.6→1.6、wheel 5.7→1.6、result 27.6→1.6、
   scoreboard 29.1→1.6、rotationresult 25.5→4.3、home 37.4→1.6。
2. **做成幂等**：环境里记一个 `isInsideFoldedTopHalf`，套两层时只认最外面那一层。
   并且**删掉 `max(140,…)` 兜底**——量到的高度不像半屏（<320pt）就原样放行，
   宁可不框也不要框出一条看不懂的缝。
3. **折叠时滚动区默认停在底部**（`FoldedBottomAnchor`）。这是老手第二轮 blocker 的正解：
   半屏确实放不下整页，所以要滚；但默认停在顶部＝主按钮滚到屏外，页面成死胡同。
   这些页的主按钮都在最后，停底部正好。
   已拍图确认「开始游戏 / 下一轮转盘 / 再来一局 / Start」四个主按钮**全部在折痕以上**。
4. **交接页的「刚才那些词」回顾卡折叠时整块藏掉**（`hiddenWhenFolded`）。
   它两百多点高，留着 Start 就被挤出可视区。摊开时照常显示。
5. **停表改成记原因**（`GameStore.PauseReason`）。中手报的真 bug：
   暂停弹窗每次开关都无条件回写 `turnPaused`，会盖掉折叠教学 / 合上遮罩存的状态，
   最后把牌局留在「表停了但屏上没有任何暂停提示」。现在谁加的谁撤。
6. **相机权限弹窗期间停表**（`PauseReason.cameraPrompt`）：第一队的时间不再烧在系统弹窗后面。
7. **三张说明卡（教学 / 请摊开 / 请转回来）收进立起来那半屏**——它们正是出事那一刻唯一要读的字。
8. **摊开还原画布**再放宽一档：`canvasBeforeFold || !strokes.isEmpty`。
   从看词页折起来、在折叠画板上画完再摊开，以前照样被踢回看词页。
9. **清空画布时解钉作画区**（注释一直这么写，代码漏了）。
10. **设置里「再讲一遍」的确认态从 UserDefaults 读初值**，不再只活在 @State 里骗人。
11. **扫图时不再弹折叠教学**，另加 `foldintro` / `foldintrodraw` 两个专门拍这张卡的模式。
    老手第二轮拿到的 act/draw 两张图全是「Folded mode」教学卡——这是工具的毛病。
12. **`--outer` 只许在 Duo 上跑**（老手第一轮的小问题）：那条路的前提是「主屏就是外屏」。

## 还没解决 / 有意分歧

- **暂停弹窗压在折痕上**。中手不同意「系统 alert 位置不可控所以不改」，主张自绘。
  说得有道理（这次已经自绘了四个遮罩层），但那是另一块工作量，没做。
- **内屏安全区仍是假设值**，真机到手必须 `FOLD_PROBE=1` 重量。
  `CoverScreen.swift` 注释里的 645×350 反推 trailing=0，和脚手架假设的 84 矛盾，两者不可能同时对。
- **内屏到底是竖是横**没法在没有真机的情况下定论。没有做横屏版面，
  只做了「转不过来？就这样用整屏」这个出口，把可能的完全锁死降级成可降级的体验。
- **名人堂**没有折叠版面，改成明确提示要摊平。
- 老手还提了两条小的没动：`OrientationLock.apply()` 只在姿态翻转时调（回前台不补调）、
  `FoldedTopHalf` 和 `CreaseSplit` 是同一条中线算两遍。

## Next action

要么跑第三轮复审，要么收尾提交。第一轮和第二轮都是 0/3，但第二轮的 blocker 已经
逐条在像素上验过修掉了——第三轮才能知道他们认不认。


## 第三轮之前，用户直接提的两件事（已做）

1. **「请转过来」那一层重做**（`RotateToLaptopOverlay` + `RotateDiagram`）。
   - **方向按当前界面方向算**，不写死：`.landscapeLeft` 是机身底边在左、顶边指向右，
     顶边要回到上就得**逆时针**转；`.landscapeRight` 反过来。写死必然有一半是反的。
     而且只有这一个方向落在竖屏上——另一边转过去是倒置竖屏，App 根本没声明那个方向。
   - **做成了动画**：一台折成 90° 的手机循环转到竖屏，配环形箭头（`arrow.clockwise` /
     `arrow.counterclockwise`），转完停一下再淡出重来。用 `TimelineView` 按时间算，
     不用 `repeatForever(autoreverses:)`——那个会演示「再转回去」，正好把人带反。
   - **绿色那条边＝外屏**，和 `FoldDiagram` 一个约定。顺时针转 90°，左边那条到上面，
     也就是转完之后外屏立起来朝着对面——这正是用户要的落点。
   - **变成两个，左右各一个**，不再放正中。横着拿的时候折痕是**竖**的，
     所以按 `geo.size.width/2 + (trailing-leading)/2` 劈开，两半各放一份完整提示
     （图 + 标题 + 说明 + 那个「就这样用整屏」的出口）。放正中只会骑在弯折带上。
   - 顺带去掉了这一层上的 `foldedTopHalf()`：那个按**横**折痕算，在这儿用是错的轴。

2. **那个相机会话真的用起来了**（`CoverCameraThumb` + `FoldedCameraThumb`）。
   折成 90° 时，**内屏**计时正下方挂一个小窗，显示**朝外那颗镜头**拍到的画面——
   也就是坐在对面的人，执机人由此看得到他们的反应。
   （一开始放到外屏上了，用户纠正：外屏朝着猜的人，在那儿放镜头等于让他们看自己，没用。
   已改到内屏，外屏那两面恢复原样。）
   只在折起来时显示：摊平时外屏不存在，镜头也没有「朝着对面」这回事。
   位置实拍确认：比划页在右（计时在右上），画板页在左（计时在左上）。
   - `DiscardingSink` → `PreviewSink`：**只在小窗真的显示时才解帧**（`wantsPreview`），
     12fps 封顶，转成 `CGImage` 直接画，不落盘、不进相册、不上传。
   - 占位图（没有相机 / 权限没给时）必须用深色：内屏是浅色的，
     一开始写的白底白框在真机上等于什么都没画。
   - ⚠️ `videoRotationAngle = 90` 是假设值，真机上对不上就改这一个数。

### 跟着改的文案（代码变了，话就不能照旧说）

`NSCameraUsageDescription`（中英）、设置里权限被拒那段脚注、`CoverScreen.swift` 文件头、
`docs/iphone-duo.md` 全部重写：以前写的是「不会把相机画面显示出来」，现在**会显示**，
只是不拍照、不录像、不保存、不离开设备。已验证构建产物里中英两版都更新了。

### ⚠️ 宣传片文案现在和代码对不上，没动

`trailer/文案.md` 整个第 4 段的立论就是「那个假相机」——
「不显示、不保存、连帧都不读」「假相机 → 外屏」「都得挂一个假的相机」，
封面大字和小红书标题也是这句。相机现在是真的在用，这些话都不再成立。
用户说过这份文案要自己大改，所以**没有替他改**，只在这里记一笔。

## 这一轮又修掉的工具缺陷

- `fold-shots.sh` 按 `--display 1` 取屏是错的：**两台 Duo 上 display 1 不是同一块屏**，
  一台是外屏（1398×2034），另一台是内屏（2034×1398）。闭合姿态下内屏是黑的，
  于是整轮 9 张全黑、字节数一模一样，而脚本一声不吭当成功了。
  改成**按几何挑屏**（两种朝向都认），挑不到就报错退出，不再出黑图。

## 又一个工具缺陷（这一轮第三次踩同一类）

`fold-shots.sh` 连着三次把黑图当成功：
1. 写死 `--display 1`——两台 Duo 上 1 号不是同一块屏；
2. 闲时挑屏——空闲亮着的那块不一定是 App 启动后去的那块，有一台正好相反；
3. 按**名字**找 Duo——有台模拟器被改名成 "Duo TEST"，于是既找不到它，
   `--outer` 的机型校验也误报「当前设备不是 Duo」。

现在：按 `deviceTypeIdentifier` 找机型（改名不影响），**App 跑起来之后**再挑屏，
几何对得上外屏（两种朝向都认）**且画面不是黑的**才用；每张图拍完再判一次亮度，
全黑直接报错退出。整个脚本重写过一遍（之前被我改残了，头部和参数解析都没了）。


## 🚨 真机到手，量到了：内屏是**横**的

装到用户那台真机 Duo 上（`devicectl`，Debug 自动签名）之后跑 `FOLD_PROBE=1`：

```
FOLDPROBE  size=867x635  insets=0,0,34,84      → 整块内屏 951 × 669
FOLDORIENT interface=4 (landscapeRight)  device=1 (portrait)
```

`device=1` 说明手机**竖着拿**，iOS 照样给了横屏布局。老手第一轮报的那条 blocker
（「内屏可能不认 declared orientation」）**成立**，`docs/iphone-duo.md` 原文是对的。

后果：
- `isSideways` 在真机上**恒为真**，一折到 90° 整页被「请转过来」盖住，
  折叠版面根本进不去——挡着的只有后加的那个「就这样用整屏」出口。
- `CreaseSplit` 按水平中线劈；横屏下物理折痕是**竖**的，整个轴错了。
- 这一轮所有 `laptop/` 截图都是按 669×951 竖版渲的，**几何不对**，
  包括「折痕以下 σ 降到 1.6」那组数——在真机上都要按 951×669 重做。

模拟器复现不了这件事（它的 Duo 把内屏报成竖的），只有真机说实话。

**用户决定先自己试机器，横屏折叠版面这件事没开工。**

## 真机上改掉的两条（用户现场反馈）

1. **镜头用错了**：`.back` → `.front`。真机枚举出四颗（前/后 × 广角/超广角），
   外屏那颗在 iOS 这边是 front——合上手机时它和外屏朝同一面，就是截图里那个挖孔。
2. **小窗不再镜像**：看的是对面的人，不是自己。镜像是照镜子的做法，
   这里要的是「透过手机看过去」，左右得和实际一致。
3. **旋转方向反了**：真机 `interface=4`(landscapeRight) 时要**逆时针**才回得到竖屏。
   第一版是推的，推反了；现在注释里写明这组对应以实测为准。


## 相机小窗：做了，又撤了

想法是「既然会话非开不可，就让它真的派上用场」——内屏计时旁边挂个小窗，
显示朝外那颗镜头拍到的画面（对面那几个人）。

撤掉的原因是**挑不中外屏那颗镜头**。真机枚举（`FOLD_PROBE=1`）在展开状态下一共五个：

```
:0 后置广角   :1 前置广角   :5 后置超广角   :8 前置超广角   :6 后置双广角
```

`position: .front` 只有 `:1` 和 `:8` 两颗，**实机确认两颗都是内屏那颗**；
外屏那颗（截图里一直看到的那个挖孔）在展开状态下根本枚举不到。
没有稳定的办法挑中它，功能就立不住，所以整块撤掉：

- `PreviewSink` 退回 `DiscardingSink`，一帧都不解；
- `CoverCameraThumb` / `FoldedCameraThumb` / `InlineCameraThumb` 全删；
- 相机权限文案、设置里那段脚注、`docs/iphone-duo.md` 一起退回
  「不拍照、不录像、不保存，也不会把相机画面显示出来」——这句现在又是真的了。

**没有验证过的路**：折起来之后再枚举，iOS 很可能把 `.front` 重新映射到外屏那颗，
或者多出一个设备。真要再做，从这儿查起。

## 教训：这一轮我两次用文本切片删代码，两次都删多了

一次把 `fold-shots.sh` 的头部和参数解析删没了（重写了整个脚本），
一次把 `CoverScreen.swift` 的「外屏上画什么」一整段删没了
（`CoverScreenContent`/`QuestionFace`/`DrawingFace` 等全丢，按对话里的版本补回并重拍图验过）。
两次都是「从 A 字符串切到 B 字符串」的写法，中间夹着的东西被一起带走。
以后改这种文件用带锚点的定点替换，别用区间切片。


## 外屏镜像「上面不全」——作画区钉早了

用户在真机上发现：折叠状态下在内屏画，外屏镜像的上边被切掉一块。

原因是 `pinBoard` 钉得太早。它挂在 `onAppear` 上，第一次量到的往往是版面的**中间态**尺寸；
等版面落定、白板变了形，`boardAspect` 还是旧比例，于是「作画区」成了白板里居中的一小块。
白板剩下那一圈 margin 照样画得上去、内屏也画得出来，
而外屏 `DrawingFace` 是 `context.clip(to: box)` 的——画在 margin 里的笔画全被裁掉。

两处一起修：

1. **落笔那一刻才钉**（`pinBoardIfNeeded`，从手势的第一个点调）。
   没动笔之前作画区**就是**整块白板，没有 margin，不可能画到框外；
   一旦开始画就锁死，之后折叠/摊开只让方框整体缩放（这条是原来就要保住的）。
2. **内屏也裁同一刀**。`drawingCanvas` 的 Canvas 加 `context.clip(to: board)`，
   和外屏完全一致——所见即对面所见。万一真出现 margin（画到一半折叠），
   用户也能直接看见边界，而不是画了却没传过去。


## 笔记本模式：所有要点的东西都归下半屏

规则（用户定的）：折成 90° 时，除了你画我猜，**上半屏只放词和计时这类不用操作的 UI，
猜对 / 换词 / 人名按钮一律在下半屏**。

漏的是**轮流模式**：那一支 `actionButtons` 里是 `EmptyView()`，计分其实靠点人名，
而人名是 `GuesserRing` 围着词排的——在 `wordArea` 里，也就是**上半屏**。
对战和开放抢答本来就是对的（猜对/被抢答/换词都在下半屏）。

改法：
- 新增 `GuesserPad`（RotationViews.swift，和私有的 `GuesserChip` 同文件）：
  平铺两到三列的人名按钮，没有弧度。摊平时名字围着词排是为了把两者绑成一个整体，
  折起来之后词在立起来那半、名字在平躺那半，弧就没有意义了，平铺更好按。
- `wordArea` 只在**摊平**时用 `GuesserRing`；折起来时上半屏只剩词卡。
- `actionButtons` 在折叠 + 轮流时放 `GuesserPad`。
- 词卡的 `maxHeight: .infinity` 从「非轮流」放宽到所有折叠情形，
  垂直留白也从 28 放回 42——上半屏不用再给名字让位了。

三页实拍确认（折痕画了红线）：轮流＝词在上 / 五个人名 + 换词在下；
比划＝词在上 / 猜对 + 换词在下；开放抢答＝词在上 / 猜对 + 被抢答 + 换词在下。
