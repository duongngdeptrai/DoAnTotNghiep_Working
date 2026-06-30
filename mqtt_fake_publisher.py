"""
MQTT Fake Data Publisher
Bắn dữ liệu GPS/SOS giả lên broker để test backend.

Dùng:
  python mqtt_fake_publisher.py              # GPS tự động di chuyển
  python mqtt_fake_publisher.py --sos        # Bắn 1 tín hiệu SOS rồi thoát
  python mqtt_fake_publisher.py --plain      # Không mã hóa (gửi JSON thuần)
  python mqtt_fake_publisher.py --interval 2 # Gửi mỗi 2 giây
"""

import argparse
import base64
import json
import math
import os
import time

import paho.mqtt.client as mqtt
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

# ─── Cấu hình (lấy từ .env, có thể override bằng biến môi trường) ───────────
BROKER   = os.getenv("MQTT_HOST",           "broker.emqx.io")
PORT     = int(os.getenv("MQTT_PORT",       "1883"))
GPS_TOPIC  = os.getenv("MQTT_TOPIC",        "dotn/duong29/gps/child_01")
SOS_TOPIC  = os.getenv("MQTT_SOS_TOPIC",   "dotn/duong29/sos/child_01")
ENC_KEY  = os.getenv("MQTT_ENCRYPTION_KEY", "a35f8c2d71b94e06c81a3f90d25b7e44")
DEVICE_ID = os.getenv("DEFAULT_DEVICE_ID",  "child_01")

# ─── Tọa độ gốc: cổng chính HUST ────────────────────────────────────────────
BASE_LAT = 21.0285
BASE_LNG = 105.8542


def encrypt_payload(data: dict, key_hex: str) -> bytes:
    """AES-128 CBC: base64(IV[16] || ciphertext) — khớp với crypto.py của backend."""
    key = bytes.fromhex(key_hex)
    iv = os.urandom(16)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    plaintext = json.dumps(data).encode()
    ciphertext = cipher.encrypt(pad(plaintext, AES.block_size))
    return base64.b64encode(iv + ciphertext)


def build_gps_payload(step: int) -> dict:
    """Mô phỏng trẻ đi vòng tròn quanh điểm gốc, bán kính ~80m."""
    angle = (step * 15) % 360  # mỗi bước quay 15 độ
    rad = math.radians(angle)
    radius_deg = 80 / 111_320  # ~80 mét tính ra độ
    return {
        "deviceId": DEVICE_ID,
        "lat": round(BASE_LAT + radius_deg * math.cos(rad), 6),
        "lng": round(BASE_LNG + radius_deg * math.sin(rad), 6),
        "timestamp": int(time.time()),
    }


def build_sos_payload(no_gps: bool = False) -> dict:
    return {
        "deviceId": DEVICE_ID,
        "lat": BASE_LAT,
        "lng": BASE_LNG,
        "timestamp": int(time.time()),
        "noGps": no_gps,
    }


def main():
    parser = argparse.ArgumentParser(description="Fake MQTT publisher cho hệ thống theo dõi trẻ em")
    parser.add_argument("--sos",      action="store_true", help="Bắn 1 SOS rồi thoát")
    parser.add_argument("--no-gps",  action="store_true", help="Bắn SOS với noGps=True")
    parser.add_argument("--plain",   action="store_true", help="Gửi JSON thuần (không mã hóa)")
    parser.add_argument("--interval",type=float, default=3.0, help="Giây giữa mỗi bản tin GPS (mặc định: 3)")
    parser.add_argument("--count",   type=int,   default=0,   help="Số lần gửi GPS rồi dừng (0 = vô hạn)")
    args = parser.parse_args()

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

    def on_connect(c, userdata, flags, rc, props):
        if rc == 0:
            print(f"[+] Đã kết nối tới {BROKER}:{PORT}")
        else:
            print(f"[-] Kết nối thất bại, mã lỗi: {rc}")

    client.on_connect = on_connect
    client.connect(BROKER, PORT, keepalive=60)
    client.loop_start()
    time.sleep(1)  # chờ on_connect chạy xong

    def publish(topic: str, data: dict):
        if args.plain:
            raw = json.dumps(data).encode()
        else:
            raw = encrypt_payload(data, ENC_KEY)
        client.publish(topic, raw)
        mode = "plain" if args.plain else "AES"
        print(f"  [{mode}] → {topic}")
        print(f"         {json.dumps(data)}")

    try:
        if args.sos:
            payload = build_sos_payload(no_gps=args.no_gps)
            print("[SOS] Bắn tín hiệu SOS...")
            publish(SOS_TOPIC, payload)
            time.sleep(0.5)
        else:
            step = 0
            print(f"[GPS] Bắt đầu bắn GPS mỗi {args.interval}s — Ctrl+C để dừng")
            while True:
                payload = build_gps_payload(step)
                publish(GPS_TOPIC, payload)
                step += 1
                if args.count and step >= args.count:
                    break
                time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n[*] Dừng.")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
