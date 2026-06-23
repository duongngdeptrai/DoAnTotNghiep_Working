"""
Sơ đồ 1: Kiến trúc hệ thống tổng thể
Output: ../SOICT_DATN_Duong/Hinhve/architecture.png
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

fig, ax = plt.subplots(figsize=(16, 7))
ax.set_xlim(0, 16)
ax.set_ylim(0, 7)
ax.axis("off")
fig.patch.set_facecolor("white")

# ── Helpers ──────────────────────────────────────────────────────────────────
def box(ax, x, y, w, h, label, sublabel="", fc="#FFFFFF", ec="#333333", lw=1.5):
    rect = FancyBboxPatch((x, y), w, h,
                          boxstyle="round,pad=0.08",
                          facecolor=fc, edgecolor=ec, linewidth=lw, zorder=3)
    ax.add_patch(rect)
    cx, cy = x + w / 2, y + h / 2
    if sublabel:
        ax.text(cx, cy + 0.18, label, ha="center", va="center",
                fontsize=10, fontweight="bold", zorder=4)
        ax.text(cx, cy - 0.22, sublabel, ha="center", va="center",
                fontsize=8.5, color="#444444", zorder=4)
    else:
        ax.text(cx, cy, label, ha="center", va="center",
                fontsize=10, fontweight="bold", zorder=4)

def arrow(ax, x1, y1, x2, y2, label="", label2="", bidirectional=False,
          color="#333333", lw=1.8):
    style = "<->" if bidirectional else "->"
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle=style, color=color,
                                lw=lw, connectionstyle="arc3,rad=0"))
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    if label:
        offset = 0.18 if label2 else 0
        ax.text(mx, my + offset, label, ha="center", va="center",
                fontsize=8, color="#222222",
                bbox=dict(fc="white", ec="none", pad=1), zorder=5)
    if label2:
        ax.text(mx, my - 0.18, label2, ha="center", va="center",
                fontsize=8, color="#666666",
                bbox=dict(fc="white", ec="none", pad=1), zorder=5)

# ── Layer background bands ─────────────────────────────────────────────────
layer_data = [
    (0.1,  3.5, "#E8F4FD", "Tầng\nthiết bị"),
    (3.7,  3.5, "#FFF3E0", "Tầng\ntruyền thông"),
    (7.3,  3.5, "#E8F5E9", "Tầng\ndịch vụ"),
    (11.0, 5.0, "#F3E5F5", "Tầng\nứng dụng"),
]
for lx, lw, lc, lname in layer_data:
    rect = FancyBboxPatch((lx, 0.5), lw, 5.8,
                          boxstyle="round,pad=0.1",
                          facecolor=lc, edgecolor="none", zorder=1)
    ax.add_patch(rect)
    ax.text(lx + lw / 2, 6.6, lname, ha="center", va="center",
            fontsize=8.5, color="#666666", style="italic")

# ── Main nodes ────────────────────────────────────────────────────────────
#  Row 1 (y=3.5): main horizontal flow
box(ax,  0.4, 3.5, 3.0, 1.5, "Thiết bị IoT", "ESP32 + SIM7000G",
    fc="#DBEAFE", ec="#1D4ED8")
box(ax,  4.0, 3.5, 3.0, 1.5, "MQTT Broker",  "EMQX Public",
    fc="#FEF3C7", ec="#D97706")
box(ax,  7.6, 3.5, 3.0, 1.5, "Backend",       "FastAPI",
    fc="#D1FAE5", ec="#059669")
box(ax, 11.4, 3.5, 3.2, 1.5, "Ứng dụng",      "Flutter App",
    fc="#EDE9FE", ec="#7C3AED")

# Row 2 (y=1.2): storage + notifications
box(ax,  7.6, 1.2, 3.0, 1.4, "Cơ sở dữ liệu", "MongoDB",
    fc="#ECFDF5", ec="#10B981")
box(ax,  4.5, 1.2, 2.4, 1.4, "Telegram Bot", "",
    fc="#DBEAFE", ec="#3B82F6")
box(ax,  1.8, 1.2, 2.4, 1.4, "Email (SMTP)", "",
    fc="#FEE2E2", ec="#EF4444")

# ── Arrows ────────────────────────────────────────────────────────────────
# Device → Broker
arrow(ax, 3.4, 4.25, 4.0, 4.25,
      label="MQTT Publish", label2="qua GPRS", color="#1D4ED8")

# Broker → Backend
arrow(ax, 7.0, 4.25, 7.6, 4.25,
      label="MQTT Subscribe", color="#D97706")

# Backend ↔ Flutter (REST API + WebSocket)
arrow(ax, 10.6, 4.25, 11.4, 4.25,
      label="REST API", label2="WebSocket",
      bidirectional=True, color="#7C3AED")

# Backend ↔ MongoDB
arrow(ax, 9.1, 3.5, 9.1, 2.6,
      label="đọc/ghi", bidirectional=True, color="#059669")

# Backend → Telegram (bend left)
ax.annotate("", xy=(5.7, 2.6), xytext=(9.1, 3.5),
            arrowprops=dict(arrowstyle="->", color="#3B82F6", lw=1.5,
                            connectionstyle="arc3,rad=0.25"))

# Backend → Email (bend more)
ax.annotate("", xy=(3.0, 2.6), xytext=(9.1, 3.5),
            arrowprops=dict(arrowstyle="->", color="#EF4444", lw=1.5,
                            connectionstyle="arc3,rad=0.35"))

ax.text(7.2, 2.55, "cảnh báo", ha="center", va="top",
        fontsize=8, color="#555555",
        bbox=dict(fc="white", ec="none", pad=1))

# ── Title ─────────────────────────────────────────────────────────────────
ax.set_title("Kiến trúc tổng thể hệ thống theo dõi vị trí trẻ em",
             fontsize=13, fontweight="bold", pad=14)

plt.tight_layout()
plt.savefig("../SOICT_DATN_Duong/Hinhve/architecture.png",
            dpi=200, bbox_inches="tight", facecolor="white")
print("Saved: Hinhve/architecture.png")
plt.show()
