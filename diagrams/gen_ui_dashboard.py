"""
Thiet ke giao dien: man hinh Bang dieu khien (Dashboard)
Ve lai theo dung mau sac / theme thuc te cua ung dung Flutter da build
(navy #0F172A, cyan #22D3EE, orange #F97316) thay vi mau xanh la / xanh
duong chung chung truoc day khong khop voi san pham that.
Output: ../Final/SOICT_DATN_Duong/Hinhve/tk_giaodien.png
"""

import math
from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------- CANVAS ----
SCALE = 2                      # ve o do phan giai gap doi roi thu nho -> net hon
W, H = 1800 * SCALE, 1050 * SCALE
OUT_PATH = "../Final/SOICT_DATN_Duong/Hinhve/tk_giaodien.png"

# ----------------------------------------------------------------- MAU -----
NAVY        = (15, 23, 42)        # #0F172A - nen chinh / topbar / bottombar
PANEL       = (19, 31, 54)        # panel noi
PANEL_2     = (24, 38, 63)        # panel item nen
BORDER      = (51, 65, 90)        # vien mo tren nen toi
CYAN        = (34, 211, 238)      # #22D3EE - accent chinh
ORANGE      = (249, 115, 22)      # #F97316 - accent canh bao / con
PURPLE      = (167, 139, 250)
WHITE       = (255, 255, 255)
MUTED       = (148, 163, 184)     # slate-400
MUTED_DIM   = (100, 116, 139)
GREEN       = (74, 222, 128)
GRAY_OFF    = (100, 116, 139)

MAP_BG      = (223, 231, 236)
WATER       = (169, 209, 227)
BUILDING    = (206, 214, 199)
BUILDING_2  = (216, 223, 210)

FONT_DIR = "C:/Windows/Fonts/"


def font(size, bold=False):
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    return ImageFont.truetype(FONT_DIR + name, int(size * SCALE))


img = Image.new("RGB", (W, H), NAVY)
draw = ImageDraw.Draw(img, "RGBA")


def s(v):
    return int(v * SCALE)


def rrect(xy, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(
        [s(xy[0]), s(xy[1]), s(xy[2]), s(xy[3])],
        radius=s(radius), fill=fill, outline=outline, width=s(width) if outline else 0,
    )


def text(pos, txt, size, color=WHITE, bold=False, anchor="la"):
    draw.text((s(pos[0]), s(pos[1])), txt, font=font(size, bold), fill=color, anchor=anchor)


def text_center(box_xy, txt, size, color=WHITE, bold=False):
    x0, y0, x1, y1 = box_xy
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    text((cx, cy), txt, size, color, bold, anchor="mm")


def pill(xy, fill, radius=None):
    x0, y0, x1, y1 = xy
    if radius is None:
        radius = (y1 - y0) / 2
    rrect((x0, y0, x1, y1), radius, fill=fill)


def circle(cx, cy, r, fill=None, outline=None, width=2):
    draw.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)],
                 fill=fill, outline=outline, width=s(width) if outline else 0)


def icon_target(cx, cy, r, color):
    circle(cx, cy, r, outline=color, width=2.6)
    circle(cx, cy, r * 0.45, fill=color)


def icon_home(cx, cy, r, color):
    # than nha (hinh chu nhat rong, thap) + mai nha (tam giac thoai, cung do rong)
    body_w, body_h = r * 1.5, r * 0.85
    body_top = cy - body_h * 0.15
    draw.rectangle([s(cx - body_w / 2), s(body_top),
                     s(cx + body_w / 2), s(body_top + body_h)], fill=color)
    roof = [(cx - body_w / 2 - r * 0.12, body_top),
            (cx, body_top - r * 0.62),
            (cx + body_w / 2 + r * 0.12, body_top)]
    draw.polygon([(s(x), s(y)) for x, y in roof], fill=color)


def icon_person(cx, cy, r, color):
    circle(cx, cy - r * 0.35, r * 0.42, fill=color)
    draw.pieslice([s(cx - r * 0.62), s(cy + r * 0.05), s(cx + r * 0.62), s(cy + r * 1.35)],
                   180, 360, fill=color)


def icon_pin(cx, cy, r, color, bg=None):
    if bg is not None:
        circle(cx, cy, r, fill=bg)
    circle(cx, cy - r * 0.15, r * 0.55, fill=color)
    tri = [(cx - r * 0.32, cy + r * 0.15), (cx + r * 0.32, cy + r * 0.15), (cx, cy + r * 0.8)]
    draw.polygon([(s(x), s(y)) for x, y in tri], fill=color)
    circle(cx, cy - r * 0.15, r * 0.22, fill=NAVY)


# =====================================================================
# 1) TOP BAR
# =====================================================================
TOPBAR_H = 108
rrect((0, 0, 1800, TOPBAR_H), 0, fill=NAVY)

icon_target(46, TOPBAR_H / 2, 20, CYAN)
text((84, TOPBAR_H / 2 - 15), "GPS Tracker", 24, WHITE, bold=True, anchor="lm")
text((84, TOPBAR_H / 2 + 15), "Theo dõi vị trí con", 12.5, MUTED, anchor="lm")

tabs = [("Bản đồ", True), ("Thống kê", False), ("Hồ sơ", False)]
tx = 430
for label, active in tabs:
    tw = 150
    if active:
        pill((tx, 30, tx + tw, TOPBAR_H - 30), fill=(*CYAN, 22))
        text_center((tx, 30, tx + tw, TOPBAR_H - 30), label, 15.5, CYAN, bold=True)
    else:
        text_center((tx, 30, tx + tw, TOPBAR_H - 30), label, 15.5, MUTED)
    tx += tw + 14

circle(1754, TOPBAR_H / 2, 24, fill=PANEL_2, outline=BORDER, width=2)
icon_person(1754, TOPBAR_H / 2 + 3, 11, MUTED)

rrect((0, TOPBAR_H, 1800, TOPBAR_H + 3), 0, fill=CYAN)

# =====================================================================
# 2) KHUNG NOI DUNG
# =====================================================================
BODY_TOP = TOPBAR_H + 3
BOTTOMBAR_H = 92
BODY_BOTTOM = 1050 - BOTTOMBAR_H

rrect((0, BODY_TOP, 1800, BODY_BOTTOM), 0, fill=(30, 41, 59))

# ---------------------------------------------------------------- MAP ------
MAP_L, MAP_R = 400, 1400
rrect((MAP_L, BODY_TOP, MAP_R, BODY_BOTTOM), 0, fill=MAP_BG)

blocks = [
    (430, 190, 560, 300), (610, 190, 760, 300), (830, 190, 990, 280),
    (430, 620, 560, 760), (610, 640, 760, 780),
    (1030, 200, 1180, 320), (1220, 220, 1360, 340),
    (1030, 620, 1180, 740), (1220, 640, 1360, 780),
]
for i, (x0, y0, x1, y1) in enumerate(blocks):
    c = BUILDING if i % 2 == 0 else BUILDING_2
    rrect((x0, y0 + TOPBAR_H, x1, y1 + TOPBAR_H), 10, fill=c)

draw.ellipse([s(1080), s(TOPBAR_H + 470), s(1340), s(TOPBAR_H + 700)], fill=WATER)

# vung an toan (geofence) - vong tron net dut mau cyan
gf_cx, gf_cy, gf_r = 700, TOPBAR_H + 330, 165
for k in range(0, 360, 14):
    a0 = math.radians(k)
    a1 = math.radians(k + 7)
    x0, y0 = gf_cx + gf_r * math.cos(a0), gf_cy + gf_r * math.sin(a0)
    x1, y1 = gf_cx + gf_r * math.cos(a1), gf_cy + gf_r * math.sin(a1)
    draw.line([(s(x0), s(y0)), (s(x1), s(y1))], fill=CYAN, width=s(3.4))
circle(gf_cx, gf_cy, gf_r, fill=(*CYAN, 22))

pill((gf_cx - 92, gf_cy - gf_r - 46, gf_cx + 92, gf_cy - gf_r - 10), fill=(*NAVY, 235))
text_center((gf_cx - 92, gf_cy - gf_r - 46, gf_cx + 92, gf_cy - gf_r - 10), "Vùng an toàn", 13, CYAN, bold=True)

circle(gf_cx, gf_cy, 27, fill=CYAN, outline=WHITE, width=3.5)
icon_home(gf_cx, gf_cy + 2, 11, NAVY)

child_x, child_y = gf_cx + 55, gf_cy + 70
circle(child_x, child_y, 40, fill=(*ORANGE, 45))
icon_pin(child_x, child_y, 24, WHITE, bg=ORANGE)

# nut zoom map
zb_x0, zb_x1 = MAP_R - 74, MAP_R - 24
zb_y0, zb_y1, zb_mid, zb_y2 = BODY_TOP + 40, BODY_TOP + 200, BODY_TOP + 120, BODY_TOP + 200
rrect((zb_x0, zb_y0, zb_x1, zb_y2), 10, fill=(*NAVY, 210), outline=BORDER, width=1.5)
cx_zoom = (zb_x0 + zb_x1) / 2
draw.line([(s(zb_x0 + 12), s(zb_mid)), (s(zb_x1 - 12), s(zb_mid))], fill=BORDER, width=s(1.2))
draw.line([(s(cx_zoom - 14), s(zb_y0 + 40)), (s(cx_zoom + 14), s(zb_y0 + 40))], fill=WHITE, width=s(2.6))
draw.line([(s(cx_zoom), s(zb_y0 + 26)), (s(cx_zoom), s(zb_y0 + 54))], fill=WHITE, width=s(2.6))
draw.line([(s(cx_zoom - 14), s(zb_mid + 40)), (s(cx_zoom + 14), s(zb_mid + 40))], fill=WHITE, width=s(2.6))

pill((MAP_L + 20, BODY_TOP + 24, MAP_L + 230, BODY_TOP + 66), fill=(*NAVY, 225))
circle(MAP_L + 44, BODY_TOP + 45, 6, fill=GREEN)
text((MAP_L + 62, BODY_TOP + 45), "Đã kết nối", 12.5, GREEN, bold=True, anchor="lm")

# =====================================================================
# 3) PANEL TRAI — VUNG AN TOAN
# =====================================================================
PL, PR = 24, 380
rrect((PL, BODY_TOP + 20, PR, BODY_BOTTOM - 20), 18, fill=PANEL, outline=BORDER, width=1.5)

text((PL + 24, BODY_TOP + 46), "Vùng an toàn", 18, CYAN, bold=True)
pill((PR - 62, BODY_TOP + 40, PR - 24, BODY_TOP + 78), fill=(*CYAN, 30))
text_center((PR - 62, BODY_TOP + 40, PR - 24, BODY_TOP + 78), "+", 20, CYAN, bold=True)

draw.line([(s(PL + 20), s(BODY_TOP + 100)), (s(PR - 20), s(BODY_TOP + 100))], fill=BORDER, width=s(1.2))

zones = [
    ("Nhà", "Hình tròn · 100 m", CYAN, True),
    ("Trường học", "Hình tròn · 200 m", PURPLE, True),
    ("Đường đi học", "Đường đi · hành lang 50 m", PURPLE, False),
]
zy = BODY_TOP + 122
for name, sub, dotc, on in zones:
    rrect((PL + 16, zy, PR - 16, zy + 108), 12, fill=PANEL_2)
    circle(PL + 44, zy + 54, 7, fill=dotc)
    text((PL + 66, zy + 30), name, 15.5, WHITE, bold=True, anchor="lm")
    text((PL + 66, zy + 66), sub, 12, MUTED, anchor="lm")
    tx0, ty0, tx1, ty1 = PR - 90, zy + 38, PR - 34, zy + 70
    pill((tx0, ty0, tx1, ty1), fill=CYAN if on else (71, 85, 105))
    knob_x = tx1 - 18 if on else tx0 + 18
    circle(knob_x, (ty0 + ty1) / 2, 13, fill=WHITE)
    zy += 124

# =====================================================================
# 4) PANEL PHAI — THIET BI THEO DOI
# =====================================================================
QL, QR = 1420, 1776
rrect((QL, BODY_TOP + 20, QR, BODY_BOTTOM - 20), 18, fill=PANEL, outline=BORDER, width=1.5)

text((QL + 24, BODY_TOP + 46), "Thiết bị theo dõi", 17, CYAN, bold=True)
pill((QR - 56, BODY_TOP + 40, QR - 24, BODY_TOP + 78), fill=(*CYAN, 30))
text_center((QR - 56, BODY_TOP + 40, QR - 24, BODY_TOP + 78), "2", 14, CYAN, bold=True)
draw.line([(s(QL + 20), s(BODY_TOP + 100)), (s(QR - 20), s(BODY_TOP + 100))], fill=BORDER, width=s(1.2))

devices = [
    ("Thiết bị của con", "5 giây trước", "Online", GREEN, True),
    ("Thiết bị dự phòng", "2 giờ trước", "Offline", GRAY_OFF, False),
]
dy = BODY_TOP + 122
for name, last, status, statusc, on in devices:
    rrect((QL + 16, dy, QR - 16, dy + 118), 12, fill=PANEL_2)
    circle(QL + 46, dy + 40, 20, fill=(*CYAN, 30) if on else (*GRAY_OFF, 30))
    icon_pin(QL + 46, dy + 40, 12, CYAN if on else MUTED_DIM)
    text((QL + 78, dy + 24), name, 14.5, WHITE, bold=True, anchor="lm")
    text((QL + 78, dy + 54), last, 11.5, MUTED, anchor="lm")
    pill((QL + 78, dy + 76, QL + 78 + 82, dy + 102), fill=(*statusc, 35))
    text_center((QL + 78, dy + 76, QL + 78 + 82, dy + 102), status, 11, statusc, bold=True)
    tx0, ty0, tx1, ty1 = QR - 78, dy + 42, QR - 30, dy + 72
    pill((tx0, ty0, tx1, ty1), fill=CYAN if on else (71, 85, 105))
    knob_x = tx1 - 16 if on else tx0 + 16
    circle(knob_x, (ty0 + ty1) / 2, 11, fill=WHITE)
    dy += 132

rrect((QL + 16, dy + 6, QR - 16, dy + 70), 12, outline=CYAN, width=1.6)
text_center((QL + 16, dy + 6, QR - 16, dy + 70), "+  Thêm thiết bị", 13.5, CYAN, bold=True)

# =====================================================================
# 5) BOTTOM BAR — CHE DO
# =====================================================================
rrect((0, BODY_BOTTOM, 1800, 1050), 0, fill=NAVY)
pill((24, BODY_BOTTOM + 20, 168, BODY_BOTTOM + 72), fill=(*CYAN, 30))
text_center((24, BODY_BOTTOM + 20, 168, BODY_BOTTOM + 72), "Cố định", 14, CYAN, bold=True)
pill((180, BODY_BOTTOM + 20, 320, BODY_BOTTOM + 72), fill=PANEL_2)
text_center((180, BODY_BOTTOM + 20, 320, BODY_BOTTOM + 72), "Di động", 14, MUTED, bold=True)

circle(354, BODY_BOTTOM + 46, 4, fill=CYAN)
text((372, BODY_BOTTOM + 46), "100 m · 3 vùng", 13, MUTED, anchor="lm")

pill((1580, BODY_BOTTOM + 20, 1776, BODY_BOTTOM + 72), fill=(*ORANGE, 25))
text_center((1580, BODY_BOTTOM + 20, 1776, BODY_BOTTOM + 72), "Chia sẻ: Bật", 13, ORANGE, bold=True)

# =====================================================================
# LUU FILE (thu nho lai de khu rang cua / AA)
# =====================================================================
img = img.resize((1800, 1050), Image.LANCZOS)
img.save(OUT_PATH)
print("Saved:", OUT_PATH)
