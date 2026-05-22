#ifndef FPGA_SERIAL_H
#define FPGA_SERIAL_H

#include <Arduino.h>
#include "wiring_private.h"  // For pinPeripheral() and Uart class

/**
 * FPGA Serial Communication Interface
 * 
 * ⚠️ HARDWARE CONFIGURATION (Feather M4 + FPGA)
 * =====================================================
 * Serial2 on Feather M4 uses SERCOM1 (PA10/PA11):
 *   - PA10 (D12) = RX (FPGA TX → Board RX)
 *   - PA11 (D13) = TX (FPGA RX ← Board TX)
 * 
 * Wiring Diagram:
 *   FPGA TX (output)   → PA10 (D12) / Board RX
 *   FPGA RX (input)    ← PA11 (D13) / Board TX
 *   FPGA GND           → GND
 *   FPGA 3V3/5V Power  → (as appropriate for your FPGA)
 * 
 * ✅ Default Configuration:
 *   Baud Rate: 115200 (same as USB Serial for simplicity)
 *   Timeout: 10 seconds for FPGA response
 * 
 * 📋 Protocol:
 *   SEND (Fingerprint → FPGA):  "FP:<id>:<confidence>\n"
 *     Example: "FP:5:245\n" (ID=5, Confidence=245)
 *   
 *   RECEIVE (FPGA → Seed):      "<seed>\n"
 *     Example: "42069\n" (seed value)
 */

// Define Serial2 on SERCOM1 (D12/D13) for FPGA communication
// Uart(sercom, rxPin, txPin, rxPad, txPad)
// FPGA TX → D12 (MCU RX), FPGA RX ← D13 (MCU TX)
static Uart Serial2(&sercom1, 12, 13, SERCOM_RX_PAD_3, UART_TX_PAD_0);

// SAMD51 requires IRQ handlers for SERCOM1
void SERCOM1_0_Handler() { Serial2.IrqHandler(); }
void SERCOM1_1_Handler() { Serial2.IrqHandler(); }
void SERCOM1_2_Handler() { Serial2.IrqHandler(); }
void SERCOM1_3_Handler() { Serial2.IrqHandler(); }

class FPGASerial {
private:
  const uint32_t TIMEOUT_MS = 10000;  // 10 second timeout for FPGA response
  const uint32_t BAUD_RATE = 115200;  // Serial2 baud rate (configurable)

public:
  FPGASerial() {}

  /**
   * Initialize Serial2 for FPGA communication
   * Call this in setup() after initializing other serials
   */
  void begin() {
    Serial.println(F("[FPGA] Initializing Serial2 at 115200 baud..."));
    
    // Configure pin mux for D12 (RX) and D13 (TX) to use SERCOM1
    pinPeripheral(12, PIO_SERCOM);   // D12 = PA19 (SERCOM1 RX pad 3)
    pinPeripheral(13, PIO_SERCOM);   // D13 = PA18 (SERCOM1 TX pad 0)
    
    // Initialize SERCOM1 UART
    Serial2.begin(BAUD_RATE);
    delay(500);
    
    Serial.println(F("[FPGA] Serial2 ready for FPGA communication on D12/D13"));
  }

  /**
   * Send fingerprint data to FPGA
   * Format: "FP:<id>:<confidence>\n"
   * 
   * Parameters:
   *   fingerprintID - The enrolled fingerprint ID (1-127 typical)
   *   confidence    - Confidence score from sensor (0-255)
   * 
   * Example: sendFingerprintData(5, 245) sends "FP:5:245\n"
   */
  void sendFingerprintData(uint16_t fingerprintID, uint16_t confidence) {
    Serial.print(F("[FPGA] Sending fingerprint data - ID: "));
    Serial.print(fingerprintID);
    Serial.print(F(", Confidence: "));
    Serial.println(confidence);
    
    // Build message: "FP:<id>:<confidence>\n"
    Serial2.print(F("FP:"));
    Serial2.print(fingerprintID);
    Serial2.print(F(":"));
    Serial2.print(confidence);
    Serial2.println();  // Add newline
    
    Serial2.flush();  // Ensure data is sent immediately
    Serial.println(F("[FPGA] Message sent."));
  }

  /**
   * Wait for seed response from FPGA
   * The FPGA should respond with a seed number followed by newline
   * Format expected: "<seed>\n" (e.g., "12345\n")
   * 
   * Returns:
   *   uint16_t seed value (0-65535)
   *   If timeout or invalid response, returns a locally-generated random seed
   */
  uint16_t receiveSeedFromFPGA() {
    Serial.println(F("[FPGA] Waiting for seed response from FPGA..."));
    
    uint32_t startTime = millis();
    uint32_t seedValue = 0;
    bool seedReceived = false;
    char buffer[20];  // Buffer to hold incoming data
    uint8_t bufferIndex = 0;
    
    // Clear any stray data in serial buffer
    while (Serial2.available()) {
      Serial2.read();
    }
    
    // Wait for FPGA response with timeout
    while ((millis() - startTime) < TIMEOUT_MS) {
      if (Serial2.available()) {
        char c = Serial2.read();
        
        // Look for newline or carriage return
        if (c == '\n' || c == '\r') {
          if (bufferIndex > 0) {
            buffer[bufferIndex] = '\0';  // Null-terminate
            
            // Try to parse the seed value
            seedValue = (uint16_t)atoi(buffer);
            seedReceived = true;
            
            Serial.print(F("[FPGA] Seed received from FPGA: "));
            Serial.println(seedValue);
            return seedValue;
          }
        } else if (c >= '0' && c <= '9') {
          // Accumulate digits
          if (bufferIndex < sizeof(buffer) - 1) {
            buffer[bufferIndex++] = c;
          }
        }
      }
      
      // Yield to other processes
      delay(10);
    }
    
    // Timeout occurred - report failure to the caller
    if (!seedReceived) {
      Serial.println(F("[FPGA] TIMEOUT: Failed to receive valid seed. Halting execution."));
      while (true) { delay(100); } // Halt to prevent running without a valid hardware seed
    }
    
    return seedValue;
  }
};

#endif  // FPGA_SERIAL_H
