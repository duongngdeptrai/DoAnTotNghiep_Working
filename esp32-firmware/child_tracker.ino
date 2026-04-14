#include <WiFi.h>
#include <PubSubClient.h>
#include <TinyGPS++.h>

// GPS module wiring (ESP32 UART2)
static const int GPS_RX_PIN = 16;
static const int GPS_TX_PIN = 17;
static const uint32_t GPS_BAUD = 9600;

// Wi-Fi and MQTT settings
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* MQTT_HOST = "192.168.1.10";
const int MQTT_PORT = 1883;
const char* MQTT_USERNAME = "";
const char* MQTT_PASSWORD = "";
const char* MQTT_TOPIC = "gps/child_01";
const char* DEVICE_ID = "child_01";

unsigned long lastPublishMs = 0;
const unsigned long PUBLISH_INTERVAL_MS = 5000;

HardwareSerial gpsSerial(2);
TinyGPSPlus gps;
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

void connectMQTT() {
  if (mqttClient.connected()) {
    return;
  }

  while (!mqttClient.connected()) {
    bool connected;

    if (strlen(MQTT_USERNAME) > 0) {
      connected = mqttClient.connect(DEVICE_ID, MQTT_USERNAME, MQTT_PASSWORD);
    } else {
      connected = mqttClient.connect(DEVICE_ID);
    }

    if (!connected) {
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  connectWiFi();

  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  connectMQTT();
}

void loop() {
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (!mqttClient.connected()) {
    connectMQTT();
  }

  mqttClient.loop();

  if (millis() - lastPublishMs < PUBLISH_INTERVAL_MS) {
    return;
  }

  lastPublishMs = millis();

  if (!gps.location.isValid()) {
    return;
  }

  float lat = gps.location.lat();
  float lng = gps.location.lng();

  // If GPS UTC date/time is valid, convert it in your backend if needed.
  // Here we use uptime seconds as fallback timestamp to keep payload always available.
  unsigned long timestamp = millis() / 1000;

  char payload[200];
  snprintf(
    payload,
    sizeof(payload),
    "{\"deviceId\":\"%s\",\"lat\":%.6f,\"lng\":%.6f,\"timestamp\":%lu}",
    DEVICE_ID,
    lat,
    lng,
    timestamp
  );

  mqttClient.publish(MQTT_TOPIC, payload);
}
