"""把 Sketchfab 那台带骨骼的 iPhone Duo 摆成 90° 笔记本姿势，并把屏幕换成实拍。

模型：Apple iPhone Duo Fold Star White 2026 (Animated)，作者 UnknownOrigin，
Free Standard 授权（可商用、可改），102k 三角面。
https://sketchfab.com/3d-models/apple-iphone-duo-fold-star-white-2026-animated-240492141edd4594ae13082a7fcbbb29

比苹果官网那个 AR 用的 USDZ 好接三件事：
  1. 带铰链骨骼和 `open-close` 动画（0 帧摊平 ↔ 48 帧合上），折到任意角度只要选一帧，
     不用自己沿 Y=0 把网格劈成两半再绕轴转；
  2. 内外屏是两块单独命名的网格（`Front_Screen` / `Back_Screen`），UV 都是规规矩矩的 0–1，
     换张图就换完了，不用在屏幕前面浮一张贴图去对边；
  3. 内屏是**整块**跨过折痕的（158.6 × 110.9mm），所以摆成笔记本之后，
     一张完整的内屏实拍直接铺上去，上半自动立起来当词卡、下半自动躺平当画板。

⚠️ 外屏仍然是**横**的：这个模型量出来 77.7 宽 × 112.4 高（贴在合起来的正面那一侧），
   摆成笔记本之后沿折痕那条边（112.4）变成水平 —— 112.4 宽 × 77.7 高，长宽比 1.446。
   苹果官网 AR 那个 USDZ（apple.com/iphone-duo/ 的 iPhone_Duo_e-sim_Star-White_Variant.usdz）
   量出来是 77.4 × 112.5（1.4535）。两个独立的模型对上了，
   所以真机在笔记本姿势下给 App 的外屏场景应该是横的 678×466，不是模拟器那个竖的 466×678。
   （还是没在真机上看过，见 发布.md）
"""
import bpy, math
from mathutils import Vector, Matrix

#: 背景球，Sketchfab 预览用的，不是机器
JUNK = {"Icosphere"}
#: 内屏 / 外屏的材质名（换贴图就改这两个材质里的图）
MAT_INNER = "C_StarWhite_Screen_Inner"
MAT_COVER = "C_SW_Screen_Outer"
#: 外屏那块网格，用来判断立起来的是哪一半
COVER_MESH = "Back_Screen"


def _phone_meshes(fresh):
    """只认这次导入进来的网格。

    场景里桌子和背景板是先建好的，拿 `bpy.data.objects` 全量算包围盒的话，
    落桌面那一步会按桌子的尺寸去推，手机直接飞出画面。
    """
    return [o for o in fresh if o.type == "MESH" and o.name not in JUNK]


def _evaluated_bounds(objs):
    """世界包围盒。必须走 depsgraph：骨骼是用 modifier 变形的，

    直接读 `o.bound_box` 拿到的是没掰开之前的静止网格，摆到桌面上会差一大截。
    """
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        ev = o.evaluated_get(dg)
        for corner in ev.bound_box:
            w = ev.matrix_world @ Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return lo, hi


def _outward(arm):
    """两半各自「从铰链指向外缘」的方向，以及铰链的位置（世界坐标）。

    骨头在 Blender 里是沿自己的 +Y 长的。静止姿势下 Bone_02 从 +X 那半的外缘长向铰链，
    Bone_01 从铰链长向 -X 那半的外缘 —— 方向正好一个朝里一个朝外，所以 Bone_02 要取反。
    两个外缘方向之间的夹角就是张开角：180° 摊平，90° 笔记本，0° 合上。
    """
    def axis(name):
        return (arm.matrix_world @ arm.pose.bones[name].matrix).col[1].xyz.normalized()
    hinge = (arm.matrix_world @ arm.pose.bones["Bone_Hinge"].matrix).translation.copy()
    return axis("Bone_01"), -axis("Bone_02"), hinge


def _open_angle(arm):
    a, b, _ = _outward(arm)
    return math.degrees(a.angle(b))


def _seek_angle(arm, want_deg):
    """在 open-close 这段动画里找张开角最接近 want_deg 的那一帧（含小数帧）。

    90° 正好落在第 24 帧上，但别写死——换个角度（比如拍 120° 半开）也能用。
    """
    scene = bpy.context.scene
    action = bpy.data.actions.get("open-close") or next(iter(bpy.data.actions))
    lo, hi = (int(action.frame_range[0]), int(action.frame_range[1]))

    def err(frame):
        scene.frame_set(int(frame), subframe=frame - int(frame))
        bpy.context.view_layer.update()
        return abs(_open_angle(arm) - want_deg)

    best = min(range(lo, hi + 1), key=err)
    # 再在相邻两帧之间二分几次，取小数帧
    a, b = max(lo, best - 1.0), min(hi, best + 1.0)
    for _ in range(12):
        m1, m2 = a + (b - a) / 3, b - (b - a) / 3
        if err(m1) <= err(m2):
            b = m2
        else:
            a = m1
    frame = (a + b) / 2
    err(frame)
    return frame


def load(glb_path, fold_deg=90.0):
    """导入、折到 fold_deg、摆到桌面上。返回 (armature, info)。

    摆好之后：折痕沿 X 横在 y=0，平躺那半朝 -Y（画的人那侧），
    立起那半在上，外屏朝 +Y（猜的人那侧），整机坐在 z=0 的桌面上。
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    fresh = [o for o in bpy.data.objects if o not in before]
    for o in list(fresh):
        if o.name.split(".")[0] in JUNK:
            fresh.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)

    arm = next(o for o in fresh if o.type == "ARMATURE")
    frame = _seek_angle(arm, fold_deg)

    out_a, out_b, hinge = _outward(arm)
    cover = bpy.data.objects[COVER_MESH]
    dg = bpy.context.evaluated_depsgraph_get()
    ev = cover.evaluated_get(dg)
    cover_mid = sum((ev.matrix_world @ Vector(c) for c in ev.bound_box), Vector()) / 8
    # 外屏贴在哪一半，哪一半就是要立起来的「盖」
    lid_out, deck_out = ((out_a, out_b) if (cover_mid - hinge).dot(out_a) >
                         (cover_mid - hinge).dot(out_b) else (out_b, out_a))

    # 两个外缘方向张成一个正交基，直接映射到想要的姿势上，
    # 比「先转 90 再转 180」那种凑出来的欧拉角稳：换折叠角度也不用重新试符号
    e1 = deck_out.normalized()
    e2 = (lid_out - e1 * lid_out.dot(e1)).normalized()
    e3 = e1.cross(e2)
    src = Matrix((e1, e2, e3)).transposed()
    dst = Matrix(((0, -1, 0), (0, 0, 1), (-1, 0, 0))).transposed()
    arm.matrix_world = (dst @ src.inverted()).to_4x4() @ arm.matrix_world
    bpy.context.view_layer.update()

    # 落到桌面、折痕放到 y=0、左右居中。平移量从实际包围盒算，不靠手推
    lo, hi = _evaluated_bounds(_phone_meshes(fresh))
    arm.matrix_world = Matrix.Translation(
        Vector((-(lo.x + hi.x) / 2, -hi.y, -lo.z))) @ arm.matrix_world
    bpy.context.view_layer.update()

    lo, hi = _evaluated_bounds(_phone_meshes(fresh))
    return arm, dict(frame=frame, angle=_open_angle(arm), lo=lo, hi=hi)


def set_screen(mat_name, image, glow=0.9, flip_u=False, flip_v=False, spin=0.0):
    """把某块屏的贴图换成自己的图。

    模型自带的材质已经把贴图接到了自发光上（屏幕本来就该是亮的），
    所以这里只换图、顺带把底色也接过去 —— 原本底色走的是一层顶点色，
    不接的话屏幕在反光里会是一片灰。
    """
    mat = bpy.data.materials[mat_name]
    nt = mat.node_tree
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex.image = image
    tex.extension = "CLIP"

    if flip_u or flip_v or spin:
        coord = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping")
        # Mapping 算的是 Location + Rotation * (Scale * uv)，三个变换都绕 UV 原点 (0,0)，
        # 所以翻转和旋转都会把图甩出 [0,1]²，得自己平移回来
        sx, sy = (-1 if flip_u else 1), (-1 if flip_v else 1)
        mapping.inputs["Scale"].default_value = (sx, sy, 1)
        loc = [1.0 if flip_u else 0.0, 1.0 if flip_v else 0.0, 0.0]
        if spin:
            mapping.inputs["Rotation"].default_value = (0, 0, math.radians(spin))
            loc[0] += 1.0 if spin > 0 else 0.0
            loc[1] += 0.0 if spin > 0 else 1.0
        mapping.inputs["Location"].default_value = loc
        nt.links.new(coord.outputs["UV"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])

    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = glow
    bsdf.inputs["Roughness"].default_value = 0.18
    return mat
