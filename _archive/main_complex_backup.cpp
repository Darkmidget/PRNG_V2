/***************************************************
  MINIMAL DIAGNOSTIC - Testing board responsiveness
 ****************************************************/

#include <Arduino.h>

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
AS606Interface fingerprint;
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
bool gFingerprintConnected = false;
bool gFPGAConnected = false;
uint8_t gFPGAPassCount = 0;
uint8_t gFPGAFailCount = 0;
bool gWorkflowReady = false;  // True only after successful fingerprint->FPGA seed workflow

// Game state enum for fingerprint capture workflow
enum GameState {
  STATE_RUNNING,              // Normal Game of Life operation
  STATE_PAUSING,              // Transitioning to pause
  STATE_PAUSED_FOR_CAPTURE,   // Paused, waiting for fingerprint
  STATE_RESUMING              // Transitioning back to running
};

// Global game state
GameState gGameState = STATE_RUNNING;

// Global fingerprint data
uint16_t gLastFingerprintID = 0;
uint16_t gLastFingerprintConfidence = 0;
bool gFingerprintDataReady = false;

[[noreturn]] void fatalStop(const __FlashStringHelper *message) {
  Serial.println();
  Serial.println(F("[FATAL] ======================================="));
  Serial.println(message);
  Serial.println(F("[FATAL] System halted. Fix wiring/device and reset."));
  Serial.println(F("[FATAL] ======================================="));
  while (1) {
    delay(250);
  }
}

bool runFPGADiagnostic() {
  gFPGAPassCount = 0;
  gFPGAFailCount = 0;

  Serial.println(F("[FPGA] Running startup binary protocol diagnostic..."));
  Serial.println(F("[FPGA] A1 <- DIP22 (FPGA TX), A4 -> DIP23 (FPGA RX)"));

  // Verify multiple frames, each must return 2-byte random output.
  struct TestVector {
    uint8_t b0;
    uint8_t b1;
  };

  const TestVector vectors[] = {
    {0x42, 0x69},
    {0x00, 0x00},
    {0xAA, 0x55}
  };

  uint16_t verifiedOutputs[sizeof(vectors) / sizeof(vectors[0])] = {0};
  const uint8_t repeatsPerVector = 2;

  for (uint8_t i = 0; i < (sizeof(vectors) / sizeof(vectors[0])); i++) {
    const uint16_t txWord = (uint16_t)(((uint16_t)vectors[i].b1 << 8) | vectors[i].b0);
    bool vectorPass = true;
    uint16_t firstOut = 0;

    Serial.print(F("[FPGA] Test vector "));
    Serial.print(i);
    Serial.print(F(": [0x"));
    Serial.print(vectors[i].b0, HEX);
    Serial.print(F(", 0x"));
    Serial.print(vectors[i].b1, HEX);
    Serial.println(F("]"));

    for (uint8_t r = 0; r < repeatsPerVector; r++) {
      uint16_t seedOut = 0;
      bool ok = fpga.processSeedBytes(vectors[i].b0, vectors[i].b1, seedOut);

      if (!ok) {
        Serial.print(F("[FPGA]   Attempt "));
        Serial.print(r + 1);
        Serial.println(F(" FAILED (timeout/no response)."));
        vectorPass = false;
        break;
      }

      Serial.print(F("[FPGA]   Attempt "));
      Serial.print(r + 1);
      Serial.print(F(" -> 0x"));
      if (seedOut < 0x1000) {
        Serial.print('0');
      }
      Serial.println(seedOut, HEX);

      if (seedOut == txWord) {
        // Reject probable electrical/software echo of sent bytes.
        Serial.println(F("[FPGA]   FAIL: Response matched transmitted bytes (echo suspected)."));
        vectorPass = false;
        break;
      }

      if (r == 0) {
        firstOut = seedOut;
      } else if (seedOut != firstOut) {
        // For a seeded FPGA path, repeated challenge should be deterministic.
        Serial.println(F("[FPGA]   FAIL: Non-deterministic response for identical challenge."));
        vectorPass = false;
        break;
      }
    }

    if (vectorPass) {
      verifiedOutputs[i] = firstOut;
      gFPGAPassCount++;
      Serial.println(F("[FPGA]   PASS"));
    } else {
      gFPGAFailCount++;
      Serial.println(F("[FPGA]   FAIL"));
    }

    delay(30);
  }

  if (gFPGAFailCount == 0) {
    // Additional anti-false-positive check: different challenges should not all map to the same output.
    bool allSame = true;
    for (uint8_t i = 1; i < (sizeof(vectors) / sizeof(vectors[0])); i++) {
      if (verifiedOutputs[i] != verifiedOutputs[0]) {
        allSame = false;
        break;
      }
    }

    if (allSame) {
      Serial.println(F("[FPGA] FAIL: All challenges produced the same output (line noise/stuck line suspected)."));
      gFPGAFailCount = 1;
      gFPGAPassCount = 0;
    }
  }

  gFPGAConnected = (gFPGAFailCount == 0);
  Serial.print(F("[FPGA] Diagnostic results: "));
  Serial.print(gFPGAPassCount);
  Serial.print(F(" passed, "));
  Serial.print(gFPGAFailCount);
  Serial.println(F(" failed"));
  
  if (!gFPGAConnected) {
    Serial.println(F("[FPGA] *** FPGA NOT DETECTED - STARTUP WILL HALT ***"));
  }

  return gFPGAConnected;
}

void printSystemStatus() {
  Serial.println();
  Serial.println(F("========== SYSTEM STATUS =========="));
  Serial.println(F("USB Serial @ 115200: OK"));

  Serial.print(F("Display HX8357D: "));
  Serial.println(gDisplayConnected ? F("OK") : F("FAIL"));

  Serial.print(F("Fingerprint (Serial1 D0/D1): "));
  Serial.println(gFingerprintConnected ? F("OK") : F("FAIL"));

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

void suspendGameUntilValidFingerprint(const __FlashStringHelper *reason) {
  Serial.println(reason);
  Serial.println(F("[GAME] Strict mode: Game of Life display is suspended until valid fingerprint->FPGA seed flow succeeds."));
  gGameState = STATE_PAUSED_FOR_CAPTURE;
  gWorkflowReady = false;
  renderer.clear();
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
// Fingerprint Capture Workflow
// ========================================

/**
 * Execute the complete fingerprint capture and seed update workflow
 * This is called when the user triggers a fingerprint scan
 * 
 * Workflow:
 *   1. Pause the Game of Life
 *   2. Attempt to capture fingerprint from sensor
 *   3. Search for match in database
 *   4. Derive 2 seed bytes from captured fingerprint template
 *   5. Send bytes to FPGA and receive randomized seed
 *   6. Update Game of Life with new seed
 *   7. Resume the Game of Life
 */
bool processFingerprints() {
  Serial.println(F("\n[FINGERPRINT] ========== FINGERPRINT SCAN INITIATED =========="));
  
  // STEP 1: Pause the game
  pauseGameOfLife();
  
  // STEP 2: Capture image from sensor
  Serial.println(F("[FINGERPRINT] Attempting to capture fingerprint..."));
  uint8_t p = fingerprint.getImage();
  
  if (p != FINGERPRINT_OK) {
    Serial.print(F("[FINGERPRINT] Image capture failed. Response code: 0x"));
    Serial.println(p, HEX);
    fingerprint.printLastResponseCode();
    
    Serial.println(F("[FINGERPRINT] Aborting fingerprint scan."));
    suspendGameUntilValidFingerprint(F("[FINGERPRINT] Invalid/unavailable fingerprint image."));
    return false;
  }
  
  Serial.println(F("[FINGERPRINT] Image captured successfully."));
  delay(100);
  
  // STEP 3: Convert image to template
  p = fingerprint.image2Tz(1);
  if (p != FINGERPRINT_OK) {
    Serial.print(F("[FINGERPRINT] Template conversion failed. Response code: 0x"));
    Serial.println(p, HEX);
    fingerprint.printLastResponseCode();
    suspendGameUntilValidFingerprint(F("[FINGERPRINT] Template conversion failed."));
    return false;
  }
  
  Serial.println(F("[FINGERPRINT] Template generated successfully."));
  delay(100);
  
  // STEP 4: Search for match in database (informational only)
  Serial.println(F("[FINGERPRINT] Searching for match in database..."));
  uint16_t matchID = fingerprint.fingerSearch();
  uint16_t confidence = fingerprint.getLastConfidence();

  if (matchID == 0) {
    Serial.println(F("[FINGERPRINT] No database match. Proceeding with raw fingerprint template."));
  } else {
    Serial.print(F("[FINGERPRINT] Match found! ID: "));
    Serial.print(matchID);
    Serial.print(F(", Confidence: "));
    Serial.println(confidence);
  }

  // STEP 5: Reduce fingerprint template bytes to 2-byte FPGA seed input.
  uint8_t seedByte0 = 0;
  uint8_t seedByte1 = 0;
  if (!fingerprint.deriveSeedBytesFromTemplate(seedByte0, seedByte1)) {
    Serial.println(F("[FINGERPRINT] ERROR: Failed to derive seed bytes from fingerprint template."));
    suspendGameUntilValidFingerprint(F("[FINGERPRINT] Could not derive seed bytes from fingerprint image."));
    return false;
  }

  // STEP 6: Send to FPGA and receive randomized 16-bit seed.
  Serial.println(F("[FINGERPRINT] Sending template-derived bytes to FPGA..."));
  uint16_t newSeed = 0;
  if (!fpga.processSeedBytes(seedByte0, seedByte1, newSeed)) {
    Serial.println(F("[FINGERPRINT] ERROR: FPGA did not return a valid 2-byte response."));
    suspendGameUntilValidFingerprint(F("[FINGERPRINT] FPGA seed exchange failed."));
    return false;
  }

  // STEP 7: Restart game with new seed.
  restartGameWithNewSeed(newSeed);
  
  Serial.println(F("[FINGERPRINT] ========== FINGERPRINT SCAN COMPLETE ==========\n"));
  
  // STEP 8: Resume the game
  gWorkflowReady = true;
  resumeGameOfLife();
  return true;
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
  
  // CRITICAL: Check FPGA FIRST before any rendering
  // Initialize FPGA UART (Serial3 on A1/A4)
  Serial.println(F("Initializing FPGA UART on A1/A4..."));
  Serial3.begin(115200);
  pinPeripheral(A1, PIO_SERCOM_ALT);
  pinPeripheral(A4, PIO_SERCOM_ALT);
  delay(300);
  if (!runFPGADiagnostic()) {
    fatalStop(F("FPGA UART diagnostic failed (A1/A4 <-> DIP22/23). NO RENDERING WITHOUT FPGA."));
  }
  
  // Only initialize display AFTER FPGA is confirmed
  Serial.println(F("Initializing display..."));
  if (!renderer.begin()) {
    fatalStop(F("Display initialization failed."));
  }
  gDisplayConnected = true;
  Serial.println(F("Display initialized successfully."));
  
  // Initialize fingerprint sensor. Startup halts if this step fails.
  Serial.println();
  Serial.println(F("Initializing AS606 fingerprint sensor..."));
  if (fingerprint.begin()) {
    gFingerprintConnected = true;
    Serial.println(F("Fingerprint sensor initialized successfully!"));
    Serial.println(F("Type 'F' in Serial Monitor to capture fingerprint."));
  } else {
    fatalStop(F("Fingerprint sensor initialization failed (D0/D1)."));
  }

  printSystemStatus();

  // No fallback mode: do not start the simulation until full fingerprint->FPGA path succeeds.
  Serial.println(F("[BOOT] Startup fingerprint check: place your thumb now..."));
  Serial.println(F("[BOOT] Waiting for successful fingerprint -> FPGA -> Game seed flow."));
  renderer.clear();
  while (!processFingerprints()) {
    Serial.println(F("[BOOT] Retry required. Place thumb and try again."));
    delay(500);
  }

  // Render current state after processFingerprints() seeded the game.
  // Only render if FPGA is confirmed to be connected
  if (gFPGAConnected && gWorkflowReady) {
    renderer.requestFullRedraw();
    renderer.renderGrid(gol);
    renderer.updateInfoPanel(gol.getGeneration(), gol.getPatternName(gCurrentSeed), gCurrentSeed);
  } else {
    Serial.println(F("[ERROR] Cannot render: FPGA not connected or workflow not ready"));
    while (1) {
      delay(250);  // Halt if FPGA is not available
    }
  }
  
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
  // AND verify FPGA is still connected
  if (!gWorkflowReady || !gFPGAConnected) {
    if (Serial.available()) {
      char cmd = Serial.read();
      if (cmd == 'f' || cmd == 'F') {
        (void)processFingerprints();
      }
    }
    delay(20);
    return;
  }
  
  // Only update game if we're in running state AND FPGA is connected
  if (gGameState == STATE_RUNNING && gFPGAConnected) {
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
        Serial.println(F("[CMD] Disabled: random reseed fallback is not allowed in this build."));
        break;
        
      case 'i':
      case 'I':
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
        // Start fingerprint scan
        if (!processFingerprints()) {
          Serial.println(F("[FINGERPRINT] Workflow failed. Display remains suspended until valid fingerprint flow succeeds."));
        }
        break;

      case 't':
      case 'T':
        runFPGADiagnostic();
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
        Serial.println(F("  F - Run full fingerprint -> FPGA -> Game update"));
        Serial.println(F("  T - Run FPGA binary protocol diagnostic"));
        Serial.println(F("  D - Print startup connectivity status"));
        break;
    }
  }
}
