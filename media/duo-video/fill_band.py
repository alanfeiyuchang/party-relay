"""把外屏素材顶上那条白带补掉。

按 678×466 横版排外屏时，内容被模拟器窗口的安全区整体往下推了 42pt（截图里 126px），
顶上就空出一条白带——画板那张看不出来（本来就是白的），但答对/换词那两张的渐变铺不到边，
一眼就是穿帮。几何不动，只把第一行有内容的像素往上复制满那条带。

用法：python3 fill_band.py tex/cover.png tex/cover-correct.png …
"""
import sys
import zlib
import struct


def read(path):
    data = open(path, "rb").read()
    pos, idat, ihdr = 8, [], None
    while pos < len(data):
        (ln,) = struct.unpack(">I", data[pos:pos + 4])
        typ = data[pos + 4:pos + 8]
        if typ == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", data[pos + 8:pos + 8 + ln])
        elif typ == b"IDAT":
            idat.append(data[pos + 8:pos + 8 + ln])
        pos += 12 + ln
    w, h, depth, color, _, _, interlace = ihdr
    assert depth == 8 and interlace == 0, ihdr
    nch = {0: 1, 2: 3, 4: 2, 6: 4}[color]
    raw = zlib.decompress(b"".join(idat))
    stride = w * nch
    rows, prev, p = [], bytearray(stride), 0
    for _ in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:
            for i in range(nch, stride):
                line[i] = (line[i] + line[i - nch]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                b = prev[i]
                c = prev[i - nch] if i >= nch else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        rows.append(line)
        prev = line
    return w, h, nch, rows


def write(path, w, h, nch, rows):
    color = {1: 0, 2: 4, 3: 2, 4: 6}[nch]
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, body):
        return (struct.pack(">I", len(body)) + tag + body
                + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF))

    open(path, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )


def main(paths):
    for path in paths:
        w, h, nch, rows = read(path)

        def is_white(y):
            return all(rows[y][x * nch] > 248 and rows[y][x * nch + 1] > 248
                       and rows[y][x * nch + 2] > 248 for x in range(0, w, 11))

        top = next((y for y in range(h) if not is_white(y)), 0)
        # 画板那张整张都是白的，top 会落在笔画上——只补明显是「带」的那种（小于四分之一屏）
        if 0 < top < h // 4:
            for y in range(top):
                rows[y] = bytearray(rows[top])
            write(path, w, h, nch, rows)
            print("  补白带 %-20s %dpx" % (path.split("/")[-1], top))


if __name__ == "__main__":
    main(sys.argv[1:])
