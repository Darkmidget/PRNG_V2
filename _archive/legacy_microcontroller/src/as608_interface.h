#ifndef AS608_INTERFACE_H
#define AS608_INTERFACE_H

#include <Adafruit_Fingerprint.h>

// Use Serial1 for AS608 on Feather M4
// Serial1 on Feather M4 maps to D0 (RX) and D1 (TX)
// User connection: Sensor TX -> D0 (MCU RX), Sensor RX -> D1 (MCU TX)
#define FINGERPRINT_BAUD    57600  // AS608 default baud rate

/**
 * AS608 Fingerprint Sensor Interface
 * 
 * Uses Serial1 hardware UART for communication with the AS608 fingerprint sensor.
 * 
 * Usage:
 *   AS608Interface fingerprint;
 *   fingerprint.begin();
 *   fingerprint.getImage();
 *   fingerprint.image2Tz();
 *   uint16_t matchID = fingerprint.fingerSearch();
 */

class AS608Interface {
private:
  Adafruit_Fingerprint *finger;
  bool initialized;

  bool readByteWithTimeout(uint8_t &out, uint16_t timeoutMs) {
    uint32_t start = millis();
    while ((millis() - start) < timeoutMs) {
      if (Serial1.available()) {
        out = (uint8_t)Serial1.read();
        return true;
      }
      delay(1);
    }
    return false;
  }

  bool readPacketHeader(uint8_t &type, uint16_t &length, uint16_t timeoutMs) {
    uint8_t b = 0;

    // Find start code 0xEF01.
    while (true) {
      if (!readByteWithTimeout(b, timeoutMs)) {
        return false;
      }
      if (b == 0xEF) {
        uint8_t b2 = 0;
        if (!readByteWithTimeout(b2, timeoutMs)) {
          return false;
        }
        if (b2 == 0x01) {
          break;
        }
      }
    }

    // Skip 4-byte address.
    for (uint8_t i = 0; i < 4; i++) {
      if (!readByteWithTimeout(b, timeoutMs)) {
        return false;
      }
    }

    if (!readByteWithTimeout(type, timeoutMs)) {
      return false;
    }

    uint8_t lenHi = 0;
    uint8_t lenLo = 0;
    if (!readByteWithTimeout(lenHi, timeoutMs)) {
      return false;
    }
    if (!readByteWithTimeout(lenLo, timeoutMs)) {
      return false;
    }

    length = (uint16_t)(((uint16_t)lenHi << 8) | lenLo);
    return true;
  }

public:
  AS608Interface() : finger(nullptr), initialized(false) {}

  /**
   * Initialize the sensor interface
   * Uses Serial1 hardware UART at 57,600 baud
   * Returns true if sensor responds, false otherwise
   */
  bool begin() {
    Serial.println(F("[AS608] Initializing fingerprint sensor..."));
    
    // Initialize Serial1 for sensor communication
    Serial1.begin(FINGERPRINT_BAUD);
    delay(100);
    
    // Create Adafruit Fingerprint object
    finger = new Adafruit_Fingerprint(&Serial1);
    
    // Wait for sensor to power up
    delay(500);
    
    // Verify password (handshake)
    if (!finger->verifyPassword()) {
      Serial.println(F("[AS608] ERROR: Sensor not found or verification failed!"));
      Serial.println(F("[AS608] Check connections: D0=RX, D1=TX, Power=3.3V"));
      return false;
    }
    
    Serial.println(F("[AS608] Sensor verified successfully!"));
    
    // Get sensor parameters
    finger->getParameters();
    Serial.print(F("[AS608] Status register: 0x"));
    Serial.println(finger->status_reg, HEX);
    Serial.print(F("[AS608] System ID: 0x"));
    Serial.println(finger->system_id, HEX);
    Serial.print(F("[AS608] Capacity: "));
    Serial.println(finger->capacity);
    Serial.print(F("[AS608] Security level: "));
    Serial.println(finger->security_level);
    Serial.print(F("[AS608] Device address: 0x"));
    Serial.println(finger->device_addr, HEX);
    Serial.print(F("[AS608] Packet length: "));
    Serial.println(finger->packet_len);
    Serial.print(F("[AS608] Baud rate: "));
    Serial.println(finger->baud_rate);
    
    // Turn on LED during initialization to confirm sensor is responsive
    finger->LEDcontrol(FINGERPRINT_LED_ON, 0, FINGERPRINT_LED_BLUE);
    delay(500);
    finger->LEDcontrol(FINGERPRINT_LED_OFF, 0, FINGERPRINT_LED_BLUE);
    
    initialized = true;
    return true;
  }

  /**
   * Check if sensor is initialized
   */
  bool isInitialized() const {
    return initialized;
  }

  /**
   * Capture fingerprint image from sensor
   * Returns FINGERPRINT_OK on success
   */
  uint8_t getImage() {
    if (!initialized) {
      Serial.println(F("[AS608] ERROR: Sensor not initialized!"));
      return FINGERPRINT_NOFINGER;
    }
    
    Serial.println(F("[AS608] Waiting for fingerprint..."));
    finger->LEDcontrol(FINGERPRINT_LED_ON, 0, FINGERPRINT_LED_BLUE);
    
    uint8_t p = finger->getImage();
    
    finger->LEDcontrol(FINGERPRINT_LED_OFF, 0, FINGERPRINT_LED_BLUE);
    
    return p;
  }

  /**
   * Convert captured image to template in buffer 1
   * Slot: 1 or 2 (typically use 1 for enrollment, 2 for search)
   * Returns FINGERPRINT_OK on success
   */
  uint8_t image2Tz(uint8_t slot = 1) {
    if (!initialized) {
      Serial.println(F("[AS608] ERROR: Sensor not initialized!"));
      return FINGERPRINT_IMAGEFAIL;
    }
    
    Serial.print(F("[AS608] Converting image to template (buffer "));
    Serial.print(slot);
    Serial.println(F(")..."));
    
    return finger->image2Tz(slot);
  }

  /**
   * Download the generated template from CharBuffer1 and reduce it to 2 seed bytes.
   *
   * The sensor uploads template bytes in multiple data packets. We stream those
   * bytes through a rolling 32-bit hash and then fold to 16 bits.
   *
   * Returns true on success and writes out seedByte0/seedByte1.
   */
  bool deriveSeedBytesFromTemplate(uint8_t &seedByte0, uint8_t &seedByte1) {
    if (!initialized) {
      Serial.println(F("[AS608] ERROR: Sensor not initialized!"));
      return false;
    }

    // Drain stale UART bytes before issuing upload.
    while (Serial1.available()) {
      Serial1.read();
    }

    // Request upload of template in CharBuffer1.
    uint8_t cmdData[] = {FINGERPRINT_UPLOAD, 0x01};
    Adafruit_Fingerprint_Packet cmd(FINGERPRINT_COMMANDPACKET, sizeof(cmdData), cmdData);
    finger->writeStructuredPacket(cmd);

    // First packet must be ACK.
    uint8_t pktType = 0;
    uint16_t pktLen = 0;
    if (!readPacketHeader(pktType, pktLen, 1500)) {
      Serial.println(F("[AS608] ERROR: ACK header timeout."));
      return false;
    }
    if (pktType != FINGERPRINT_ACKPACKET || pktLen < 3) {
      Serial.println(F("[AS608] ERROR: invalid ACK packet."));
      return false;
    }

    uint8_t ackCode = 0;
    if (!readByteWithTimeout(ackCode, 500)) {
      Serial.println(F("[AS608] ERROR: ACK payload timeout."));
      return false;
    }

    // Skip remaining ACK payload/checksum bytes.
    for (uint16_t i = 1; i < pktLen; i++) {
      uint8_t discard = 0;
      if (!readByteWithTimeout(discard, 500)) {
        Serial.println(F("[AS608] ERROR: ACK tail timeout."));
        return false;
      }
    }

    if (ackCode != FINGERPRINT_OK) {
      Serial.print(F("[AS608] ERROR: getModel rejected, code=0x"));
      Serial.println(ackCode, HEX);
      return false;
    }

    uint32_t rollingHash = 0x811C9DC5u;  // FNV-1a offset basis
    uint32_t totalBytes = 0;

    while (true) {
      if (!readPacketHeader(pktType, pktLen, 1500)) {
        Serial.println(F("[AS608] ERROR: template packet header timeout."));
        return false;
      }

      if (pktType != FINGERPRINT_DATAPACKET && pktType != FINGERPRINT_ENDDATAPACKET) {
        Serial.print(F("[AS608] ERROR: unexpected packet type: 0x"));
        Serial.println(pktType, HEX);
        return false;
      }

      if (pktLen < 2) {
        Serial.println(F("[AS608] ERROR: malformed template packet length."));
        return false;
      }

      // Length includes 2 checksum bytes.
      uint16_t payloadLen = (uint16_t)(pktLen - 2);
      uint16_t checksumCalc = (uint16_t)(pktType + (pktLen >> 8) + (pktLen & 0xFF));

      for (uint16_t i = 0; i < payloadLen; i++) {
        uint8_t dataByte = 0;
        if (!readByteWithTimeout(dataByte, 500)) {
          Serial.println(F("[AS608] ERROR: payload timeout."));
          return false;
        }
        checksumCalc = (uint16_t)(checksumCalc + dataByte);
        rollingHash ^= dataByte;
        rollingHash *= 16777619u;
      }

      uint8_t csumHi = 0;
      uint8_t csumLo = 0;
      if (!readByteWithTimeout(csumHi, 500) || !readByteWithTimeout(csumLo, 500)) {
        Serial.println(F("[AS608] ERROR: checksum timeout."));
        return false;
      }
      uint16_t checksumRx = (uint16_t)(((uint16_t)csumHi << 8) | csumLo);
      if (checksumRx != checksumCalc) {
        Serial.println(F("[AS608] ERROR: checksum mismatch in template packet."));
        return false;
      }

      totalBytes += payloadLen;

      if (pktType == FINGERPRINT_ENDDATAPACKET) {
        break;
      }
    }

    if (totalBytes == 0) {
      Serial.println(F("[AS608] ERROR: empty template upload."));
      return false;
    }

    uint16_t folded = (uint16_t)((rollingHash >> 16) ^ (rollingHash & 0xFFFFu));
    seedByte0 = (uint8_t)(folded >> 8);   // Big-endian seed byte0
    seedByte1 = (uint8_t)(folded & 0xFF); // Big-endian seed byte1

    Serial.print(F("[AS608] Template bytes hashed: "));
    Serial.println(totalBytes);
    Serial.print(F("[AS608] Derived FPGA seed bytes: 0x"));
    if (seedByte0 < 0x10) {
      Serial.print('0');
    }
    Serial.print(seedByte0, HEX);
    Serial.print(F(" 0x"));
    if (seedByte1 < 0x10) {
      Serial.print('0');
    }
    Serial.println(seedByte1, HEX);

    return true;
  }

  /**
   * Search for match in database
   * Returns the ID of the matching fingerprint (0-162)
   * Returns 0 if no match found
   * Confidence score available via getConfidence()
   */
  uint16_t fingerSearch() {
    if (!initialized) {
      Serial.println(F("[AS608] ERROR: Sensor not initialized!"));
      return 0;
    }
    
    Serial.println(F("[AS608] Searching database..."));
    
    uint8_t p = finger->fingerSearch();
    
    if (p == FINGERPRINT_OK) {
      Serial.print(F("[AS608] Match found! ID: "));
      Serial.print(finger->fingerID);
      Serial.print(F(", Confidence: "));
      Serial.println(finger->confidence);
      return finger->fingerID;
    } else if (p == FINGERPRINT_NOTFOUND) {
      Serial.println(F("[AS608] No match found in database."));
      return 0;
    } else {
      Serial.print(F("[AS608] Search error: 0x"));
      Serial.println(p, HEX);
      return 0;
    }
  }

  /**
   * Get the ID of the last match
   */
  uint16_t getLastMatchID() const {
    if (!initialized) return 0;
    return finger->fingerID;
  }

  /**
   * Get the confidence score of the last match
   */
  uint16_t getLastConfidence() const {
    if (!initialized) return 0;
    return finger->confidence;
  }

  /**
   * Get template count from sensor
   * Returns number of enrolled fingerprints
   */
  uint16_t getTemplateCount() {
    if (!initialized) {
      Serial.println(F("[AS608] ERROR: Sensor not initialized!"));
      return 0;
    }
    
    finger->getTemplateCount();
    
    Serial.print(F("[AS608] Templates in sensor: "));
    Serial.println(finger->templateCount);
    
    return finger->templateCount;
  }

  /**
   * Print last response code to serial with explanation
   */
  void printLastResponseCode() {
    // The Adafruit library stores response codes in finger->p internal state
    // For now, we'll just print a generic message
    Serial.println(F("[AS608] Check serial output above for detailed error information."));
  }

  /**
   * Destructor - cleanup
   */
  ~AS608Interface() {
    if (finger) delete finger;
  }
};

#endif  // AS608_INTERFACE_H
