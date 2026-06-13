#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>

// ============ PIN CONFIG (iMaker ESP32 SIM7600CE-M1S) ============
#define MODEM_RX        27
#define MODEM_TX        26
#define MODEM_RESET_PIN 25
#define LED_PIN         2
#define mySerial        Serial2

// ============ WIFI ============
const char* WIFI_SSID     = "Viettel_Minh Dong";
const char* WIFI_PASSWORD = "29122004";

// ============ MQTT (HiveMQ Cloud — TLS 8883) ============
const char* MQTT_HOST     = "45a8c40927a646de8c48e6d9c2d1aed7.s1.eu.hivemq.cloud";
const int   MQTT_PORT     = 8883;
const char* MQTT_USERNAME = "duong29";
const char* MQTT_PASSWORD = "Duongthcsvt2912";
const char* MQTT_TOPIC    = "gps/child_01";
const char* DEVICE_ID     = "child_01";

const unsigned long PUBLISH_INTERVAL_MS = 5000;

WiFiClientSecure secureClient;
PubSubClient     mqttClient(secureClient);

// ============ GPS DATA ============
struct GpsData {
  double   lat      = 0.0;
  double   lon      = 0.0;
  uint32_t unixTime = 0;
  bool     valid    = false;
};

// ============ AT HELPERS ============

static void drainSerial() {
  uint32_t t = millis();
  while (mySerial.available() && millis() - t < 100)
    mySerial.read();
}

static String readUntilDone(uint32_t timeoutMs) {
  String   buf;
  uint32_t start = millis();
  while (millis() - start < timeoutMs) {
    while (mySerial.available())
      buf += (char)mySerial.read();
    if (buf.indexOf("OK") >= 0 || buf.indexOf("ERROR") >= 0)
      break;
    delay(5);
  }
  return buf;
}

static bool sendAT(const char* cmd, const char* expect, uint32_t timeoutMs = 3000) {
  drainSerial();
  mySerial.print(cmd);
  mySerial.print("\r");
  String resp = readUntilDone(timeoutMs);
  bool   ok   = resp.indexOf(expect) >= 0;
  Serial.printf("[AT] %-20s => %s\n", cmd, ok ? "OK" : "FAIL");
  return ok;
}

static String queryAT(const char* cmd, uint32_t timeoutMs = 3000) {
  drainSerial();
  mySerial.print(cmd);
  mySerial.print("\r");
  String   buf;
  uint32_t start = millis();
  while (millis() - start < timeoutMs) {
    while (mySerial.available()) buf += (char)mySerial.read();
    if (buf.indexOf("OK") >= 0 || buf.indexOf("ERROR") >= 0) break;
    delay(5);
  }
  return buf;
}

// ============ GPS PARSE ============

static double nmeaToDeg(const String& nmea) {
  double raw = nmea.toDouble();
  int    deg = (int)(raw / 100);
  return deg + (raw - deg * 100.0) / 60.0;
}

// Tính Unix epoch UTC từ date DDMMYY và time HHMMSS.S của GPS
static uint32_t gpsToUnixTime(const String& dateStr, const String& timeStr) {
  if (dateStr.length() < 6 || timeStr.length() < 6) return 0;

  int day   = dateStr.substring(0, 2).toInt();
  int month = dateStr.substring(2, 4).toInt();
  int year  = 2000 + dateStr.substring(4, 6).toInt();
  int hour  = timeStr.substring(0, 2).toInt();
  int min   = timeStr.substring(2, 4).toInt();
  int sec   = timeStr.substring(4, 6).toInt();

  if (day < 1 || day > 31 || month < 1 || month > 12 || year < 2020) return 0;

  static const int days_in_month[] = {31,28,31,30,31,30,31,31,30,31,30,31};
  uint32_t days = 0;
  for (int y = 1970; y < year; y++) {
    bool leap = (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0));
    days += leap ? 366 : 365;
  }
  bool leap_year = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
  for (int m = 1; m < month; m++) {
    days += days_in_month[m - 1];
    if (m == 2 && leap_year) days++;
  }
  days += day - 1;

  return days * 86400UL + hour * 3600UL + min * 60UL + sec;
}

// Parse +CGNSSINFO: mode,gps_sv,glo_sv,bd_sv,lat,N/S,lon,E/W,date,time,alt,speed,course,...
static bool readGPS(GpsData& out) {
  String buf = queryAT("AT+CGNSSINFO", 3000);

  int idx = buf.indexOf("+CGNSSINFO:");
  if (idx < 0) { out.valid = false; return false; }

  int    end  = buf.indexOf('\n', idx);
  String line = (end < 0) ? buf.substring(idx) : buf.substring(idx, end);
  line.trim();

  int start = line.indexOf(": ");
  if (start < 0) { out.valid = false; return false; }

  String data = line.substring(start + 2);
  data.trim();
  if (data.startsWith(",")) { out.valid = false; return false; }

  String fields[13];
  int n = 0, pos = 0;
  while (n < 13) {
    int c = data.indexOf(',', pos);
    if (c < 0) { fields[n++] = data.substring(pos); break; }
    fields[n++] = data.substring(pos, c);
    pos = c + 1;
  }

  if (n < 10 || fields[0].toInt() < 2 || fields[4].length() == 0) {
    out.valid = false;
    return false;
  }

  out.lat = nmeaToDeg(fields[4]);
  if (fields[5] == "S") out.lat = -out.lat;
  out.lon = nmeaToDeg(fields[6]);
  if (fields[7] == "W") out.lon = -out.lon;
  out.unixTime = gpsToUnixTime(fields[8], fields[9]);
  out.valid = true;
  return true;
}

// ============ MODEM INIT ============

static void modemReset() {
  Serial.println("[RST] Resetting modem...");
  pinMode(MODEM_RESET_PIN, OUTPUT);

  // Sequence đúng theo tài liệu board iMaker SIM7600CE-M1S
  digitalWrite(MODEM_RESET_PIN, HIGH);
  delay(50);
  digitalWrite(MODEM_RESET_PIN, LOW);
  delay(1000);
  digitalWrite(MODEM_RESET_PIN, HIGH);

  Serial.println("[RST] Waiting for boot (10s)...");
  delay(10000);
  drainSerial();
}

static void modemInit() {
  Serial.println("[INIT] Syncing AT...");
  for (int i = 0; i < 10; i++) {
    if (sendAT("AT", "OK", 2000)) break;
    delay(500);
  }
  sendAT("ATE0", "OK", 1000);

  // Tắt GPS trước (bỏ qua lỗi nếu chưa bật), rồi bật lại sạch
  sendAT("AT+CGPS=0", "OK", 3000);
  delay(500);
  if (!sendAT("AT+CGPS=1,1", "OK", 5000)) {
    Serial.println("[GPS] CGPS=1,1 failed, retrying...");
    delay(1000);
    sendAT("AT+CGPS=1,1", "OK", 5000);
  }
  Serial.println("[GPS] Enabled, searching satellites...");
}

// ============ WIFI ============

static void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\n[WiFi] Connected, IP: %s\n", WiFi.localIP().toString().c_str());
}

// ============ MQTT ============

static void connectMQTT() {
  while (!mqttClient.connected()) {
    Serial.println("[MQTT] Connecting to HiveMQ Cloud...");
    if (mqttClient.connect(DEVICE_ID, MQTT_USERNAME, MQTT_PASSWORD)) {
      Serial.println("[MQTT] Connected");
    } else {
      Serial.printf("[MQTT] Failed (rc=%d), retry in 3s\n", mqttClient.state());
      delay(3000);
    }
  }
}

// ============ SETUP & LOOP ============

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== ESP32 GPS Tracker (WiFi + MQTT) ===");

  mySerial.setRxBufferSize(2048);
  mySerial.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(1000);
  drainSerial();

  modemReset();
  modemInit();

  connectWiFi();

  secureClient.setInsecure();
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setBufferSize(512);
  connectMQTT();

  Serial.println("[SYS] Ready!\n");
}

void loop() {
  static unsigned long lastPublishMs = 0;

  if (WiFi.status() != WL_CONNECTED) connectWiFi();
  if (!mqttClient.connected())        connectMQTT();
  mqttClient.loop();

  if (millis() - lastPublishMs < PUBLISH_INTERVAL_MS) return;
  lastPublishMs = millis();

  // Tự bật lại GPS nếu module tự tắt sau fix
  String gpsSt = queryAT("AT+CGPS?", 1000);
  if (gpsSt.indexOf("+CGPS: 0") >= 0) {
    Serial.println("[GPS] Auto-disabled detected, re-enabling...");
    sendAT("AT+CGPS=1,1", "OK", 3000);
  }

  GpsData gps;
  if (!readGPS(gps)) {
    Serial.println("[GPS] No fix...");
    return;
  }

  uint32_t ts = (gps.unixTime > 0) ? gps.unixTime : (millis() / 1000);

  char payload[256];
  snprintf(payload, sizeof(payload),
    "{\"deviceId\":\"%s\",\"lat\":%.6f,\"lng\":%.6f,\"timestamp\":%lu}",
    DEVICE_ID, gps.lat, gps.lon, (unsigned long)ts
  );

  Serial.printf("[PUB] %s\n", payload);
  mqttClient.publish(MQTT_TOPIC, payload);

  digitalWrite(LED_PIN, HIGH);
  delay(50);
  digitalWrite(LED_PIN, LOW);
}
