#include <Arduino.h>
#include "esp_timer.h"
#include "esp_system.h"

// ================== PIN & UART ==================
#define MODEM_RX 27
#define MODEM_TX 26
#define mySerial Serial2

#define MODEM_RESET_PIN 25
#define LED_PIN 2

// =============== CẤU HÌNH ===============
#define TARGET_PHONE "0338739614"  // Số điện thoại đích
#define SMS_MESSAGE "TEST ESP32 By ZenoPCB"  // Nội dung SMS
#define INTERVAL_SEC 15  // Khoảng thời gian giữa các lần gửi (60 giây = 1 phút)
#define CALL_DURATION_SEC 10  // Thời gian gọi 10s tự tắt máy, Nếu bắt máy 10s cũng tự tắt

// =============== TIMEOUT ===============
#define AT_TIMEOUT_MS 3000
#define AT_RETRIES 3

static int64_t BOOT_US = 0;

// =================================================
// Helper Functions
// =================================================

static String readResponseUntil(uint32_t timeoutMs, bool echoToSerial = false)
{
  String resp;
  resp.reserve(512);
  uint32_t start = millis();

  while (millis() - start < timeoutMs)
  {
    if (mySerial.available())
    {
      char c = (char)mySerial.read();

      if (c < 0x20 && c != '\r' && c != '\n')
        continue;

      resp += c;

      if (resp.length() > 1024)
        resp.remove(0, 256);

      if (echoToSerial)
        Serial.write(c);
    }

    if (resp.indexOf("OK") >= 0 || resp.indexOf("ERROR") >= 0 ||
        resp.indexOf("+CME ERROR") >= 0)
      break;

    delay(5);
    yield();
  }
  return resp;
}

static void drainSerial(uint16_t maxBytes = 256)
{
  uint16_t drained = 0;
  uint32_t startTime = millis();

  while (mySerial.available() > 0 && drained < maxBytes &&
         (millis() - startTime < 100))
  {
    mySerial.read();
    drained++;
    if (drained % 32 == 0)
      yield();
  }
}

static bool sendAT(const String &cmd, const String &expect = "OK",
                   uint32_t timeoutMs = AT_TIMEOUT_MS, int retries = AT_RETRIES)
{
  for (int i = 0; i < retries; i++)
  {
    drainSerial(512);
    Serial.print("> ");
    Serial.println(cmd);

    mySerial.print(cmd);
    mySerial.print("\r");

    String resp = readResponseUntil(timeoutMs, true);

    if (resp.indexOf(expect) >= 0)
      return true;

    if (resp.indexOf("ERROR") >= 0 || resp.indexOf("+CME ERROR") >= 0)
    {
      Serial.println("[WARN] AT ERROR - retry");
      delay(200);
    }
    delay(200);
  }

  Serial.println("[ERR] sendAT failed");
  return false;
}

// =================================================
// Modem Reset & Init
// =================================================

static void modemHardwareReset()
{
  pinMode(MODEM_RESET_PIN, OUTPUT);
  digitalWrite(MODEM_RESET_PIN, HIGH);
  delay(50);

  Serial.println("[RST] Resetting modem...");
  digitalWrite(MODEM_RESET_PIN, LOW);
  delay(1000);
  digitalWrite(MODEM_RESET_PIN, HIGH);

  Serial.println("[RST] Waiting for boot...");
  delay(10000);
  drainSerial(512);
}

static void modemInit()
{
  Serial.println("[INIT] Initializing modem...");

  // Sync AT
  for (int i = 0; i < 8; i++)
  {
    if (sendAT("AT", "OK", 2000, 1))
      break;
    delay(300);
  }

  // Basic config
  sendAT("ATE1", "OK", 2000, 1);  // Echo ON để debug
  sendAT("AT+CMEE=2", "OK", 2000, 1);  // Verbose errors

  // SMS config
  sendAT("AT+CMGF=1", "OK", 2000, 1);  // Text mode
  sendAT("AT+CSCS=\"GSM\"", "OK", 2000, 1);  // Character set

  // Call config
  sendAT("AT+CLIP=1", "OK", 2000, 1);
  sendAT("AT+CRC=1", "OK", 2000, 1);

  // Network
  sendAT("AT+CNMP=2", "OK", 2000, 1);  // GSM only

  Serial.println("[INIT] Modem ready");

  // Check signal
  sendAT("AT+CSQ", "OK", 2000, 1);
}

// =================================================
// Check Ready Status
// =================================================

static bool checkReady()
{
  // Check AT
  if (!sendAT("AT", "OK", 2000, 1))
  {
    Serial.println("[CHECK] AT failed");
    return false;
  }

  // Check SIM
  mySerial.print("AT+CPIN?\r");
  String resp = readResponseUntil(2000, false);
  if (resp.indexOf("READY") < 0)
  {
    Serial.println("[CHECK] SIM not ready");
    return false;
  }

  // Check registration
  mySerial.print("AT+CREG?\r");
  resp = readResponseUntil(2000, false);
  if (resp.indexOf(",1") < 0 && resp.indexOf(",5") < 0)
  {
    Serial.println("[CHECK] Not registered");
    return false;
  }

  // Check signal
  mySerial.print("AT+CSQ\r");
  resp = readResponseUntil(2000, false);
  int csqPos = resp.indexOf("+CSQ:");
  if (csqPos >= 0)
  {
    int comma = resp.indexOf(',', csqPos);
    String csqStr = resp.substring(csqPos + 5, comma);
    csqStr.trim();
    int csq = csqStr.toInt();

    if (csq == 99 || csq < 5)
    {
      Serial.println("[CHECK] Weak signal");
      return false;
    }

    Serial.print("[CHECK] Signal: ");
    Serial.println(csq);
  }

  return true;
}

// =================================================
// Send SMS
// =================================================

static bool sendSMS(const char* phoneNumber, const char* message)
{
  Serial.println("\n[SMS] Sending SMS...");
  Serial.print("[SMS] To: ");
  Serial.println(phoneNumber);
  Serial.print("[SMS] Message: ");
  Serial.println(message);

  // Set SMS format to text mode
  if (!sendAT("AT+CMGF=1", "OK", 2000, 1))
  {
    Serial.println("[SMS] Failed to set text mode");
    return false;
  }

  // Set phone number
  String cmd = "AT+CMGS=\"";
  cmd += phoneNumber;
  cmd += "\"";

  drainSerial(512);
  mySerial.print(cmd);
  mySerial.print("\r");

  delay(500);

  // Wait for prompt '>'
  String resp = readResponseUntil(3000, true);
  if (resp.indexOf(">") < 0)
  {
    Serial.println("[SMS] No prompt received");
    return false;
  }

  // Send message
  mySerial.print(message);
  delay(100);
  mySerial.write(0x1A);  // Ctrl+Z to send

  // Wait for response
  resp = readResponseUntil(10000, true);

  if (resp.indexOf("OK") >= 0 || resp.indexOf("+CMGS:") >= 0)
  {
    Serial.println("[SMS] SMS sent successfully ✓");
    return true;
  }
  else
  {
    Serial.println("[SMS] Failed to send SMS ✗");
    return false;
  }
}

// =================================================
// Make Call
// =================================================

static bool makeCall(const char* phoneNumber, uint16_t durationSec)
{
  Serial.println("\n[CALL] Making call...");
  Serial.print("[CALL] To: ");
  Serial.println(phoneNumber);

  // Dial
  String cmd = "ATD";
  cmd += phoneNumber;
  cmd += ";";

  drainSerial(512);
  Serial.print("> ");
  Serial.println(cmd);
  mySerial.print(cmd);
  mySerial.print("\r");

  digitalWrite(LED_PIN, HIGH);

  // Wait for call to establish
  bool connected = false;
  uint32_t startTime = millis();

  while (millis() - startTime < 30000)  // 30s timeout
  {
    if (mySerial.available())
    {
      String line = mySerial.readStringUntil('\n');
      Serial.println(line);

      if (line.indexOf("OK") >= 0 ||
          line.indexOf("CONNECT") >= 0 ||
          line.indexOf("VOICE CALL: BEGIN") >= 0)
      {
        connected = true;
        Serial.println("[CALL] Call connected ✓");
        break;
      }

      if (line.indexOf("BUSY") >= 0 ||
          line.indexOf("NO CARRIER") >= 0 ||
          line.indexOf("NO ANSWER") >= 0)
      {
        Serial.println("[CALL] Call failed");
        digitalWrite(LED_PIN, LOW);
        return false;
      }
    }
    delay(10);
    yield();
  }

  if (!connected)
  {
    Serial.println("[CALL] Call timeout");
    sendAT("ATH", "OK", 2000, 1);
    digitalWrite(LED_PIN, LOW);
    return false;
  }

  // Hold call for specified duration
  Serial.print("[CALL] Holding call for ");
  Serial.print(durationSec);
  Serial.println(" seconds...");

  startTime = millis();
  while (millis() - startTime < durationSec * 1000UL)
  {
    // Drain any incoming data
    while (mySerial.available())
    {
      Serial.write(mySerial.read());
    }
    delay(100);
    yield();
  }

  // Hang up
  Serial.println("[CALL] Hanging up...");
  sendAT("ATH", "OK", 2000, 1);
  sendAT("AT+CHUP", "OK", 2000, 1);

  digitalWrite(LED_PIN, LOW);
  Serial.println("[CALL] Call ended ✓");

  return true;
}

// =================================================
// Setup & Loop
// =================================================

void setup()
{
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  pinMode(MODEM_RX, INPUT_PULLUP);

  Serial.begin(115200);
  delay(500);

  mySerial.setRxBufferSize(4096);
  mySerial.begin(115200, SERIAL_8N1, MODEM_RX, MODEM_TX);
  mySerial.setTimeout(500);
  delay(1000);

  while (mySerial.available())
    mySerial.read();

  Serial.println("\n\n========================================");
  Serial.println("ESP32 SMS & Call System");
  Serial.println("========================================");
  Serial.print("Target: ");
  Serial.println(TARGET_PHONE);
  Serial.print("Interval: ");
  Serial.print(INTERVAL_SEC);
  Serial.println(" seconds");
  Serial.println("========================================\n");

  modemHardwareReset();
  modemInit();

  BOOT_US = esp_timer_get_time();

  Serial.println("[SYS] Setup complete!\n");
}

void loop()
{
  static uint32_t lastAction = 0;

  // Wait for interval
  if (millis() - lastAction < INTERVAL_SEC * 1000UL)
  {
    delay(100);
    yield();
    return;
  }

  Serial.println("\n========================================");
  Serial.print("[SYS] Time: ");
  Serial.print(millis() / 1000);
  Serial.println(" seconds");
  Serial.println("========================================");

  // Check if ready
  if (!checkReady())
  {
    Serial.println("[SYS] Modem not ready, waiting...");
    delay(5000);
    return;
  }

  // Send SMS
  //sendSMS(TARGET_PHONE, SMS_MESSAGE);
  //delay(2000);

  // Make call
  makeCall(TARGET_PHONE, CALL_DURATION_SEC);
  delay(2000);

  lastAction = millis();

  Serial.println("\n[SYS] Waiting for next cycle...\n");
}
