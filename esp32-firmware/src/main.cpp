#define TINY_GSM_MODEM_SIM7600
#define TINY_GSM_RX_BUFFER 1024

#include <Arduino.h>
#include <TinyGsmClient.h>
#include <PubSubClient.h>

// ============ PIN CONFIG ============
#define MODEM_RX        27
#define MODEM_TX        26
#define MODEM_RESET_PIN 25
#define LED_PIN         2
#define SOS_BUTTON_PIN  0   // GPIO0 = nút BOOT, active-LOW

// ============ APN (Viettel) ============
const char* APN      = "v-internet";
const char* APN_USER = "";
const char* APN_PASS = "";

// ============ MQTT ============
const char* MQTT_HOST      = "broker.emqx.io";
const int   MQTT_PORT      = 1883;
const char* MQTT_USER      = "";
const char* MQTT_PASS      = "";
const char* MQTT_TOPIC     = "dotn/duong29/gps/child_01";
const char* MQTT_SOS_TOPIC = "dotn/duong29/sos/child_01";
const char* DEVICE_ID      = "child_01";

// ============ TIMING ============
const unsigned long PUBLISH_INTERVAL_MS = 5000;
#define SOS_DEBOUNCE_MS  50
#define SOS_COOLDOWN_MS  10000

// ============ OBJECTS ============
TinyGsm       modem(Serial2);
TinyGsmClient gsmClient(modem);
PubSubClient  mqttClient(gsmClient);

// ============ SOS ============
volatile bool sosPending  = false;
unsigned long lastSosTime = 0;

void IRAM_ATTR sosBtnISR() { sosPending = true; }

// ============ MODEM ============

void modemReset() {
  Serial.println("[RST] Resetting modem...");
  pinMode(MODEM_RESET_PIN, OUTPUT);
  digitalWrite(MODEM_RESET_PIN, HIGH); delay(50);
  digitalWrite(MODEM_RESET_PIN, LOW);  delay(1000);
  digitalWrite(MODEM_RESET_PIN, HIGH);
  delay(8000);
  Serial.println("[RST] Done");
}

void modemInit() {
  Serial.println("[MODEM] Initializing...");
  modem.restart();
  Serial.println("[MODEM] " + modem.getModemInfo());

  modem.enableGPS();
  Serial.println("[GPS] Enabled, searching satellites...");
}

// ============ GPRS ============

void connectGPRS() {
  if (modem.isGprsConnected()) return;
  Serial.printf("[GPRS] Connecting APN: %s\n", APN);
  while (!modem.gprsConnect(APN, APN_USER, APN_PASS)) {
    Serial.println("[GPRS] Failed, retry 5s...");
    delay(5000);
  }
  Serial.println("[GPRS] Connected — IP: " + modem.localIP().toString());
}

// ============ MQTT ============

void connectMQTT() {
  while (!mqttClient.connected()) {
    if (!modem.isGprsConnected()) connectGPRS();
    Serial.println("[MQTT] Connecting...");
    if (mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASS)) {
      Serial.println("[MQTT] Connected to broker.emqx.io");
    } else {
      Serial.printf("[MQTT] Failed rc=%d, retry 3s\n", mqttClient.state());
      delay(3000);
    }
  }
}

// ============ GPS ============

struct GpsData { double lat=0, lon=0; uint32_t ts=0; bool valid=false; };

bool readGPS(GpsData& out) {
  float lat, lon, speed, alt, accuracy;
  int   vsat, usat, year, month, day, hour, minute, second;

  if (!modem.getGPS(&lat, &lon, &speed, &alt, &vsat, &usat, &accuracy,
                    &year, &month, &day, &hour, &minute, &second)) {
    out.valid = false;
    return false;
  }

  out.lat   = lat;
  out.lon   = lon;
  out.valid = true;

  if (year > 2020) {
    struct tm t = {};
    t.tm_year = year - 1900;
    t.tm_mon  = month - 1;
    t.tm_mday = day;
    t.tm_hour = hour;
    t.tm_min  = minute;
    t.tm_sec  = second;
    out.ts = (uint32_t)mktime(&t);
  }
  return true;
}

// ============ SOS ============

void blinkSOS() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH); delay(100);
    digitalWrite(LED_PIN, LOW);  delay(100);
  }
}

void sendSOS(const GpsData& gps) {
  unsigned long now = millis();
  if (now - lastSosTime < SOS_COOLDOWN_MS) {
    Serial.println("[SOS] Cooldown, skipped");
    return;
  }
  lastSosTime = now;

  char payload[300];
  if (gps.valid) {
    snprintf(payload, sizeof(payload),
      "{\"deviceId\":\"%s\",\"lat\":%.6f,\"lng\":%.6f,"
      "\"timestamp\":%lu,\"sos\":true}",
      DEVICE_ID, gps.lat, gps.lon, (unsigned long)gps.ts);
  } else {
    snprintf(payload, sizeof(payload),
      "{\"deviceId\":\"%s\",\"lat\":0,\"lng\":0,"
      "\"timestamp\":0,\"sos\":true,\"noGps\":true}",
      DEVICE_ID);
  }

  Serial.printf("[SOS] %s\n", payload);
  bool ok = mqttClient.publish(MQTT_SOS_TOPIC, payload, false);
  Serial.printf("[SOS] %s\n", ok ? "SENT" : "FAILED");
  blinkSOS();
}

// ============ SETUP ============

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== ESP32 GPS Tracker (SIM7000G 4G) ===");

  Serial2.setRxBufferSize(2048);
  Serial2.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(1000);

  modemReset();
  modemInit();
  connectGPRS();

  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setBufferSize(512);
  connectMQTT();

  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(SOS_BUTTON_PIN), sosBtnISR, FALLING);

  Serial.println("[SYS] Ready! Press BOOT for SOS.\n");
}

// ============ LOOP ============

void loop() {
  static unsigned long lastPublish = 0;
  static GpsData       cachedGps;

  if (!mqttClient.connected()) connectMQTT();
  mqttClient.loop();

  // Xử lý SOS
  if (sosPending) {
    sosPending = false;
    delay(SOS_DEBOUNCE_MS);
    if (digitalRead(SOS_BUTTON_PIN) == LOW) {
      GpsData freshGps;
      if (!readGPS(freshGps)) freshGps = cachedGps;
      sendSOS(freshGps);
    }
  }

  if (millis() - lastPublish < PUBLISH_INTERVAL_MS) return;
  lastPublish = millis();

  if (!readGPS(cachedGps)) {
    Serial.println("[GPS] No fix...");
    return;
  }

  char payload[256];
  snprintf(payload, sizeof(payload),
    "{\"deviceId\":\"%s\",\"lat\":%.6f,\"lng\":%.6f,\"timestamp\":%lu}",
    DEVICE_ID, cachedGps.lat, cachedGps.lon, (unsigned long)cachedGps.ts);

  Serial.printf("[PUB] %s\n", payload);
  mqttClient.publish(MQTT_TOPIC, payload);
  digitalWrite(LED_PIN, HIGH); delay(50); digitalWrite(LED_PIN, LOW);
}
