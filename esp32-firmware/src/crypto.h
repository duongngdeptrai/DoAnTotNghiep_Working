#pragma once
#include "mbedtls/aes.h"
#include "mbedtls/base64.h"
#include "esp_random.h"
#include <Arduino.h>

// AES-128 key (16 bytes) — phải khớp với MQTT_ENCRYPTION_KEY trong backend .env
static const uint8_t MQTT_AES_KEY[16] = {
    0xA3, 0x5F, 0x8C, 0x2D, 0x71, 0xB9, 0x4E, 0x06,
    0xC8, 0x1A, 0x3F, 0x90, 0xD2, 0x5B, 0x7E, 0x44
};

#define CRYPTO_MAX_PLAIN  320
#define CRYPTO_MAX_CIPHER (16 + CRYPTO_MAX_PLAIN)
#define CRYPTO_MAX_B64    (((CRYPTO_MAX_CIPHER + 2) / 3) * 4 + 1)

// Mã hóa AES-128 CBC với random IV.
// Output format: base64( IV[16 bytes] || ciphertext )
String encryptPayload(const String& plaintext) {
    size_t len = plaintext.length();
    if (len == 0 || len > CRYPTO_MAX_PLAIN - 16) {
        Serial.println("[CRYPTO] Payload too large or empty");
        return "";
    }

    // PKCS7 padding lên bội số 16
    size_t padded_len = ((len / 16) + 1) * 16;
    uint8_t input[CRYPTO_MAX_PLAIN] = {};
    memcpy(input, plaintext.c_str(), len);
    uint8_t pad = (uint8_t)(padded_len - len);
    memset(input + len, pad, pad);

    // Random IV từ hardware RNG của ESP32
    uint8_t iv[16];
    esp_fill_random(iv, sizeof(iv));

    // AES-128 CBC encrypt
    uint8_t ciphertext[CRYPTO_MAX_PLAIN] = {};
    uint8_t iv_work[16];
    memcpy(iv_work, iv, 16);  // CBC sẽ modify iv_work, giữ iv gốc để ghép đầu

    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);
    mbedtls_aes_setkey_enc(&aes, MQTT_AES_KEY, 128);
    mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_ENCRYPT, padded_len, iv_work, input, ciphertext);
    mbedtls_aes_free(&aes);

    // Ghép: IV (16 bytes) || ciphertext
    size_t total = 16 + padded_len;
    uint8_t combined[CRYPTO_MAX_CIPHER] = {};
    memcpy(combined, iv, 16);
    memcpy(combined + 16, ciphertext, padded_len);

    // Base64 encode để gửi qua MQTT
    size_t b64_len = 0;
    uint8_t b64_buf[CRYPTO_MAX_B64] = {};
    mbedtls_base64_encode(b64_buf, sizeof(b64_buf), &b64_len, combined, total);

    return String((char*)b64_buf);
}
