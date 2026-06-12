import json
import time
import argparse
import ssl
import paho.mqtt.client as mqtt

HIVEMQ_HOST = "45a8c40927a646de8c48e6d9c2d1aed7.s1.eu.hivemq.cloud"
HIVEMQ_PORT = 8883
HIVEMQ_USERNAME = "duong29"
HIVEMQ_PASSWORD = "Duongthcsvt2912"


def simulate_gps(
    broker_host=HIVEMQ_HOST,
    broker_port=HIVEMQ_PORT,
    username=HIVEMQ_USERNAME,
    password=HIVEMQ_PASSWORD,
    device_id="child_01",
    lat=21.0285,
    lng=105.8542,
    move_outside=False,
    interval=5,
):
    """
    Simulate ESP32 GPS by publishing MQTT messages to HiveMQ Cloud.

    Usage:
      python test_mqtt_client.py                          # child_01, inside geofence
      python test_mqtt_client.py --device-id child_02     # child_02, inside geofence
      python test_mqtt_client.py --move-outside           # move outside (trigger alert)
      python test_mqtt_client.py --interval 2             # bắn mỗi 2 giây
    """
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.username_pw_set(username, password)
    client.tls_set(tls_version=ssl.PROTOCOL_TLS_CLIENT)

    connected = False

    def on_connect(client, userdata, flags, reason_code, properties):
        nonlocal connected
        if reason_code == 0:
            connected = True
            print(f"[MQTT] Connected to {broker_host}:{broker_port}")
        else:
            print(f"[MQTT] Connection failed: {reason_code}")

    def on_disconnect(client, userdata, flags, reason_code, properties):
        nonlocal connected
        connected = False
        print(f"[MQTT] Disconnected: {reason_code}")

    def on_publish(client, userdata, mid, reason_code, properties):
        pass  # suppress default output

    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_publish = on_publish

    print(f"[MQTT] Connecting to {broker_host}:{broker_port} ...")
    try:
        client.connect(broker_host, broker_port, keepalive=60)
        client.loop_start()

        # Chờ kết nối thành công
        for _ in range(20):
            if connected:
                break
            time.sleep(0.5)
        else:
            print("[MQTT] Timeout: could not connect. Check credentials / network.")
            return

        print(f"\nDevice    : {device_id}")
        print(f"Position  : lat={lat}, lng={lng}")
        print(f"Interval  : {interval}s")
        print(f"Mode      : {'MOVE OUTSIDE (alert)' if move_outside else 'stay inside geofence'}")
        print(f"Geofence  : center=(21.0285, 105.8542) radius=100m")
        print("-" * 60)
        print("Press Ctrl+C to stop.\n")

        seq = 0
        while True:
            timestamp = int(time.time())

            if move_outside:
                current_lat = 21.0285 + (seq % 10) * 0.005
                current_lng = 105.8542
            else:
                current_lat = lat + (seq % 3) * 0.0001
                current_lng = lng + (seq % 3) * 0.0001

            payload = {
                "deviceId": device_id,
                "lat": round(current_lat, 6),
                "lng": round(current_lng, 6),
                "timestamp": timestamp,
            }

            topic = f"gps/{device_id}"
            result = client.publish(topic, json.dumps(payload))

            distance_from_center = int(seq * 50) if move_outside and seq > 0 else 0
            status = "OUTSIDE" if (move_outside and seq > 2) else "inside "
            ok = "OK" if result.rc == 0 else f"ERR({result.rc})"
            print(f"[{seq:04d}] {status} | lat={current_lat:.6f} lng={current_lng:.6f} +{distance_from_center}m | {ok}")

            seq += 1
            time.sleep(interval)

    except KeyboardInterrupt:
        print("\n[MQTT] Stopped.")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Simulate GPS via HiveMQ MQTT")
    parser.add_argument("--host", default=HIVEMQ_HOST)
    parser.add_argument("--port", type=int, default=HIVEMQ_PORT)
    parser.add_argument("--username", default=HIVEMQ_USERNAME)
    parser.add_argument("--password", default=HIVEMQ_PASSWORD)
    parser.add_argument("--device-id", default="child_01", help="Device ID (vd: child_01, child_02)")
    parser.add_argument("--lat", type=float, default=21.0285)
    parser.add_argument("--lng", type=float, default=105.8542)
    parser.add_argument("--move-outside", action="store_true", help="Di chuyển ra ngoài vùng an toàn")
    parser.add_argument("--interval", type=float, default=5, help="Khoảng cách giữa các lần bắn (giây)")

    args = parser.parse_args()

    simulate_gps(
        broker_host=args.host,
        broker_port=args.port,
        username=args.username,
        password=args.password,
        device_id=args.device_id,
        lat=args.lat,
        lng=args.lng,
        move_outside=args.move_outside,
        interval=args.interval,
    )
