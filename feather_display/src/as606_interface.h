#ifndef AS606_INTERFACE_H
#define AS606_INTERFACE_H

#include <Adafruit_Fingerprint.h>

// Use Serial1 for AS606 on Feather M4
// Serial1 on Feather M4 maps to D0 (RX) and D1 (TX)
// User connection: Sensor TX -> D0 (MCU RX), Sensor RX -> D1 (MCU TX)
#define FINGERPRINT_BAUD    57600  // AS606 default baud rate

/**
 * AS606 Fingerprint Sensor Interface
 * 
 * Uses Serial1 hardware UART for communication with the AS606 fingerprint sensor.
 * 
 * Usage:
 *   AS606Interface fingerprint;
 *   fingerprint.begin();
 *   fingerprint.getImage();
 *   fingerprint.image2Tz();
 *   uint16_t matchID = fingerprint.fingerSearch();
 */

class AS606Interface {
private:
  Adafruit_Fingerprint *finger;
  bool initialized;

public:
  AS606Interface() : finger(nullptr), initialized(false) {}

  /**
   * Initialize the sensor interface
   * Uses Serial1 hardware UART at 57,600 baud
   * Returns true if sensor responds, false otherwise
   */
  bool begin() {
    Serial.println(F("[AS606] Initializing fingerprint sensor..."));
    
    // Initialize Serial1 for sensor communication
    Serial1.begin(FINGERPRINT_BAUD);
    delay(100);
    
    // Create Adafruit Fingerprint object
    finger = new Adafruit_Fingerprint(&Serial1);
    
    // Wait for sensor to power up
    delay(500);
    
    // Verify password (handshake)
    if (!finger->verifyPassword()) {
      Serial.println(F("[AS606] ERROR: Sensor not found or verification failed!"));
      Serial.println(F("[AS606] Check connections: D0=RX, D1=TX, Power=3.3V"));
      return false;
    }
    
    Serial.println(F("[AS606] Sensor verified successfully!"));
    
    // Get sensor parameters
    finger->getParameters();
    Serial.print(F("[AS606] Status register: 0x"));
    Serial.println(finger->status_reg, HEX);
    Serial.print(F("[AS606] System ID: 0x"));
    Serial.println(finger->system_id, HEX);
    Serial.print(F("[AS606] Capacity: "));
    Serial.println(finger->capacity);
    Serial.print(F("[AS606] Security level: "));
    Serial.println(finger->security_level);
    Serial.print(F("[AS606] Device address: 0x"));
    Serial.println(finger->device_addr, HEX);
    Serial.print(F("[AS606] Packet length: "));
    Serial.println(finger->packet_len);
    Serial.print(F("[AS606] Baud rate: "));
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
      Serial.println(F("[AS606] ERROR: Sensor not initialized!"));
      return FINGERPRINT_NOFINGER;
    }
    
    Serial.println(F("[AS606] Waiting for fingerprint..."));
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
      Serial.println(F("[AS606] ERROR: Sensor not initialized!"));
      return FINGERPRINT_IMAGEFAIL;
    }
    
    Serial.print(F("[AS606] Converting image to template (buffer "));
    Serial.print(slot);
    Serial.println(F(")..."));
    
    return finger->image2Tz(slot);
  }

  /**
   * Search for match in database
   * Returns the ID of the matching fingerprint (0-162)
   * Returns 0 if no match found
   * Confidence score available via getConfidence()
   */
  uint16_t fingerSearch() {
    if (!initialized) {
      Serial.println(F("[AS606] ERROR: Sensor not initialized!"));
      return 0;
    }
    
    Serial.println(F("[AS606] Searching database..."));
    
    uint8_t p = finger->fingerSearch();
    
    if (p == FINGERPRINT_OK) {
      Serial.print(F("[AS606] Match found! ID: "));
      Serial.print(finger->fingerID);
      Serial.print(F(", Confidence: "));
      Serial.println(finger->confidence);
      return finger->fingerID;
    } else if (p == FINGERPRINT_NOTFOUND) {
      Serial.println(F("[AS606] No match found in database."));
      return 0;
    } else {
      Serial.print(F("[AS606] Search error: 0x"));
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
      Serial.println(F("[AS606] ERROR: Sensor not initialized!"));
      return 0;
    }
    
    finger->getTemplateCount();
    
    Serial.print(F("[AS606] Templates in sensor: "));
    Serial.println(finger->templateCount);
    
    return finger->templateCount;
  }

  /**
   * Print last response code to serial with explanation
   */
  void printLastResponseCode() {
    // The Adafruit library stores response codes in finger->p internal state
    // For now, we'll just print a generic message
    Serial.println(F("[AS606] Check serial output above for detailed error information."));
  }

  /**
   * Destructor - cleanup
   */
  ~AS606Interface() {
    if (finger) delete finger;
  }
};

#endif  // AS606_INTERFACE_H
