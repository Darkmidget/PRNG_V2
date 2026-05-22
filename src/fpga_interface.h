#ifndef FPGA_INTERFACE_H
#define FPGA_INTERFACE_H

#include <Arduino.h>
#include "wiring_private.h"

/**
 * FPGA Communication Interface
 *
 * Handles binary bidirectional communication with the FPGA.
 *
 * FPGA protocol (implemented in lfsr_nl_seed_uart.v):
 *   SEND (to FPGA): [byte0, byte1, 0xFF]
 *     - first two payload bytes are used as seed (seed = {byte0, byte1})
 *     - 0xFF terminates the frame
 *
 *   RECEIVE (from FPGA): [rand_low, rand_high]
 *     - 16-bit random value, little-endian on UART TX
 *
 * No fallback behavior: timeout or malformed response returns false.
 */

// Template class to work with any serial-like interface
template<typename SerialType>
class FPGAInterfaceBase {
private:
  SerialType *serialPort;  // Reference to Serial for FPGA communication
  const uint32_t TIMEOUT_MS = 1500;  // Timeout for two-byte FPGA response
  const uint32_t BAUD_RATE = 115200;  // Match the main Serial baud rate

public:
  FPGAInterfaceBase(SerialType &serial) : serialPort(&serial) {}

  /**
   * Send one seed frame to FPGA.
   * Frame format: [seedByte0, seedByte1, 0xFF]
   */
  void sendSeedFrame(uint8_t seedByte0, uint8_t seedByte1) {
    Serial.print(F("[FPGA] TX frame: [0x"));
    if (seedByte0 < 0x10) {
      Serial.print('0');
    }
    Serial.print(seedByte0, HEX);
    Serial.print(F(", 0x"));
    if (seedByte1 < 0x10) {
      Serial.print('0');
    }
    Serial.print(seedByte1, HEX);
    Serial.println(F(", 0xFF]"));

    serialPort->write(seedByte0);
    serialPort->write(seedByte1);
    serialPort->write((uint8_t)0xFF);
    serialPort->flush();
  }

  /**
   * Receive 16-bit random output from FPGA.
   * FPGA sends [lowByte, highByte] over UART.
   */
  bool receiveSeedFromFPGA(uint16_t &seedOut) {
    Serial.println(F("[FPGA] Waiting for 2-byte response..."));

    uint32_t startTime = millis();
    uint8_t rx[2] = {0, 0};
    uint8_t count = 0;

    while ((millis() - startTime) < TIMEOUT_MS && count < 2) {
      if (serialPort->available()) {
        rx[count] = (uint8_t)serialPort->read();
        Serial.print(F("[FPGA] RX byte "));
        Serial.print(count);
        Serial.print(F(": 0x"));
        if (rx[count] < 0x10) Serial.print('0');
        Serial.println(rx[count], HEX);
        count++;
      }
    }

    if (count != 2) {
      Serial.print(F("[FPGA] ERROR: Timeout - received only "));
      Serial.print(count);
      Serial.println(F(" bytes (expected 2)."));
      return false;
    }

    seedOut = (uint16_t)(((uint16_t)rx[1] << 8) | rx[0]);
    Serial.print(F("[FPGA] RX bytes: 0x"));
    if (rx[0] < 0x10) {
      Serial.print('0');
    }
    Serial.print(rx[0], HEX);
    Serial.print(F(", 0x"));
    if (rx[1] < 0x10) {
      Serial.print('0');
    }
    Serial.print(rx[1], HEX);
    Serial.print(F("  => seed 0x"));
    if (seedOut < 0x1000) {
      Serial.print('0');
    }
    Serial.println(seedOut, HEX);

    return true;
  }

  /**
   * Complete seed-byte to random-seed workflow.
   */
  bool processSeedBytes(uint8_t seedByte0, uint8_t seedByte1, uint16_t &seedOut) {
    // Discard stale bytes from previous exchanges.
    while (serialPort->available()) {
      serialPort->read();
    }

    sendSeedFrame(seedByte0, seedByte1);
    if (!receiveSeedFromFPGA(seedOut)) {
      Serial.println(F("[FPGA] Seed exchange FAILED."));
      return false;
    }

    Serial.println(F("[FPGA] Seed exchange OK."));
    return true;
  }

  /**
   * Protocol-aware diagnostic.
   * Sends known two-byte seed and expects two-byte reply.
   */
  bool testConnection() {
    Serial.println(F("[FPGA] Running binary protocol test..."));
    uint16_t outSeed = 0;
    return processSeedBytes(0x42, 0x69, outSeed);
  }
};

// Typedef for Feather M4 hardware UART instances (Serial1/Serial3)
typedef FPGAInterfaceBase<Uart> FPGAInterface;

#endif  // FPGA_INTERFACE_H
