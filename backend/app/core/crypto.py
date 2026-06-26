import base64
import json
import logging

from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad

logger = logging.getLogger(__name__)


def decrypt_mqtt_payload(raw_bytes: bytes, key_hex: str) -> dict:
    """Giải mã AES-128 CBC payload từ ESP32.
    Format: base64( IV[16 bytes] || ciphertext )
    """
    key = bytes.fromhex(key_hex)
    data = base64.b64decode(raw_bytes)
    iv = data[:16]
    ciphertext = data[16:]
    cipher = AES.new(key, AES.MODE_CBC, iv)
    plaintext = unpad(cipher.decrypt(ciphertext), AES.block_size)
    return json.loads(plaintext.decode())
