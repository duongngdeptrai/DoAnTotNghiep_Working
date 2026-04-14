import json
import time
import argparse
import paho.mqtt.client as mqtt


def simulate_gps(broker_host="localhost", broker_port=1883, device_id="child_01", lat=21.0285, lng=105.8542, move_outside=False):
    """
    Simulate ESP32 GPS by publishing MQTT messages.
    
    Default geofence center: (21.0285, 105.8542), radius: 100m
    
    Usage:
      python test_mqtt_client.py                                 # Inside geofence
      python test_mqtt_client.py --lat 21.05 --lng 105.90        # Custom start
      python test_mqtt_client.py --move-outside                  # Leave geofence
    """
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    
    def on_connect(client, userdata, flags, reason_code, properties):
        if reason_code == 0:
            print(f"[MQTT] Connected to {broker_host}:{broker_port}")
        else:
            print(f"[MQTT] Connection failed: {reason_code}")
    
    def on_disconnect(client, userdata, flags, reason_code, properties):
        print(f"[MQTT] Disconnected: {reason_code}")
    
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    
    try:
        client.connect(broker_host, broker_port, keepalive=60)
        client.loop_start()
        
        print(f"Starting GPS simulation for device: {device_id}")
        print(f"Broker: {broker_host}:{broker_port}")
        print(f"Initial position: lat={lat}, lng={lng}")
        print()
        print(f"GEOFENCE INFO (from backend config):")
        print(f"  Center: (21.0285, 105.8542)")
        print(f"  Radius: 100m")
        print()
        
        if move_outside:
            print("MODE: Moving OUTSIDE geofence (should trigger alert)")
        else:
            print("MODE: Staying INSIDE geofence (no alert)")
        print()
        print("Publishing messages every 5 seconds. Press Ctrl+C to stop.")
        print("-" * 60)
        
        seq = 0
        while True:
            timestamp = int(time.time())
            
            # Simulate movement
            if move_outside:
                # Move ~500m north from center (21.0285, 105.8542)
                # This will be outside the 100m geofence
                current_lat = 21.0285 + (seq % 10) * 0.005  # ~0.5km per step
                current_lng = 105.8542
            else:
                # Stay within 50m of center
                current_lat = lat + (seq % 3) * 0.0001
                current_lng = lng + (seq % 3) * 0.0001
            
            payload = {
                "deviceId": device_id,
                "lat": round(current_lat, 6),
                "lng": round(current_lng, 6),
                "timestamp": timestamp,
            }
            
            topic = f"gps/{device_id}"
            client.publish(topic, json.dumps(payload))
            
            distance_from_center = 0
            if seq > 0 and move_outside:
                distance_from_center = int(seq * 50)  # ~50m per step
            
            status = "🔴 OUTSIDE (alert!)" if (move_outside and seq > 2) else "🟢 inside"
            print(f"[{seq:04d}] {status} | lat={current_lat:.6f} lng={current_lng:.6f} dis={distance_from_center}m")
            seq += 1
            time.sleep(5)
    
    except KeyboardInterrupt:
        print("\n[MQTT] Stopping...")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Simulate GPS via MQTT")
    parser.add_argument("--host", default="localhost", help="MQTT broker host")
    parser.add_argument("--port", type=int, default=1883, help="MQTT broker port")
    parser.add_argument("--device-id", default="child_01", help="Device ID")
    parser.add_argument("--lat", type=float, default=21.0285, help="Starting latitude")
    parser.add_argument("--lng", type=float, default=105.8542, help="Starting longitude")
    parser.add_argument("--move-outside", action="store_true", help="Simulate movement outside geofence")
    
    args = parser.parse_args()
    
    simulate_gps(
        broker_host=args.host,
        broker_port=args.port,
        device_id=args.device_id,
        lat=args.lat,
        lng=args.lng,
        move_outside=args.move_outside,  
    )
