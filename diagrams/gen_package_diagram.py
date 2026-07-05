"""
Bieu do goi (package diagram) tong quan he thong - ban sua loi.

Sua diem sai so voi ban cu (package_diagram.drawio -> bieudo_goi.png):
  - ESP32 Firmware: ban cu ve 2 package con "gps" / "mqtt_client" nhu the
    la 2 module/thu muc rieng biet. Thuc te toan bo firmware chi la MOT
    file main.cpp (227 dong) + crypto.h, khong co tach thu muc con nao.
    -> ve lai thanh MOT khoi duy nhat, ghi chu ro "(khong tach package con)".

Package "utils" ben Flutter App duoc ve doc lap, khong co mui ten vao/ra
(khong ve chi tiet quan he phu thuoc noi bo toi tung file util).

Output: ../Final/SOICT_DATN_Duong/Hinhve/bieudo_goi.png
"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle

fig, ax = plt.subplots(figsize=(20, 13))
ax.set_xlim(0, 20)
ax.set_ylim(0, 13)
ax.axis("off")
fig.patch.set_facecolor("white")

GRAY = "#333333"
DGRAY = "#555555"
LGRAY = "#9A9A9A"


def package(ax, x, y, w, h, label, sublabel=None, fontsize=11.5, tab_w=None, tab_h=0.22):
    if tab_w is None:
        tab_w = min(1.3, w * 0.42)
    ax.add_patch(Rectangle((x, y + h), tab_w, tab_h, facecolor="white", edgecolor=GRAY, lw=1.4, zorder=3))
    ax.add_patch(Rectangle((x, y), w, h, facecolor="white", edgecolor=GRAY, lw=1.4, zorder=2))
    cy = y + h / 2 + (0.15 if sublabel else 0)
    ax.text(x + w / 2, cy, label, ha="center", va="center",
            fontsize=fontsize, fontweight="bold", zorder=4, color="#111111")
    if sublabel:
        ax.text(x + w / 2, y + h / 2 - 0.22, sublabel, ha="center", va="center",
                fontsize=fontsize * 0.68, style="italic", color=DGRAY, zorder=4)


def container(ax, x, y, w, h, label):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="square,pad=0",
                                 facecolor="none", edgecolor="black", lw=2.2, zorder=1))
    ax.text(x + w / 2, y + h - 0.32, label, ha="center", va="center",
            fontsize=15, fontweight="bold", zorder=4)


def ext_box(ax, x, y, w, h, label):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.06",
                                 facecolor="white", edgecolor=GRAY, lw=1.6, zorder=3))
    ax.text(x + w / 2, y + h / 2, label, ha="center", va="center",
            fontsize=12.5, fontweight="bold", zorder=4)


def dep(ax, x1, y1, x2, y2, bidir=False):
    style = "<->" if bidir else "->"
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle=style, color=LGRAY, lw=1.1,
                                 linestyle=(0, (4, 2)), shrinkA=1, shrinkB=1), zorder=2)


def dep_elbow(ax, pts):
    """Dependency net dut nhieu doan (dung khi diem den nam lech hang/cot)."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ax.plot(xs[:-1], ys[:-1], color=LGRAY, lw=1.1, linestyle=(0, (4, 2)), zorder=2)
    ax.annotate("", xy=pts[-1], xytext=pts[-2],
                arrowprops=dict(arrowstyle="->", color=LGRAY, lw=1.1,
                                 linestyle=(0, (4, 2))), zorder=2)


def elbow(ax, pts, label="", label_pos=None):
    """Duong noi vuong goc: pts la danh sach (x,y); doan cuoi co mui ten."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ax.plot(xs[:-1], ys[:-1], color="black", lw=2.0, zorder=5, solid_capstyle="round")
    ax.annotate("", xy=pts[-1], xytext=pts[-2],
                arrowprops=dict(arrowstyle="->", color="black", lw=2.0), zorder=5)
    if label:
        if label_pos is None:
            mx, my = xs[len(xs) // 2], ys[len(xs) // 2]
        else:
            mx, my = label_pos
        ax.text(mx, my, label, ha="center", va="center", fontsize=11,
                color="#111111", bbox=dict(fc="white", ec="none", pad=1.5), zorder=6)


def layer_label(ax, cx, y, text):
    ax.text(cx, y, text, ha="center", va="center", fontsize=11.5, style="italic", color="#333333")


def layer_divider(ax, x1, x2, y):
    ax.plot([x1, x2], [y, y], color=LGRAY, lw=1.2, linestyle=(0, (5, 3)), zorder=1)


# ============================================================ TITLE =========
ax.text(10, 12.6, "Biểu đồ gói tổng quan hệ thống (đã hiệu chỉnh khớp code thật)",
        ha="center", va="center", fontsize=16, fontweight="bold")

# ============================================================ ESP32 =========
ext_box(ax, 0.4, 9.9, 3.6, 1.0, "MQTT Broker")
container(ax, 0.4, 6.7, 3.6, 2.6, "")
ax.text(0.4 + 1.8, 6.7 + 2.6 - 0.35, "ESP32 Firmware", ha="center", va="center",
        fontsize=13.5, fontweight="bold")
package(ax, 0.8, 7.2, 2.8, 1.0, "main.cpp", "(không tách package con)", fontsize=12.5)
ext_box(ax, 0.4, 3.4, 3.6, 1.0, "Telegram / Email")

elbow(ax, [(2.2, 9.3), (2.2, 9.9)], "Publish", label_pos=(2.85, 9.6))

# ============================================================ BACKEND =======
BX, BY, BW, BH = 5.3, 2.0, 8.0, 9.8
container(ax, BX, BY, BW, BH, "Backend (FastAPI)")
CX = BX + BW / 2

api_y, api_h = BY + BH - 1.9, 0.9
layer_label(ax, CX, api_y + api_h + 0.3, "«API Layer»")
package(ax, CX - 1.3, api_y, 2.6, api_h, "api")
layer_divider(ax, BX + 0.15, BX + BW - 0.15, api_y - 0.35)

svc_y, svc_h = api_y - 1.65, 0.9
layer_label(ax, CX, svc_y + svc_h + 0.3, "«Service Layer»")
package(ax, CX - 1.5, svc_y, 3.0, svc_h, "services")
layer_divider(ax, BX + 0.15, BX + BW - 0.15, svc_y - 0.35)

infra_y, infra_h = svc_y - 1.65, 0.9
layer_label(ax, CX, infra_y + infra_h + 0.3, "«Infrastructure Layer»")
package(ax, BX + 0.6, infra_y, 2.3, infra_h, "repositories", fontsize=11)
package(ax, BX + 3.2, infra_y, 1.8, infra_h, "core", fontsize=11)
package(ax, BX + 5.3, infra_y, 1.6, infra_h, "ws", fontsize=11)
layer_divider(ax, BX + 0.15, BX + BW - 0.15, infra_y - 0.35)

data_y, data_h = infra_y - 1.65, 0.9
layer_label(ax, CX, data_y + data_h + 0.3, "«Data Layer»")
package(ax, BX + 1.4, data_y, 2.2, data_h, "models", fontsize=11.5)
package(ax, BX + 4.3, data_y, 2.2, data_h, "db", fontsize=11.5)

# --- dependency noi bo (net dut, xam nhat) ---
dep(ax, CX, api_y, CX, svc_y + svc_h)
dep(ax, CX - 1.0, svc_y, BX + 1.75, infra_y + infra_h)
dep(ax, CX, svc_y, BX + 4.1, infra_y + infra_h)
dep(ax, CX + 1.0, svc_y, BX + 6.1, infra_y + infra_h)
dep(ax, BX + 1.75, infra_y, BX + 2.3, data_y + data_h)
dep(ax, BX + 1.75, infra_y, BX + 5.2, data_y + data_h)

# --- luong ben ngoai, di doc theo hanh lang trai cua khung Backend ---
elbow(ax, [(4.0, 10.4), (5.55, 10.4), (5.55, svc_y + 0.6), (CX - 1.5, svc_y + 0.6)],
      "Subscribe", label_pos=(5.55, 10.65))
elbow(ax, [(CX - 1.5, svc_y + 0.3), (5.7, svc_y + 0.3), (5.7, 3.9), (4.0, 3.9)],
      "Alert", label_pos=(5.7, 5.2))

# db -> MongoDB
MONGO_Y = 0.3
ext_box(ax, BX + 3.2, MONGO_Y, 2.2, 0.9, "MongoDB")
elbow(ax, [(BX + 5.4, data_y), (BX + 5.4, MONGO_Y + 0.9)], "Read / Write",
      label_pos=(BX + 6.35, data_y - 0.45))

# ============================================================ FLUTTER =======
FX, FY, FW, FH = 15.0, 2.0, 4.6, 9.8
container(ax, FX, FY, FW, FH, "Flutter App")

scr_y = FY + FH - 1.75
package(ax, FX + 0.3, scr_y, 4.0, 0.9, "screens", fontsize=11.5)
row2_y = scr_y - 1.55
package(ax, FX + 0.3, row2_y, 1.8, 0.85, "widgets", fontsize=10.5)
package(ax, FX + 2.4, row2_y, 1.9, 0.85, "providers", fontsize=10.5)
row3_y = row2_y - 1.55
package(ax, FX + 0.2, row3_y, 1.5, 0.85, "services", fontsize=10)
package(ax, FX + 1.85, row3_y, 1.4, 0.85, "models", fontsize=10)
package(ax, FX + 3.35, row3_y, 1.1, 0.85, "config", fontsize=9.5)
utils_y = row3_y - 1.55
package(ax, FX + 1.3, utils_y, 2.0, 0.85, "utils", fontsize=11)

dep(ax, FX + 1.2, scr_y, FX + 1.1, row2_y + 0.85)
dep(ax, FX + 2.8, scr_y, FX + 3.2, row2_y + 0.85)
dep(ax, FX + 2.1, row2_y + 0.42, FX + 2.4, row2_y + 0.42, bidir=True)
dep(ax, FX + 3.1, row2_y, FX + 0.95, row3_y + 0.85)
dep(ax, FX + 3.3, row2_y, FX + 2.55, row3_y + 0.85)
dep(ax, FX + 3.6, row2_y, FX + 3.85, row3_y + 0.85)

# Backend <-> Flutter
rest_y = row2_y + 0.42
elbow(ax, [(BX + BW, rest_y), (FX, rest_y)], "REST / WebSocket")
ax.annotate("", xy=(BX + BW, rest_y), xytext=(FX, rest_y),
            arrowprops=dict(arrowstyle="->", color="black", lw=2.0), zorder=5)

plt.tight_layout()
plt.savefig("../Final/SOICT_DATN_Duong/Hinhve/bieudo_goi.png",
            dpi=180, bbox_inches="tight", facecolor="white")
print("Saved: bieudo_goi.png")
