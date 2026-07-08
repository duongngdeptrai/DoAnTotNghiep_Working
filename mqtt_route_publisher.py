"""
MQTT Route Publisher — bắn GPS giả bám theo đường thật (OSRM routing),
mặc định đi từ Vĩnh Phúc (Vĩnh Yên) đến Đại học Bách Khoa Hà Nội.

Dùng OSRM demo server (router.project-osrm.org) để lấy tuyến đường thật
(snapped vào đường bộ, giống Google Maps Directions) — miễn phí, không cần API key.

Dùng:
  python mqtt_route_publisher.py                          # Vĩnh Yên -> HUST, 40km/h, gửi mỗi 3s
  python mqtt_route_publisher.py --speed-kmh 60 --interval 5
  python mqtt_route_publisher.py --reverse                # HUST -> Vĩnh Yên
  python mqtt_route_publisher.py --loop                   # đi hết tuyến thì quay đầu, lặp mãi
  python mqtt_route_publisher.py --plain                  # gửi JSON thuần, không mã hóa
  python mqtt_route_publisher.py --start-lat 21.31 --start-lng 105.60 --end-lat 21.01 --end-lng 105.84
"""

import argparse
import base64
import json
import math
import os
import sys
import time

import paho.mqtt.client as mqtt
import requests

if sys.platform == "win32":
    # Console Windows mặc định dùng codepage cp1252, không encode được tiếng Việt có dấu.
    sys.stdout.reconfigure(encoding="utf-8")
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

# ─── Cấu hình (khớp với mqtt_fake_publisher.py / backend .env) ─────────────
BROKER = os.getenv("MQTT_HOST", "broker.emqx.io")
PORT = int(os.getenv("MQTT_PORT", "1883"))
GPS_TOPIC = os.getenv("MQTT_TOPIC", "dotn/duong29/gps/child_01")
ENC_KEY = os.getenv("MQTT_ENCRYPTION_KEY", "a35f8c2d71b94e06c81a3f90d25b7e44")
DEVICE_ID = os.getenv("DEFAULT_DEVICE_ID", "child_01")

OSRM_URL = "http://router.project-osrm.org/route/v1/driving/{lng1},{lat1};{lng2},{lat2}"

# Điểm mặc định
DEFAULT_START = (21.3089, 105.6049)  # Vĩnh Yên, Vĩnh Phúc (trung tâm)
DEFAULT_END = (21.0069, 105.8432)  # Đại học Bách Khoa Hà Nội (cổng chính)

EARTH_RADIUS_M = 6371000


def haversine_m(lat1, lng1, lat2, lng2):
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return EARTH_RADIUS_M * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def fetch_route(start, end):
    """Lấy tuyến đường thật (bám đường bộ) từ OSRM. Trả về list[(lat, lng)]."""
    lat1, lng1 = start
    lat2, lng2 = end
    url = OSRM_URL.format(lng1=lng1, lat1=lat1, lng2=lng2, lat2=lat2)
    resp = requests.get(url, params={"overview": "full", "geometries": "geojson"}, timeout=20)
    resp.raise_for_status()
    data = resp.json()
    if data.get("code") != "Ok" or not data.get("routes"):
        raise RuntimeError(f"OSRM không tìm được tuyến đường: {data.get('code')}")
    route = data["routes"][0]
    coords = route["geometry"]["coordinates"]  # [[lng, lat], ...]
    points = [(lat, lng) for lng, lat in coords]
    return points, route["distance"]


def resample_by_distance(points, step_m):
    """Chia lại tuyến đường thành các điểm cách đều nhau step_m mét,
    nội suy tuyến tính giữa 2 đỉnh gần nhất để vẫn bám đúng hình dạng đường."""
    if step_m <= 0:
        return list(points)

    resampled = [points[0]]
    target = step_m  # mốc khoảng cách lũy kế tiếp theo cần xuất 1 điểm
    cum = 0.0  # khoảng cách lũy kế tới đầu đoạn đang xét

    for i in range(len(points) - 1):
        lat1, lng1 = points[i]
        lat2, lng2 = points[i + 1]
        seg_len = haversine_m(lat1, lng1, lat2, lng2)
        if seg_len == 0:
            continue

        seg_end = cum + seg_len
        while target <= seg_end:
            frac = (target - cum) / seg_len
            resampled.append((lat1 + (lat2 - lat1) * frac, lng1 + (lng2 - lng1) * frac))
            target += step_m
        cum = seg_end

    if resampled[-1] != points[-1]:
        resampled.append(points[-1])
    return resampled


def add_jitter(lat, lng, jitter_m):
    if jitter_m <= 0:
        return lat, lng
    import random

    dlat = random.uniform(-jitter_m, jitter_m) / 111_320
    dlng = random.uniform(-jitter_m, jitter_m) / (111_320 * math.cos(math.radians(lat)) or 1)
    return lat + dlat, lng + dlng


def encrypt_payload(data: dict, key_hex: str) -> bytes:
    """AES-128 CBC: base64(IV[16] || ciphertext) — khớp với crypto.py của backend."""
    key = bytes.fromhex(key_hex)
    iv = os.urandom(16)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    plaintext = json.dumps(data).encode()
    ciphertext = cipher.encrypt(pad(plaintext, AES.block_size))
    return base64.b64encode(iv + ciphertext)


def main():
    parser = argparse.ArgumentParser(description="Bắn GPS giả bám theo đường thật (OSRM) qua MQTT")
    parser.add_argument("--start-lat", type=float, default=DEFAULT_START[0])
    parser.add_argument("--start-lng", type=float, default=DEFAULT_START[1])
    parser.add_argument("--end-lat", type=float, default=DEFAULT_END[0])
    parser.add_argument("--end-lng", type=float, default=DEFAULT_END[1])
    parser.add_argument("--speed-kmh", type=float, default=40.0, help="Tốc độ di chuyển giả lập (km/h)")
    parser.add_argument("--interval", type=float, default=3.0, help="Giây giữa mỗi bản tin GPS")
    parser.add_argument("--jitter-m", type=float, default=0.0, help="Nhiễu GPS giả lập (mét), 0 = tắt")
    parser.add_argument("--plain", action="store_true", help="Gửi JSON thuần (không mã hóa)")
    parser.add_argument("--reverse", action="store_true", help="Đi ngược lại: end -> start")
    parser.add_argument("--loop", action="store_true", help="Đi hết tuyến thì quay đầu, lặp vô hạn")
    parser.add_argument("--device-id", default=DEVICE_ID, help="deviceId gửi lên MQTT")
    parser.add_argument("--max-points", type=int, default=0, help="Chỉ gửi N điểm đầu rồi dừng (0 = đi hết tuyến), tiện để test nhanh")
    args = parser.parse_args()

    start = (args.start_lat, args.start_lng)
    end = (args.end_lat, args.end_lng)
    if args.reverse:
        start, end = end, start

    print(f"[OSRM] Đang lấy tuyến đường {start} -> {end} ...")
    points, distance_m = fetch_route(start, end)
    print(f"[OSRM] Tuyến dài {distance_m / 1000:.2f} km, {len(points)} điểm thô từ OSRM")

    step_m = max(args.speed_kmh * 1000 / 3600 * args.interval, 1.0)
    path = resample_by_distance(points, step_m)
    total_min = len(path) * args.interval / 60
    print(f"[SIM] Tốc độ {args.speed_kmh} km/h, mỗi {args.interval}s đi ~{step_m:.0f}m")
    print(f"[SIM] {len(path)} điểm sẽ gửi, tổng thời gian mô phỏng ~{total_min:.1f} phút")

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

    def on_connect(c, userdata, flags, rc, props):
        if rc == 0:
            print(f"[+] Đã kết nối tới {BROKER}:{PORT}")
        else:
            print(f"[-] Kết nối thất bại, mã lỗi: {rc}")

    client.on_connect = on_connect
    client.connect(BROKER, PORT, keepalive=60)
    client.loop_start()
    time.sleep(1)

    def publish(lat, lng, dist_so_far_km):
        jlat, jlng = add_jitter(lat, lng, args.jitter_m)
        data = {
            "deviceId": args.device_id,
            "lat": round(jlat, 6),
            "lng": round(jlng, 6),
            "timestamp": int(time.time()),
        }
        raw = json.dumps(data).encode() if args.plain else encrypt_payload(data, ENC_KEY)
        client.publish(GPS_TOPIC, raw)
        pct = dist_so_far_km / (distance_m / 1000) * 100
        print(f"  [{dist_so_far_km:6.2f}/{distance_m / 1000:.2f} km, {pct:5.1f}%] {jlat:.6f}, {jlng:.6f}")

    try:
        forward = True
        sent = 0
        done = False
        while not done:
            seq = path if forward else list(reversed(path))
            cum = 0.0
            prev = None
            for lat, lng in seq:
                if prev is not None:
                    cum += haversine_m(*prev, lat, lng) / 1000
                publish(lat, lng, cum)
                prev = (lat, lng)
                sent += 1
                if args.max_points and sent >= args.max_points:
                    print(f"[SIM] Đã gửi đủ {args.max_points} điểm (--max-points), dừng.")
                    done = True
                    break
                time.sleep(args.interval)
            if not args.loop:
                done = True
            forward = not forward
            print("[SIM] Đã tới điểm cuối, quay đầu..." if args.loop else "")
    except KeyboardInterrupt:
        print("\n[*] Dừng.")
    finally:
        client.loop_stop()
        client.disconnect()
        print("[*] Hoàn tất.")


if __name__ == "__main__":
    main()
