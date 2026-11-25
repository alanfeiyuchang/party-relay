"""PartyRelay × iPhone Duo 的 3D 演示场景。

跑法：
    /Applications/Blender.app/Contents/MacOS/Blender -b -P media/duo-video/scene.py -- --out /tmp/shot.png

场景（桌子、两个人、灯、机位）从零搭，不读任何 .blend——改参数重跑就行。
手机本身是现成的带骨骼模型，折叠角度由它自己的铰链动画给（见 duo_rig.py）。

外屏是**横**的：模型量出来那一面是 112.4×77.7mm，长宽比 1.446，几乎就是 678:466。
所以贴图不转方向，直接用 shoot.sh 拍的横版外屏（COVER_SIZE=678x466）铺满。
"""
import bpy, sys, os, math, importlib
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(flag, default):
    return ARGV[ARGV.index(flag) + 1] if flag in ARGV else default

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
# 贴图目录。中英两套界面各一份（tex / tex-en），商店截图要分别渲一次：
#   --tex tex-en
TEX = os.path.join(HERE, arg("--tex", "tex"))
OUT = arg("--out", os.path.join(HERE, "render", "hero.png"))
SAMPLES = int(arg("--samples", 96))

# 机位。
#
# ⚠️ 三块屏**不可能**在一个角度里同时看见：立起那半的两面朝向正好相反，
# 内屏朝画的人、外屏朝猜的人。所以分成两边拍，剪辑里靠一个环绕镜头连起来。
# 竖版 9:16，人一上一下排，近处那个只进半个身子当前景。
SHOTS = {
    # 全景（开场 + 封面）：猜的人这一侧，外屏朝着镜头
    "wide":  ((0.30, 0.86, 0.47), (0, 0.00, 0.105), 58),
    # 内屏这一侧：越过画的人的肩膀往下看，词卡和画板一起进画
    "inner": ((0.235, -0.50, 0.46), (0, -0.050, 0.030), 50),
    # 推近外屏：结尾那句呼吁压在这个画面上
    "cover": ((0.115, 0.275, 0.125), (0, 0.0, 0.058), 58),

    # —— 商店截图专用（1290×2796 比 9:16 更瘦更高，上方要留出放标题的地方）——
    # 机位比宣传片那两个更近：商店截图是缩略图里被扫一眼的，屏上的字必须认得出。
    # 视点抬高一点，手机因此落在画面偏下，上面那块空给文案。
    "store-fold":  ((0.205, -0.425, 0.405), (0, -0.045, 0.100), 74),
    "store-cover": ((0.135, 0.315, 0.135), (0, 0.000, 0.078), 54),
}
SHOT = arg("--shot", "wide")

def _res(text):
    w, h = (int(v) for v in text.lower().split("x"))
    return w, h
RES = _res(arg("--res", "1080x1920"))

# 调色：跟 App 自己的紫 / 青 / 橙一套
INK      = (0.07, 0.06, 0.12, 1)
TABLE    = (0.83, 0.74, 0.63, 1)
BACKDROP = (0.88, 0.86, 0.95, 1)
SKIN_A   = (0.98, 0.78, 0.62, 1)
SKIN_B   = (0.76, 0.56, 0.42, 1)
SHIRT_A  = (0.62, 0.25, 0.80, 1)   # 画的人：紫
SHIRT_B  = (0.10, 0.70, 0.68, 1)   # 猜的人：青


# ---------------------------------------------------------------- 基建

def wipe():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def flat(name, rgba, rough=0.65, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def limb(name, a, b, radius, mat):
    """两点之间架一根圆柱。

    比「摆一根再绕 X 转个角度」靠谱：手该落在哪就写哪，不用反推角度——
    之前用角度摆，符号搞反过一次，手直接甩到身后去了。
    """
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=d.length,
                                        location=(a + b) / 2)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(mat)
    for poly in o.data.polygons:
        poly.use_smooth = False
    return o


def plane(name, w, h, loc, rot, mat):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = (w, h, 1)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    return o


# ---------------------------------------------------------------- 手机

GLB = os.path.join(HERE, "model", "sketchfab-duo", "glb", "source",
                   "apple_iphone_duo_fold_star_white.glb")

# 屏幕贴图在模型 UV 上的朝向。模型是别人做的，UV 往哪边铺只能渲一张看出来，
# 所以留成两个旋钮，别去改 duo_rig 里的通用代码
INNER_UV = dict(flip_u=False, flip_v=False, spin=-90)  # 竖版实拍要转一下才对上模型 UV
COVER_UV = dict(flip_u=False, flip_v=False, spin=90)


def build_phone(inner_img, cover_img):
    """带骨骼的真机模型，折到 90°，内外屏换成模拟器实拍。

    几何和折叠全部交给模型自己的铰链骨骼（见 duo_rig.py）。内屏是整块跨过折痕的，
    所以一张完整的笔记本模式实拍直接铺上去，上半立起来是词卡、下半躺平是画板——
    不用再像以前那样把图切成两半、各浮一张平面去对边。
    """
    import duo_rig
    importlib.reload(duo_rig)
    arm, info = duo_rig.load(GLB, fold_deg=90)
    duo_rig.set_screen(duo_rig.MAT_INNER, inner_img, glow=0.85, **INNER_UV)
    duo_rig.set_screen(duo_rig.MAT_COVER, cover_img, glow=1.0, **COVER_UV)
    print("PHONE frame=%.2f angle=%.2f size=%s" % (
        info["frame"], info["angle"],
        tuple(round((info["hi"][i] - info["lo"][i]) * 1000, 1) for i in range(3))))
    return arm, info


# ---------------------------------------------------------------- 人

def build_person(name, y, shirt, skin, reach=False):
    """一个 low poly 的人：球脑袋 + 锥形身子 + 两条胳膊。不做脸。

    `y` 是坐的位置，正负决定朝向——人总是面朝原点（手机）。
    `reach` 的那条胳膊会伸到平躺那半屏上，表示正在画。
    尺寸按「桌上的小摆件」来定，不是真人比例：真人躯干 0.8m 对 0.17m 的手机，
    一进画框人就把手机压没了。
    """
    front = -1 if y > 0 else 1           # 从这个人指向手机的方向（沿 Y）
    body_mat = flat(f"{name}_shirt", shirt, rough=0.8)
    skin_mat = flat(f"{name}_skin", skin, rough=0.75)

    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.060, radius2=0.036,
                                    depth=0.125, location=(0, y, 0.0625))
    torso = bpy.context.object
    torso.name = f"{name}_torso"
    torso.data.materials.append(body_mat)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.034,
                                          location=(0, y, 0.158))
    head = bpy.context.object
    head.name = f"{name}_head"
    head.data.materials.append(skin_mat)

    for side in (-1, 1):
        shoulder = (side * 0.045, y, 0.098)
        if reach and side == -1:
            # 伸出去画的那条：手落在画板**靠边**的位置。
            # 以前让它伸到正中，结果整条胳膊横在雪人身上，画被挡掉一半
            hand = (-0.047, y + front * 0.175, 0.020)
        else:
            hand = (side * 0.052, y + front * 0.028, 0.030)
        limb(f"{name}_arm{side}", shoulder, hand, 0.012, skin_mat)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.016, location=hand)
        h = bpy.context.object
        h.name = f"{name}_hand{side}"
        h.data.materials.append(skin_mat)
        for poly in h.data.polygons:
            poly.use_smooth = False

    for o in (torso, head):
        for poly in o.data.polygons:
            poly.use_smooth = False


# ---------------------------------------------------------------- 场景

def build():
    wipe()
    scene = bpy.context.scene

    inner = bpy.data.images.load(os.path.join(TEX, "inner.png"))
    cover = bpy.data.images.load(os.path.join(TEX, "cover.png"))

    plane("table", 2.4, 2.4, (0, 0, 0), (0, 0, 0), flat("m_table", TABLE, rough=0.9))
    plane("backdrop", 3.0, 2.2, (0, 0.9, 1.0), (math.pi / 2, 0, 0),
          flat("m_backdrop", BACKDROP, rough=1.0))

    build_phone(inner, cover)
    build_person("artist",  -0.235, SHIRT_A, SKIN_A, reach=True)   # 画的人
    build_person("guesser",  0.235, SHIRT_B, SKIN_B)                # 猜的人

    # 灯：一盏主光从画的人那侧斜下来，一盏补光压住外屏那面的死黑
    bpy.ops.object.light_add(type="AREA", location=(-0.55, -0.6, 0.85))
    key = bpy.context.object
    key.data.energy, key.data.size = 42, 0.9
    key.rotation_euler = (math.radians(38), math.radians(-24), 0)

    bpy.ops.object.light_add(type="AREA", location=(0.7, 0.75, 0.6))
    fill = bpy.context.object
    fill.data.energy, fill.data.size = 16, 1.2
    fill.rotation_euler = (math.radians(62), math.radians(30), math.radians(160))

    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.84, 0.92, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.32
    scene.world = world

    loc, target, lens = SHOTS[SHOT]
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.object
    cam.data.lens = lens
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    if scene.render.engine == "CYCLES":
        scene.cycles.samples = SAMPLES
    else:
        scene.eevee.taa_render_samples = SAMPLES

    # 默认竖版 9:16（宣传片）。商店截图要 1290×2796（6.7 寸），比 9:16 更瘦更高，
    # 所以尺寸做成参数：--res 1290x2796
    scene.render.resolution_x, scene.render.resolution_y = RES
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.filepath = OUT
    scene.render.image_settings.file_format = "PNG"


build()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.render.render(write_still=True)
print("WROTE", OUT)
