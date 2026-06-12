#!/usr/bin/env python3
"""
mqtt_bot.py — Fake GPS bot gửi dữ liệu liên tục lên MQTT cho child tracking.

Chế độ di chuyển (--mode):
  circle   Đi vòng tròn quanh tâm geofence — luôn trong geofence (mặc định)
  wander   Đi ngẫu nhiên xung quanh, có thể ra/vào geofence
  patrol   Ra ngoài geofence rồi quay về, lặp lại — dùng để test alert

Ví dụ:
  python mqtt_bot.py
  python mqtt_bot.py --mode patrol --interval 2
  python mqtt_bot.py --mode wander --device-id child_02
  python mqtt_bot.py --host mqtt.broker.io --port 1883
"""

import json
import math
import random
import sys
import time
import argparse
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

# ── Hằng số địa lý ─────────────────────────────────────────────────────────────

DEFAULT_CENTER_LAT  = 21.0285    # Tâm geofence mặc định (Hà Nội)
DEFAULT_CENTER_LNG  = 105.8542
DEFAULT_GEOFENCE_M  = 100.0
M_PER_DEG_LAT       = 111_320.0  # Số mét trên 1 độ vĩ độ


def _m_per_deg_lng(lat: float) -> float:
    return M_PER_DEG_LAT * math.cos(math.radians(lat))


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Khoảng cách Haversine (mét) giữa hai tọa độ."""
    R = 6_371_000.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlng / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(min(1.0, a)))


def _move(lat: float, lng: float, heading_deg: float, dist_m: float):
    """Di chuyển dist_m mét theo hướng heading_deg từ (lat, lng)."""
    rad = math.radians(heading_deg)
    dlat = (dist_m * math.cos(rad)) / M_PER_DEG_LAT
    dlng = (dist_m * math.sin(rad)) / _m_per_deg_lng(lat)
    return lat + dlat, lng + dlng


# ── Chế độ di chuyển ───────────────────────────────────────────────────────────

class CircleWalker:
    """Đi theo đường tròn clockwise quanh tâm. Luôn ở trong geofence nếu radius < geofence."""

    def __init__(self, center_lat: float, center_lng: float,
                 radius_m: float = 70.0, step_m: float = 10.0):
        self.clat    = center_lat
        self.clng    = center_lng
        self.radius  = radius_m
        self.angle   = 0.0
        # Góc quét mỗi bước: s = r * dθ  =>  dθ = step_m / radius
        self.d_angle = step_m / radius_m  # radian

    def next(self):
        lat = self.clat + (self.radius / M_PER_DEG_LAT) * math.sin(self.angle)
        lng = self.clng + (self.radius / _m_per_deg_lng(self.clat)) * math.cos(self.angle)
        self.angle = (self.angle + self.d_angle) % (2 * math.pi)
        return round(lat, 7), round(lng, 7)


class WanderWalker:
    """Đi ngẫu nhiên — hướng thay đổi chậm, khi đi quá xa sẽ tự xoay về tâm."""

    SOFT_BOUNDARY_M = 250.0  # Khoảng cách để bắt đầu kéo về tâm

    def __init__(self, center_lat: float, center_lng: float,
                 step_m: float = 12.0, heading_noise: float = 25.0):
        self.clat          = center_lat
        self.clng          = center_lng
        self.lat           = center_lat
        self.lng           = center_lng
        self.step_m        = step_m
        self.heading       = random.uniform(0.0, 360.0)
        self.heading_noise = heading_noise

    def next(self):
        # Nếu quá xa tâm → xoay dần về hướng tâm
        dist = haversine_m(self.clat, self.clng, self.lat, self.lng)
        if dist > self.SOFT_BOUNDARY_M:
            dlat = self.clat - self.lat
            dlng = self.clng - self.lng
            target_heading = math.degrees(math.atan2(dlng, dlat)) % 360
            # Xoay 20% về hướng tâm
            diff = (target_heading - self.heading + 540) % 360 - 180
            self.heading = (self.heading + diff * 0.20) % 360

        self.heading = (self.heading + random.uniform(-self.heading_noise, self.heading_noise)) % 360
        self.lat, self.lng = _move(self.lat, self.lng, self.heading, self.step_m)
        return round(self.lat, 7), round(self.lng, 7)


class PatrolWalker:
    """
    Ra ngoài geofence theo hướng Bắc → dừng vài điểm → quay về tâm → lặp lại.
    Thiết kế để trigger alert outside_entered → outside_reminder → inside_entered.
    """

    def __init__(self, center_lat: float, center_lng: float,
                 geofence_m: float = 100.0, step_m: float = 15.0,
                 outside_target_m: float = 200.0, dwell_steps: int = 6):
        self.clat             = center_lat
        self.clng             = center_lng
        self.geofence_m       = geofence_m
        self.step_m           = step_m
        self.outside_target_m = outside_target_m
        self.dwell_steps      = dwell_steps
        self._waypoints       = self._build()
        self._idx             = 0

    def _build(self):
        pts = []
        lat, lng = self.clat, self.clng

        # Giai đoạn 1: đi ra ngoài theo hướng Bắc
        while haversine_m(self.clat, self.clng, lat, lng) < self.outside_target_m:
            lat, lng = _move(lat, lng, 0.0, self.step_m)
            pts.append((round(lat, 7), round(lng, 7)))

        # Giai đoạn 2: dừng ở ngoài (dwell)
        for _ in range(self.dwell_steps):
            pts.append((round(lat, 7), round(lng, 7)))

        # Giai đoạn 3: quay về hướng Nam
        while haversine_m(self.clat, self.clng, lat, lng) > self.step_m * 0.5:
            lat, lng = _move(lat, lng, 180.0, self.step_m)
            pts.append((round(lat, 7), round(lng, 7)))

        # Giai đoạn 4: dừng ở tâm (dwell)
        for _ in range(self.dwell_steps):
            pts.append((round(self.clat, 7), round(self.clng, 7)))

        return pts

    def next(self):
        pt = self._waypoints[self._idx]
        self._idx = (self._idx + 1) % len(self._waypoints)
        return pt


# ── MQTT Bot ───────────────────────────────────────────────────────────────────

def run_bot(args):
    # Khởi tạo walker theo mode
    if args.mode == "circle":
        walker = CircleWalker(
            args.center_lat, args.center_lng,
            radius_m=args.radius, step_m=args.step,
        )
    elif args.mode == "wander":
        walker = WanderWalker(
            args.center_lat, args.center_lng,
            step_m=args.step,
        )
    else:  # patrol
        walker = PatrolWalker(
            args.center_lat, args.center_lng,
            geofence_m=args.geofence_m, step_m=args.step,
        )

    topic = f"gps/{args.device_id}"

    # ── MQTT client setup ──────────────────────────────────────────────────────
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

    if args.username:
        client.username_pw_set(args.username, args.password or "")

    _connected = [False]

    def on_connect(c, _u, _f, rc, _p):
        if rc == 0:
            _connected[0] = True
            print(f"[MQTT] Đã kết nối tới {args.host}:{args.port}")
        else:
            print(f"[LỖI] Kết nối thất bại, rc={rc}")
            sys.exit(1)

    def on_disconnect(c, _u, _f, rc, _p):
        _connected[0] = False
        if rc != 0:
            print(f"[MQTT] Mất kết nối (rc={rc}), đang thử lại...")

    client.on_connect    = on_connect
    client.on_disconnect = on_disconnect

    # ── Header in ──────────────────────────────────────────────────────────────
    line = "─" * 62
    mode_desc = {
        "circle": "Vòng tròn quanh tâm (luôn trong geofence)",
        "wander": "Đi ngẫu nhiên (có thể ra/vào geofence)",
        "patrol": "Ra ngoài rồi quay về (test alert)",
    }
    print(f"\n╔{line}╗")
    print(f"║  MQTT GPS Bot")
    print(f"╠{line}╣")
    print(f"║  Device  : {args.device_id}")
    print(f"║  Broker  : {args.host}:{args.port}  →  topic: {topic}")
    print(f"║  Mode    : {args.mode}  —  {mode_desc[args.mode]}")
    print(f"║  Interval: {args.interval}s / lần   Bước: {args.step}m")
    print(f"║  Tâm     : {args.center_lat}, {args.center_lng}   Geofence: {args.geofence_m}m")
    print(f"╚{line}╝")
    print("  Nhấn Ctrl+C để dừng.\n")
    print(f"  {'SEQ':>5}  {'THỜI GIAN (UTC)':>15}  {'TRẠNG THÁI':>12}  {'LAT':>12}  {'LNG':>12}  {'DIST':>8}")
    print(f"  {'─'*5}  {'─'*15}  {'─'*12}  {'─'*12}  {'─'*12}  {'─'*8}")

    try:
        client.connect(args.host, args.port, keepalive=60)
    except Exception as e:
        print(f"\n[LỖI] Không thể kết nối MQTT broker {args.host}:{args.port}")
        print(f"       {e}")
        print("\nKiểm tra lại:")
        print("  • MQTT broker có đang chạy không?  (docker ps | grep mosquitto)")
        print("  • Đúng host/port chưa?              (--host, --port)")
        sys.exit(1)

    client.loop_start()
    time.sleep(0.6)  # Chờ on_connect callback

    seq = 0
    try:
        while True:
            lat, lng = walker.next()

            # UTC timestamp — trường bắt buộc cho LocationIn model
            now_epoch = int(time.time())
            now_str   = datetime.now(timezone.utc).strftime("%H:%M:%S")

            dist   = haversine_m(args.center_lat, args.center_lng, lat, lng)
            inside = dist <= args.geofence_m
            status = "🟢 TRONG" if inside else "🔴 NGOÀI"

            payload = {
                "deviceId":  args.device_id,
                "lat":       lat,
                "lng":       lng,
                "timestamp": now_epoch,
            }

            info = client.publish(topic, json.dumps(payload), qos=1)
            try:
                info.wait_for_publish(timeout=3.0)
            except Exception:
                print(f"\n[CẢNH BÁO] Publish timeout tại seq={seq}, tiếp tục...")

            print(
                f"  {seq:>5}  {now_str:>15}  {status:>12}  "
                f"{lat:>12.6f}  {lng:>12.6f}  {dist:>7.1f}m"
            )

            seq += 1
            time.sleep(args.interval)

    except KeyboardInterrupt:
        print("\n\n[MQTT] Đã dừng bởi người dùng.")
    finally:
        client.loop_stop()
        client.disconnect()
        print(f"[MQTT] Ngắt kết nối. Đã gửi {seq} điểm.")


# ── CLI ────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Fake GPS bot gửi liên tục lên MQTT.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # MQTT
    parser.add_argument("--host",       default="localhost",
                        help="MQTT broker host (default: localhost)")
    parser.add_argument("--port",       type=int, default=1883,
                        help="MQTT broker port (default: 1883)")
    parser.add_argument("--username",   default=None, help="MQTT username (nếu có)")
    parser.add_argument("--password",   default=None, help="MQTT password (nếu có)")

    # Device
    parser.add_argument("--device-id",  default="child_01",
                        help="Device ID (default: child_01)")

    # Movement
    parser.add_argument("--mode",       default="circle",
                        choices=["circle", "wander", "patrol"],
                        help="Chế độ di chuyển (default: circle)")
    parser.add_argument("--interval",   type=float, default=2.0,
                        help="Giây giữa hai lần gửi (default: 2.0)")
    parser.add_argument("--step",       type=float, default=10.0,
                        help="Bước di chuyển (mét, default: 10 — phải > 5m để qua noise filter)")
    parser.add_argument("--radius",     type=float, default=70.0,
                        help="Bán kính vòng tròn — chỉ dùng với --mode circle (default: 70m)")

    # Geofence center
    parser.add_argument("--center-lat", type=float, default=DEFAULT_CENTER_LAT,
                        help=f"Vĩ độ tâm (default: {DEFAULT_CENTER_LAT})")
    parser.add_argument("--center-lng", type=float, default=DEFAULT_CENTER_LNG,
                        help=f"Kinh độ tâm (default: {DEFAULT_CENTER_LNG})")
    parser.add_argument("--geofence-m", type=float, default=DEFAULT_GEOFENCE_M,
                        help=f"Bán kính geofence để hiển thị status (default: {DEFAULT_GEOFENCE_M}m)")

    run_bot(parser.parse_args())
