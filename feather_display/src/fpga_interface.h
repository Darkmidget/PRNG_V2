#ifndef FPGA_INTERFACE_H
#define FPGA_INTERFACE_H

#include <Arduino.h>
#include "wiring_private.h"

/**
 * FPGA Communication Interface
 * 
 * Handles bidirectional communication with the FPGA:
 * - Sends fingerprint match data (ID and confidence)
 * - Receives random seed value for Game of Life
 * 
 * Protocol:
 *   SEND (to FPGA):     "FP:<id>:<confidence>\n"
 *   RECEIVE (from FPGA): "<seed>\n" (e.g., "42069\n")
 * 
 * The FPGA processes the fingerprint ID/confidence and generates
 * a random seed number to be used as the new Game of Life seed.
 * 
 * Timeout: 10 seconds to receive seed from FPGA
 * No fallback: timeout or invalid response is treated as failure
 */

// Template class to work with any serial-like interface
template<typename SerialType>
class FPGAInterfaceBase {
private:
  SerialType *serialPort;  // Reference to Serial for FPGA communication
  const uint32_t TIMEOUT_MS = 10000;  // 10 second timeout for FPGA response
  const uint32_t BAUD_RATE = 115200;  // Match the main Serial baud rate

public:
  FPGAInterfaceBase(SerialType &serial) : serialPort(&serial) {}

  /**
   * Send fingerprint data to FPGA
   * Format: "FP:<id>:<confidence>\n"
   * 
   * Parameters:
   *   fingerprintID - The enrolled fingerprint ID (0-162)
   *   confidence    - Confidence score from sensor (0-255)
   */
  void sendFingerprintData(uint16_t fingerprintID, uint16_t confidence) {
    Serial.print(F("[FPGA] Sending fingerprint data - ID: "));
    Serial.print(fingerprintID);
    Serial.print(F(", Confidence: "));
    Serial.println(confidence);
    
    // Build message: "FP:42:250\n"
    serialPort->print(F("FP:"));
    serialPort->print(fingerprintID);
    serialPort->print(F(":"));
    serialPort->print(confidence);
    serialPort->println();
    
    serialPort->flush();  // Ensure data is sent immediately
    Serial.println(F("[FPGA] Message sent."));
  }

  /**
   * Wait for seed response from FPGA
   * The FPGA should respond with a seed number followed by newline
   * Format expected: "<seed>\n" (e.g., "12345\n")
   * 
   * Returns:
   *   uint16_t seed value (0-65535)
   *   If timeout or invalid response, returns a generated random value
   */
  uint16_t receiveSeedFromFPGA() {
    Serial.println(F("[FPGA] Waiting for seed response from FPGA..."));
    
    uint32_t startTime = millis();
    uint32_t seedValue = 0;
    bool seedReceived = false;
    char buffer[20];  // Buffer for one full line from FPGA
    uint8_t bufferIndex = 0;
    
    // Clear any stray data in serial buffer
    while (serialPort->available()) {
      serialPort->read();
    }
    
    // Wait for FPGA response with timeout
    while ((millis() - startTime) < TIMEOUT_MS) {
      if (serialPort->available()) {
        char c = serialPort->read();
        
        // End of line: attempt strict parse on complete line.
        if (c == '\n') {
          if (bufferIndex > 0) {
            buffer[bufferIndex] = '\0';  // Null-terminate

            bool numeric = true;
            for (uint8_t i = 0; i < bufferIndex; i++) {
              if (buffer[i] < '0' || buffer[i] > '9') {
                numeric = false;
                break;
              }
            }

            if (numeric) {
              seedValue = (uint16_t)atoi(buffer);
              seedReceived = true;

              Serial.print(F("[FPGA] Seed received: "));
              Serial.println(seedValue);
              break;
            }

            Serial.print(F("[FPGA] Ignoring non-numeric response: "));
            Serial.println(buffer);
            bufferIndex = 0;
          }
        } else if (c != '\r') {
          // Accumulate one full line then validate format at newline.
          if (bufferIndex < (sizeof(buffer) - 1)) {
            buffer[bufferIndex++] = c;
          }
        }
      }
    }
    
    // Handle timeout or parse failure
    if (!seedReceived) {
      Serial.println(F("[FPGA] ERROR: No valid seed response from FPGA within 10 seconds."));
      return false;
    }
    
    seedOut = (uint16_t)seedValue;
    return true;
  }

  /**
  * Full capture-to-seed workflow
  * Sends fingerprint data and waits for a numeric seed response
   * 
   * Parameters:
   *   fingerprintID - The enrolled fingerprint ID
   *   confidence    - Confidence score
   * 
   * Returns:
   *   uint16_t seed for Game of Life
   */
  uint16_t processFingerprint(uint16_t fingerprintID, uint16_t confidence) {
    Serial.println(F("[FPGA] === Starting fingerprint-to-seed workflow ==="));
    
    sendFingerprintData(fingerprintID, confidence);
    
    delay(100);  // Brief pause for FPGA to be ready
    
    uint16_t seed = receiveSeedFromFPGA();
    
    Serial.println(F("[FPGA] === Fingerprint workflow complete ==="));
    
    return seed;
  }

  /**
   * Test connectivity with FPGA
   * Sends a ping message and expects an acknowledgment
   */
  bool testConnection() {
    Serial.println(F("[FPGA] Testing connection..."));
    
    serialPort->println(F("PING"));
    serialPort->flush();
    
    uint32_t startTime = millis();
    while ((millis() - startTime) < 2000) {
      if (serialPort->available()) {
        String response = serialPort->readStringUntil('\n');
        Serial.print(F("[FPGA] Response: "));
        Serial.println(response);
        
        if (response.indexOf(F("PONG")) != -1 || response.indexOf(F("ACK")) != -1) {
          Serial.println(F("[FPGA] Connection test PASSED"));
          return true;
        }
      }
    }
    
    Serial.println(F("[FPGA] Connection test FAILED (timeout)"));
    return false;
  }
};

// Typedef for Feather M4 hardware UART instances (Serial1/Serial3)
typedef FPGAInterfaceBase<Uart> FPGAInterface;

#endif  // FPGA_INTERFACE_H
