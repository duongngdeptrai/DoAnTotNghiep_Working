#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>

// ============ PIN CONFIG ============
#define MODEM_RX        27
#define MODEM_TX        26
#define MODEM_RESET_PIN 25
#define LED_PIN         2
#define SOS_BUTTON_PIN  0   // GPIO0 = nút BOOT trên board, active-LOW

// ============ WIFI ============
const char* WIFI_SSID     = "Hust_B1";
const char* WIFI_PASSWORD = "";

// ============ MQTT (EMQX Public Broker — no TLS) ============
const char* MQTT_HOST     = "broker.emqx.io";
const int   MQTT_PORT     = 1883;
const char* MQTT_USER     = "";
const char* MQTT_PASS     = "";
const char* MQTT_TOPIC     = "dotn/duong29/gps/child_01";
const char* MQTT_SOS_TOPIC = "dotn/duong29/sos/child_01";
const char* DEVICE_ID     = "child_01";

// ============ SOS ============
#define SOS_DEBOUNCE_MS   50    // chống nảy nút
#define SOS_COOLDOWN_MS   10000 // tránh gửi liên tục (10 giây)

volatile bool sosPending = false;
unsigned long lastSosTime = 0;

void IRAM_ATTR sosBtnISR() {
  sosPending = true;
}

const unsigned long PUBLISH_INTERVAL_MS = 5000;

WiFiClient   wifiClient;
PubSubClient mqttClient(wifiClient);

// ============ AT HELPERS ============

static void drainSerial() {
  uint32_t t = millis();
  while (Serial2.available() && millis()-t < 200) Serial2.read();
}

static String readUntilDone(uint32_t ms) {
  String buf;
  uint32_t t = millis();
  while (millis()-t < ms) {
    while (Serial2.available()) buf += (char)Serial2.read();
    if (buf.indexOf("OK") >= 0 || buf.indexOf("ERROR") >= 0) break;
    delay(5);
  }
  return buf;
}

static bool sendAT(const char* cmd, const char* expect, uint32_t ms = 3000) {
  drainSerial();
  Serial2.print(cmd); Serial2.print("\r");
  bool ok = readUntilDone(ms).indexOf(expect) >= 0;
  Serial.printf("[AT] %-20s => %s\n", cmd, ok?"OK":"FAIL");
  return ok;
}

static String queryAT(const char* cmd, uint32_t ms = 3000) {
  drainSerial();
  Serial2.print(cmd); Serial2.print("\r");
  return readUntilDone(ms);
}

// ============ GPS ============

static double nmeaToDeg(const String& s) {
  double raw = s.toDouble();
  int deg = (int)(raw / 100);
  return deg + (raw - deg*100.0) / 60.0;
}

static uint32_t gpsToUnix(const String& date, const String& time) {
  if (date.length() < 6 || time.length() < 6) return 0;
  int day   = date.substring(0,2).toInt();
  int month = date.substring(2,4).toInt();
  int year  = 2000 + date.substring(4,6).toInt();
  int hour  = time.substring(0,2).toInt();
  int minute= time.substring(2,4).toInt();
  int sec   = time.substring(4,6).toInt();
  if (day<1||day>31||month<1||month>12||year<2020) return 0;
  static const int dim[] = {31,28,31,30,31,30,31,31,30,31,30,31};
  uint32_t days = 0;
  for (int y=1970;y<year;y++) { bool lp=(y%4==0&&(y%100!=0||y%400==0)); days+=lp?366:365; }
  bool ly=(year%4==0&&(year%100!=0||year%400==0));
  for (int m=1;m<month;m++) { days+=dim[m-1]; if(m==2&&ly) days++; }
  days += day-1;
  return days*86400UL + hour*3600UL + minute*60UL + sec;
}

struct GpsData { double lat=0,lon=0; uint32_t ts=0; bool valid=false; };

static bool readGPS(GpsData& out) {
  String buf = queryAT("AT+CGNSSINFO", 3000);
  int idx = buf.indexOf("+CGNSSINFO:");
  if (idx < 0) { out.valid=false; return false; }
  int end = buf.indexOf('\n', idx);
  String line = (end<0)?buf.substring(idx):buf.substring(idx,end);
  line.trim();
  int start = line.indexOf(": ");
  if (start<0) { out.valid=false; return false; }
  String data = line.substring(start+2); data.trim();
  if (data.startsWith(",")) { out.valid=false; return false; }
  String f[13]; int n=0,pos=0;
  while (n<13) {
    int c=data.indexOf(',',pos);
    if (c<0){f[n++]=data.substring(pos);break;}
    f[n++]=data.substring(pos,c); pos=c+1;
  }
  if (n<10||f[0].toInt()<2||f[4].length()==0){out.valid=false;return false;}
  out.lat=nmeaToDeg(f[4]); if(f[5]=="S") out.lat=-out.lat;
  out.lon=nmeaToDeg(f[6]); if(f[7]=="W") out.lon=-out.lon;
  out.ts=gpsToUnix(f[8],f[9]);
  out.valid=true; return true;
}

// ============ MODEM INIT ============

static void modemReset() {
  Serial.println("[RST] Resetting modem...");
  pinMode(MODEM_RESET_PIN, OUTPUT);
  digitalWrite(MODEM_RESET_PIN, HIGH); delay(50);
  digitalWrite(MODEM_RESET_PIN, LOW);  delay(1000);
  digitalWrite(MODEM_RESET_PIN, HIGH);
  Serial.println("[RST] Waiting 10s...");
  delay(10000);
  drainSerial();
}

static void modemInit() {
  for (int i=0;i<10;i++) { if(sendAT("AT","OK",2000)) break; delay(500); }
  sendAT("ATE0","OK",1000);
  sendAT("AT+CGPS=0","OK",3000); delay(500);
  if (!sendAT("AT+CGPS=1,1","OK",5000)) {
    delay(1000); sendAT("AT+CGPS=1,1","OK",5000);
  }
  Serial.println("[GPS] Enabled, searching satellites...");
}

// ============ WIFI + MQTT ============

static void connectWiFi() {
  if (WiFi.status()==WL_CONNECTED) return;
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  if (strlen(WIFI_PASSWORD) > 0)
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  else
    WiFi.begin(WIFI_SSID);
  while (WiFi.status()!=WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.printf("\n[WiFi] IP: %s\n", WiFi.localIP().toString().c_str());
}

static void connectMQTT() {
  while (!mqttClient.connected()) {
    Serial.println("[MQTT] Connecting...");
    if (mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASS)) {
      Serial.println("[MQTT] Connected to broker.emqx.io");
    } else {
      Serial.printf("[MQTT] Failed rc=%d, retry 3s\n", mqttClient.state());
      delay(3000);
    }
  }
}

// ============ SOS SEND ============

static void blinkSOS() {
  // 3 nháy nhanh xác nhận đã gửi SOS
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH); delay(100);
    digitalWrite(LED_PIN, LOW);  delay(100);
  }
}

static void sendSOS(const GpsData& gps) {
  unsigned long now = millis();
  // Chống nảy và cooldown
  if (now - lastSosTime < SOS_COOLDOWN_MS) {
    Serial.println("[SOS] Cooldown, skipped");
    return;
  }
  lastSosTime = now;

  uint32_t ts = (gps.valid && gps.ts > 0) ? gps.ts : 0;  // 0 = backend dùng giờ server
  char payload[300];
  if (gps.valid) {
    snprintf(payload, sizeof(payload),
      "{\"deviceId\":\"%s\",\"lat\":%.6f,\"lng\":%.6f,"
      "\"timestamp\":%lu,\"sos\":true}",
      DEVICE_ID, gps.lat, gps.lon, (unsigned long)ts);
  } else {
    snprintf(payload, sizeof(payload),
      "{\"deviceId\":\"%s\",\"lat\":0,\"lng\":0,"
      "\"timestamp\":%lu,\"sos\":true,\"noGps\":true}",
      DEVICE_ID, (unsigned long)ts);
  }

  Serial.printf("[SOS] Publishing: %s\n", payload);
  bool ok = mqttClient.publish(MQTT_SOS_TOPIC, payload, /*retain=*/false);
  Serial.printf("[SOS] %s\n", ok ? "SENT" : "FAILED");
  blinkSOS();
}

// ============ SETUP & LOOP ============

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== ESP32 GPS Tracker (WiFi + MQTT) ===");

  Serial2.setRxBufferSize(2048);
  Serial2.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(1000); drainSerial();

  modemReset();
  modemInit();

  connectWiFi();
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setBufferSize(512);
  connectMQTT();

  // Nút SOS: GPIO0, pull-up nội, active-LOW, ngắt cạnh xuống
  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(SOS_BUTTON_PIN), sosBtnISR, FALLING);

  Serial.println("[SYS] Ready! Press BOOT button for SOS.\n");
}

void loop() {
  static unsigned long lastPublish = 0;
  static GpsData cachedGps;         // GPS gần nhất để SOS dùng khi cần

  if (WiFi.status()!=WL_CONNECTED) connectWiFi();
  if (!mqttClient.connected())      connectMQTT();
  mqttClient.loop();

  // Xử lý SOS (ưu tiên cao, không chờ đến chu kỳ publish)
  if (sosPending) {
    sosPending = false;
    delay(SOS_DEBOUNCE_MS);                    // debounce
    if (digitalRead(SOS_BUTTON_PIN) == LOW) {  // vẫn đang nhấn => hợp lệ
      GpsData freshGps;
      if (!readGPS(freshGps)) freshGps = cachedGps;  // dùng GPS cũ nếu chưa có fix
      sendSOS(freshGps);
    }
  }

  if (millis()-lastPublish < PUBLISH_INTERVAL_MS) return;
  lastPublish = millis();

  if (!readGPS(cachedGps)) { Serial.println("[GPS] No fix..."); return; }

  uint32_t ts = (cachedGps.ts > 0) ? cachedGps.ts : (millis()/1000);
  char payload[256];
  snprintf(payload, sizeof(payload),
    "{\"deviceId\":\"%s\",\"lat\":%.6f,\"lng\":%.6f,\"timestamp\":%lu}",
    DEVICE_ID, cachedGps.lat, cachedGps.lon, (unsigned long)ts);

  Serial.printf("[PUB] %s\n", payload);
  mqttClient.publish(MQTT_TOPIC, payload);
  digitalWrite(LED_PIN, HIGH); delay(50); digitalWrite(LED_PIN, LOW);
}
