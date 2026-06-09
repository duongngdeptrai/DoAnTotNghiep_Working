#include <Arduino.h>

// ================== PIN & UART ==================
#define MODEM_RX 27
#define MODEM_TX 26
#define mySerial Serial2

#define MODEM_RESET_PIN 25
#define LED_PIN 2

#define GPS_INTERVAL_MS 5000

// ================== GPS DATA ==================
struct GpsData {
  float lat      = 0.0f;
  float lon      = 0.0f;
  float altitude = 0.0f;
  float speed    = 0.0f;
  float course   = 0.0f;
  char  date[9]  = {0};
  char  time[11] = {0};
  bool  valid    = false;
};

static GpsData gps;

// =================================================
// Serial Helpers
// =================================================

static void drainSerial()
{
  uint32_t t = millis();
  while (mySerial.available() && millis() - t < 100)
    mySerial.read();
}

static String readUntilOK(uint32_t timeoutMs)
{
  String   buf;
  uint32_t start = millis();
  while (millis() - start < timeoutMs)
  {
    while (mySerial.available())
      buf += (char)mySerial.read();
    if (buf.indexOf("OK") >= 0 || buf.indexOf("ERROR") >= 0)
      break;
    delay(5);
  }
  return buf;
}

static bool sendAT(const char *cmd, const char *expect, uint32_t timeoutMs = 3000)
{
  drainSerial();
  mySerial.print(cmd);
  mySerial.print("\r");
  String resp = readUntilOK(timeoutMs);
  Serial.print("> "); Serial.print(cmd);
  Serial.print("  => "); Serial.println(resp.indexOf(expect) >= 0 ? "OK" : "FAIL");
  return resp.indexOf(expect) >= 0;
}

// =================================================
// GPS
// =================================================

static float nmeaToDeg(const String &nmea)
{
  float raw = nmea.toFloat();
  int   deg = (int)(raw / 100);
  return deg + (raw - deg * 100.0f) / 60.0f;
}

// Parse +CGNSSINFO: mode,gps_sv,glo_sv,bd_sv,lat,N/S,lon,E/W,date,time,alt,speed,course,...
static bool parseCGNSSINFO(const String &line, GpsData &out)
{
  int start = line.indexOf(": ");
  if (start < 0) return false;

  String data = line.substring(start + 2);
  data.trim();
  if (data.startsWith(",")) { out.valid = false; return false; }

  String fields[13];
  int    n = 0, pos = 0;
  while (n < 13)
  {
    int c = data.indexOf(',', pos);
    if (c < 0) { fields[n++] = data.substring(pos); break; }
    fields[n++] = data.substring(pos, c);
    pos = c + 1;
  }
  // mode=fields[0]: 2=2D fix, 3=3D fix; lat=fields[4]
  if (n < 13 || fields[0].toInt() < 2 || fields[4].length() == 0)
  { out.valid = false; return false; }

  out.lat = nmeaToDeg(fields[4]);
  if (fields[5] == "S") out.lat = -out.lat;
  out.lon = nmeaToDeg(fields[6]);
  if (fields[7] == "W") out.lon = -out.lon;
  fields[8].toCharArray(out.date, sizeof(out.date));
  fields[9].toCharArray(out.time, sizeof(out.time));
  out.altitude = fields[10].toFloat();
  out.speed    = fields[11].toFloat();
  out.course   = fields[12].toFloat();
  out.valid    = true;
  return true;
}

static String queryAT(const char *cmd, uint32_t timeoutMs = 2000)
{
  drainSerial();
  mySerial.print(cmd);
  mySerial.print("\r");
  String   buf;
  uint32_t start = millis();
  while (millis() - start < timeoutMs)
  {
    while (mySerial.available()) buf += (char)mySerial.read();
    if (buf.indexOf("OK") >= 0 || buf.indexOf("ERROR") >= 0) break;
    delay(5);
  }
  return buf;
}

static bool readGPS(GpsData &out)
{
  String buf = queryAT("AT+CGNSSINFO", 3000);

  int idx = buf.indexOf("+CGNSSINFO:");
  if (idx < 0) { out.valid = false; return false; }

  int    end  = buf.indexOf('\n', idx);
  String line = (end < 0) ? buf.substring(idx) : buf.substring(idx, end);
  line.trim();
  return parseCGNSSINFO(line, out);
}

// =================================================
// Setup & Loop
// =================================================

void setup()
{
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.begin(115200);
  delay(500);

  mySerial.setRxBufferSize(2048);
  mySerial.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  delay(1000);
  drainSerial();

  Serial.println("\n=== ESP32 GPS — ZenoPCB ===");

  // Reset modem
  pinMode(MODEM_RESET_PIN, OUTPUT);
  digitalWrite(MODEM_RESET_PIN, LOW);  delay(500);
  digitalWrite(MODEM_RESET_PIN, HIGH);
  Serial.println("[RST] Waiting for boot...");
  delay(8000);
  drainSerial();

  // Sync AT
  for (int i = 0; i < 8; i++)
  {
    if (sendAT("AT", "OK", 2000)) break;
    delay(500);
  }

  // Bật GPS
  sendAT("AT+CGPS=1,1", "OK", 5000);
  Serial.println("[GPS] Searching for satellites...\n");
}

void loop()
{
  static uint32_t lastGPS = 0;

  if (millis() - lastGPS < GPS_INTERVAL_MS) return;
  lastGPS = millis();

  if (readGPS(gps))
  {
    Serial.printf("[GPS] Lat: %.6f  Lon: %.6f\n", gps.lat, gps.lon);
    Serial.printf("      Alt: %.1fm  Speed: %.1fkm/h  Course: %.1f\n",
                  gps.altitude, gps.speed, gps.course);
    Serial.printf("      Date: %s  Time: %s\n\n", gps.date, gps.time);

    digitalWrite(LED_PIN, HIGH); delay(50); digitalWrite(LED_PIN, LOW);
  }
  else
  {
    Serial.println("[GPS] No fix...");
  }
}
