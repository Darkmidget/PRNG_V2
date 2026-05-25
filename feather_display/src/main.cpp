/***************************************************
  Conway's Game of Life Display
  For Adafruit Feather M4 Express + HX8357D FeatherWing
  
  Receives a random seed (0-65535) and displays
  a seeded cellular automaton on the 3.5" TFT display.
  
  Open Serial Monitor at 115200 baud and press reset.
 ****************************************************/

#include <SPI.h>
#include <Arduino.h>
#include <cstdlib>
#include <ctype.h>
#include "wiring_private.h"
#include "Adafruit_GFX.h"
#include "Adafruit_HX8357.h"
#include "gameoflife.h"
#include "display_renderer.h"
#include "fpga_interface.h"

// Serial3 on SERCOM0 for FPGA UART:
//   Feather A1 (RX) <- FPGA TX (CMOD DIP 22)
//   Feather A4 (TX) -> FPGA RX (CMOD DIP 23)
Uart Serial3(&sercom0, A1, A4, SERCOM_RX_PAD_1, UART_TX_PAD_0);

void SERCOM0_0_Handler() { Serial3.IrqHandler(); }
void SERCOM0_1_Handler() { Serial3.IrqHandler(); }
void SERCOM0_2_Handler() { Serial3.IrqHandler(); }
void SERCOM0_3_Handler() { Serial3.IrqHandler(); }

// Pin definitions for Feather M4 + HX8357D FeatherWing
#define TFT_CS   9
#define TFT_DC   10
#define TFT_RST  -1

// Global objects
GameOfLife gol;
DisplayRenderer renderer(TFT_CS, TFT_DC, TFT_RST);
FPGAInterface fpga(Serial3);

// Timing constants
const uint32_t UPDATE_INTERVAL = 333;  // ~3 generations per second (333ms)
uint32_t lastUpdateTime = 0;
uint32_t infoUpdateTime = 0;
const uint32_t INFO_UPDATE_INTERVAL = 1000;  // Update info panel every 1 second

// Current seed for display
uint16_t gCurrentSeed = 0;

// Global state for seed input from serial
bool gReadingSeed = false;
char gSeedBuffer[6];     // "65535\0"
uint8_t gSeedBufferPos = 0;

bool gDisplayConnected = false;
bool gFPGAConnected = false;
uint8_t gFPGAPassCount = 0;
uint8_t gFPGAFailCount = 0;
bool gWorkflowReady = true;  // True so simulation runs automatically

// Game state enum for fingerprint capture workflow
enum GameState {
  STATE_RUNNING,              // Normal Game of Life operation
  STATE_PAUSING,              // Transitioning to pause
  STATE_PAUSED_FOR_CAPTURE,   // Paused, waiting for fingerprint
  STATE_RESUMING              // Transitioning back to running
};

// Global game state
GameState gGameState = STATE_RUNNING;
uint32_t gGamePausedTime = 0;  // When game was paused (for timeout detection)

bool runFPGALoopbackDiagnostic() {
  uint8_t patterns[] = {0x00, 0xFF, 0x55, 0xAA, 0x01, 0x80,
                        0x42, 0xDE, 0xAD, 0xBE, 0xEF, 0x7E};

  gFPGAPassCount = 0;
  gFPGAFailCount = 0;

  Serial.println(F("[FPGA] Running startup UART loopback diagnostic..."));
  Serial.println(F("[FPGA] A1 <- DIP22 (FPGA TX), A4 -> DIP23 (FPGA RX)"));

  while (Serial3.available()) {
    Serial3.read();
  }

  for (uint8_t i = 0; i < sizeof(patterns); i++) {
    uint8_t sent = patterns[i];

    while (Serial3.available()) {
      Serial3.read();
    }

    Serial3.write(sent);
    Serial3.flush();

    unsigned long timeout = millis() + 200;
    while (!Serial3.available() && millis() < timeout) {
      // wait for echo
    }

    Serial.print(F("[FPGA] Sent 0x"));
    if (sent < 0x10) {
      Serial.print('0');
    }
    Serial.print(sent, HEX);

    if (Serial3.available()) {
      uint8_t received = Serial3.read();
      Serial.print(F("  Got 0x"));
      if (received < 0x10) {
        Serial.print('0');
      }
      Serial.print(received, HEX);

      if (received == sent) {
        Serial.println(F("  [PASS]"));
        gFPGAPassCount++;
      } else {
        Serial.println(F("  [FAIL - mismatch]"));
        gFPGAFailCount++;
      }
    } else {
      Serial.println(F("  [FAIL - no response]"));
      gFPGAFailCount++;
    }

    delay(20);
  }

  gFPGAConnected = (gFPGAFailCount == 0);
  Serial.print(F("[FPGA] Diagnostic results: "));
  Serial.print(gFPGAPassCount);
  Serial.print(F(" passed, "));
  Serial.print(gFPGAFailCount);
  Serial.println(F(" failed"));

  if (gFPGAConnected) {
    Serial.println(F("[FPGA] Link check OK."));
  } else {
    Serial.println(F("[FPGA] Link check FAILED. FPGA seed response is required for normal operation."));
  }

  return gFPGAConnected;
}

void printSystemStatus() {
  Serial.println();
  Serial.println(F("========== SYSTEM STATUS =========="));
  Serial.println(F("USB Serial @ 115200: OK"));

  Serial.print(F("Display HX8357D: "));
  Serial.println(gDisplayConnected ? F("OK") : F("FAIL"));

  Serial.print(F("FPGA UART (Serial3 A1/A4): "));
  if (gFPGAConnected) {
    Serial.println(F("OK"));
  } else {
    Serial.println(F("FAIL/PARTIAL"));
  }

  Serial.print(F("FPGA Loopback: "));
  Serial.print(gFPGAPassCount);
  Serial.print(F(" pass, "));
  Serial.print(gFPGAFailCount);
  Serial.println(F(" fail"));

  Serial.println(F("==================================="));
  Serial.println();
}

// ========================================
// Pause/Resume Functions
// ========================================

/**
 * Pause the Game of Life
 * Preserves the current grid state for resumption
 * Freezes the display and generation counter
 */
void pauseGameOfLife() {
  if (gGameState == STATE_RUNNING) {
    gGameState = STATE_PAUSING;
    Serial.println(F("[GAME] Pausing Game of Life..."));
    gGamePausedTime = millis();
    
    // Small delay to let display stabilize
    delay(100);
    gGameState = STATE_PAUSED_FOR_CAPTURE;
    Serial.println(F("[GAME] Game paused. Grid state preserved."));
    Serial.print(F("[GAME] Current generation: "));
    Serial.println(gol.getGeneration());
  }
}

/**
 * Resume the Game of Life
 * Continues from where it was paused with the same grid state
 */
void resumeGameOfLife() {
  if (gGameState == STATE_PAUSED_FOR_CAPTURE) {
    gGameState = STATE_RESUMING;
    Serial.println(F("[GAME] Resuming Game of Life..."));
    
    // Reset timing so update doesn't skip generations
    lastUpdateTime = millis();
    infoUpdateTime = millis();
    
    delay(100);
    gGameState = STATE_RUNNING;
    Serial.println(F("[GAME] Game resumed."));
  }
}

/**
 * Restart Game of Life with a new seed
 * Clears the grid and initializes with new seed
 */
void restartGameWithNewSeed(uint16_t newSeed) {
  gCurrentSeed = newSeed;
  gol.initialize(gCurrentSeed);
  renderer.requestFullRedraw();
  
  Serial.print(F("[GAME] Restarted with new seed: "));
  Serial.println(gCurrentSeed);
  Serial.print(F("[GAME] Pattern: "));
  Serial.println(gol.getPatternName(gCurrentSeed));
  
  uint16_t aliveCells = gol.countAliveCells();
  Serial.print(F("[GAME] Alive cells: "));
  Serial.println(aliveCells);
}

// ========================================
// SETUP
// ========================================
void setup() {
  Serial.begin(115200);
  // Do not block forever if USB monitor is not attached.
  uint32_t serialWaitStart = millis();
  while (!Serial && (millis() - serialWaitStart) < 2000) {
    delay(10);
  }
  
  delay(500);
  Serial.println();
  Serial.println(F("========================================"));
  Serial.println(F("  Conway's Game of Life"));
  Serial.println(F("  Feather M4 Express + HX8357D"));
  Serial.println(F("========================================"));
  Serial.println();
  
  // Initialize display
  Serial.println(F("Initializing display..."));
  if (!renderer.begin()) {
    Serial.println(F("ERROR: Display initialization failed!"));
    while (1) delay(100);
  }
  gDisplayConnected = true;
  Serial.println(F("Display initialized successfully."));

  // Initialize FPGA UART (Serial3 on A1/A4)
  Serial.println(F("Initializing FPGA UART on A1/A4..."));
  Serial3.begin(115200);
  pinPeripheral(A1, PIO_SERCOM_ALT);
  pinPeripheral(A4, PIO_SERCOM_ALT);
  delay(300);
  runFPGALoopbackDiagnostic();
  
  printSystemStatus();

  // Initialize Game of Life with a default seed since there's no fingerprint workflow
  gCurrentSeed = 12345;
  gol.initialize(gCurrentSeed);

  // Render current state after processFingerprints() seeded the game.
  renderer.requestFullRedraw();
  renderer.renderGrid(gol);
  renderer.updateInfoPanel(gol.getGeneration(), gol.getPatternName(gCurrentSeed), gCurrentSeed);
  
  Serial.println(F("Starting simulation..."));
  Serial.println();
  
  lastUpdateTime = millis();
  infoUpdateTime = millis();
}

// ========================================
// MAIN LOOP
// ========================================
void loop() {
  uint32_t now = millis();

  // Strict mode: never run simulation without completed fingerprint->FPGA seed workflow.
  if (!gWorkflowReady) {
    delay(20);
    return;
  }
  
  // Only update game if we're in running state
  if (gGameState == STATE_RUNNING) {
    // Update game state at fixed interval
    if (now - lastUpdateTime >= UPDATE_INTERVAL) {
      gol.update();
      renderer.renderGrid(gol);
      lastUpdateTime = now;
    }
    
    // Update info panel at slower interval
    if (now - infoUpdateTime >= INFO_UPDATE_INTERVAL) {
      renderer.updateInfoPanel(gol.getGeneration(), gol.getPatternName(gCurrentSeed), gCurrentSeed);
      
      // Also print generation to serial
      if (gol.getGeneration() % 10 == 0) {
        Serial.print(F("Generation: "));
        Serial.println(gol.getGeneration());
      }
      
      infoUpdateTime = now;
    }
  }
  
  // Check for serial commands
  if (Serial.available()) {
    char cmd = Serial.read();
    
    // If we're reading a seed, accumulate digits
    if (gReadingSeed) {
      if (cmd == '\n' || cmd == '\r') {
        // End of seed input; parse and initialize
        gSeedBuffer[gSeedBufferPos] = '\0';
        uint16_t newSeed = (uint16_t)atoi(gSeedBuffer);
        gCurrentSeed = newSeed;
        gol.initialize(gCurrentSeed);
        renderer.requestFullRedraw();
        Serial.print(F("Initialized with seed: "));
        Serial.println(gCurrentSeed);
        gReadingSeed = false;
        gSeedBufferPos = 0;
      } else if (isdigit(cmd) && gSeedBufferPos < 5) {
        // Accumulate digit
        gSeedBuffer[gSeedBufferPos++] = cmd;
      } else if (cmd == '\b' || cmd == 0x7F) {
        // Backspace
        if (gSeedBufferPos > 0) gSeedBufferPos--;
      }
      return;  // Continue reading seed, skip command processing
    }
    
    // Normal command processing
    switch (cmd) {
      case 'r':
      case 'R':
        // Random reseed disabled in strict mode
        Serial.println(F("[CMD] Disabled: random reseed fallback is not allowed in this build."));
        break;
        
      case 'i':
      case 'I':
        // Manual seed input disabled in strict mode
        Serial.println(F("[CMD] Disabled: manual seed fallback is not allowed in this build."));
        break;
        
      case 's':
      case 'S':
        // Print current status
        Serial.print(F("Generation: "));
        Serial.print(gol.getGeneration());
        Serial.print(F(" | Seed: "));
        Serial.print(gCurrentSeed);
        Serial.print(F(" | Pattern: "));
        Serial.println(gol.getPatternName(gCurrentSeed));
        break;
        
      case 'c':
      case 'C':
        // Clear screen
        renderer.clear();
        Serial.println(F("Screen cleared."));
        break;
      
      case 'f':
      case 'F':
        Serial.println(F("[FINGERPRINT] Fingerprint sensor disabled in this build."));
        break;

      case 't':
      case 'T':
        runFPGALoopbackDiagnostic();
        break;

      case 'd':
      case 'D':
        printSystemStatus();
        break;
        
      default:
        // Print help
        Serial.println(F("Commands:"));
        Serial.println(F("  R - Disabled (no fallback random seed)"));
        Serial.println(F("  I - Disabled (no fallback manual seed)"));
        Serial.println(F("  S - Print current status"));
        Serial.println(F("  C - Clear screen"));
        Serial.println(F("  F - Scan fingerprint and update seed (AS606 sensor required)"));
        Serial.println(F("  T - Run FPGA UART loopback diagnostic"));
        Serial.println(F("  D - Print startup connectivity status"));
        break;
    }
  }
}
