/*******************************************************************************
 * INTEGRATED FEATHER M4: Game of Life + Fingerprint + FPGA
 * 
 * WIRING:
 * 1. Fingerprint Sensor (AS606/AS608):
 *    - Sensor TX (White) -> D0 (RX)[cite: 6]
 *    - Sensor RX (Green) -> D1 (TX)[cite: 6]
 * 2. FPGA (Serial2):
 *    - FPGA TX -> A1 (RX)[cite: 4, 6]
 *    - FPGA RX -> A4 (TX)[cite: 4, 6]
 * 3. Display (HX8357D):
 *    - CS -> D9 | DC -> D10 (Adjust as needed)[cite: 2, 6]
 ******************************************************************************/

#include <Arduino.h>
#include <Adafruit_Fingerprint.h>
#include <Adafruit_GFX.h>
#include <Adafruit_HX8357.h>
#include "wiring_private.h" // For pinPeripheral()[cite: 1, 4]

// =============================================================================
// 1. GAME OF LIFE LOGIC[cite: 5]
// =============================================================================
#define GOL_COLS 40
#define GOL_ROWS 60

class GameOfLife {
private:
  uint8_t grid[GOL_ROWS][GOL_COLS];
  uint8_t nextGrid[GOL_ROWS][GOL_COLS];
  uint32_t generation;

  inline uint8_t countNeighbors(uint8_t x, uint8_t y) const {
    uint8_t count = 0;
    for (int8_t dy = -1; dy <= 1; dy++) {
      for (int8_t dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        int nx = (x + dx + GOL_COLS) % GOL_COLS;
        int ny = (y + dy + GOL_ROWS) % GOL_ROWS;
        if (grid[ny][nx]) count++;
      }
    }
    return count;
  }

public:
  GameOfLife() : generation(0) {
    memset(grid, 0, sizeof(grid));
    memset(nextGrid, 0, sizeof(nextGrid));
  }

  void initialize(uint16_t seed) {
    memset(grid, 0, sizeof(grid));
    generation = 0;
    uint32_t lcg_state = seed;
    auto lcg_next = [&lcg_state]() -> uint16_t {
      lcg_state = lcg_state * 1664525u + 1013904223u;
      return (uint16_t)(lcg_state >> 16);
    };

    for (uint8_t y = 0; y < GOL_ROWS; ++y) {
      for (uint8_t x = 0; x < GOL_COLS; ++x) {
        grid[y][x] = (lcg_next() % 100) < 25 ? 1 : 0;
      }
    }
  }

  void update() {
    for (uint8_t y = 0; y < GOL_ROWS; y++) {
      for (uint8_t x = 0; x < GOL_COLS; x++) {
        uint8_t neighbors = countNeighbors(x, y);
        uint8_t alive = grid[y][x];
        if (alive && (neighbors == 2 || neighbors == 3)) nextGrid[y][x] = 1;
        else if (!alive && neighbors == 3) nextGrid[y][x] = 1;
        else nextGrid[y][x] = 0;
      }
    }
    memcpy(grid, nextGrid, sizeof(grid));
    generation++;
  }

  uint8_t getCell(uint8_t x, uint8_t y) const { return grid[y][x]; }
  uint32_t getGeneration() const { return generation; }
};

// =============================================================================
// 2. DISPLAY RENDERER[cite: 2]
// =============================================================================
#define COLOR_BG    0x0000
#define COLOR_ALIVE 0xFFFF
#define COLOR_TEXT  0xFFE0
#define CELL_WIDTH  8
#define CELL_HEIGHT 8
#define DISPLAY_WIDTH 320
#define DISPLAY_HEIGHT 480

class DisplayRenderer {
private:
  Adafruit_HX8357 tft;

public:
  DisplayRenderer(int8_t cs, int8_t dc) : tft(cs, dc, -1) {}

  bool begin() {
    tft.begin(HX8357D);
    tft.setRotation(0);
    tft.fillScreen(COLOR_BG);
    return true;
  }

  void renderGrid(const GameOfLife &game) {
    for (uint8_t y = 0; y < GOL_ROWS; y++) {
      for (uint8_t x = 0; x < GOL_COLS; x++) {
        uint16_t color = game.getCell(x, y) ? COLOR_ALIVE : COLOR_BG;
        tft.fillRect(x * CELL_WIDTH, y * CELL_HEIGHT, CELL_WIDTH, CELL_HEIGHT, color);
      }
      delay(1); 
    }
  }

  void updateInfoPanel(uint32_t generation, const char* status, uint16_t seed) {
    tft.fillRect(0, DISPLAY_HEIGHT - 16, DISPLAY_WIDTH, 16, COLOR_BG);
    tft.setTextSize(1);
    tft.setTextColor(COLOR_TEXT);
    tft.setCursor(2, DISPLAY_HEIGHT - 14);
    tft.print("Gen:"); tft.print(generation);
    tft.print(" | "); tft.print(status);
    tft.print(" | S:"); tft.print(seed);
  }
};

// =============================================================================
// 3. FPGA SERIAL INTERFACE[cite: 4]
// =============================================================================
// Custom Serial2 on SERCOM3: RX=13 (PA23, PAD[1]), TX=12 (PA22, PAD[0])
// Note: SAMD UART hardware requires TX to be on PAD[0] or PAD[2], so 12 must be TX and 13 must be RX.
Uart Serial2(&sercom3, 13, 12, SERCOM_RX_PAD_1, UART_TX_PAD_0);
void SERCOM3_0_Handler() { Serial2.IrqHandler(); }
void SERCOM3_1_Handler() { Serial2.IrqHandler(); }
void SERCOM3_2_Handler() { Serial2.IrqHandler(); }
void SERCOM3_3_Handler() { Serial2.IrqHandler(); }

class FPGASerial {
public:
  void begin() {
    Serial2.begin(115200);

    // BUG FIX: On SAMD51, pinMode() clears PMUXEN, overriding any prior
    // pinPeripheral() call.  The SERCOM mux assignment MUST be the last
    // thing touching the pin control registers, so set the pull-up first,
    // then (re-)assign the peripheral — not the other way around.
    //
    // Old (broken) order:
    //   pinPeripheral(13, PIO_SERCOM);  // assigns SERCOM3 RX
    //   pinMode(13, INPUT_PULLUP);      // ← silently clears PMUXEN!  RX dead.
    //
    // Correct order:
    pinMode(13, INPUT_PULLUP);     // 1. set pull-up (GPIO mode, PMUXEN cleared)
    pinPeripheral(13, PIO_SERCOM); // 2. re-enable SERCOM mux (PMUXEN set again)
                                   //    PULLEN bit is preserved by pinPeripheral.
    pinPeripheral(12, PIO_SERCOM); // TX — no pull-up needed
  }

  uint16_t receiveSeedFromFPGABinary() {
    uint32_t start = millis();
    int16_t low = -1, high = -1;
    while ((millis() - start) < 10000) {
      if (Serial2.available()) {
        if (low < 0) low = Serial2.read();
        else { 
          high = Serial2.read(); 
          return (uint16_t)((high << 8) | low); 
        }
      }
      delay(1);
    }
    Serial.println(F("[FPGA] TIMEOUT: No valid seed received. Halting."));
    while (true) { delay(100); } // Halt execution
    //return (uint16_t)random(65536); // Local fallback seed[cite: 4]
  }
};

// =============================================================================
// 4. MAIN APPLICATION & STATE MACHINE[cite: 6]
// =============================================================================
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&Serial1);
DisplayRenderer display(9, 10);
GameOfLife gameOfLife;
FPGASerial fpgaSerial;

enum AnimationState { 
  STATE_WAITING_INITIAL_FINGER, 
  STATE_RUNNING, 
  STATE_WAITING_FINGER, 
  STATE_PROCESSING, 
  STATE_RESTARTING 
};

AnimationState currentState = STATE_WAITING_INITIAL_FINGER;
uint32_t lastGameUpdate = 0;
uint32_t lastDisplayUpdate = 0;
uint32_t stateTime = 0;
uint16_t currentSeed = 0; // Tracks the seed returned by FPGA[cite: 6]
bool fingerprintReady = false;

const uint8_t FINGERPRINT_UPLOADIMAGE = 0x0A;

bool captureFingerprint() {
  uint8_t p = finger.getImage();
  return (p == FINGERPRINT_OK);
}

bool sendImageToFPGA() {
  uint8_t cmd = FINGERPRINT_UPLOADIMAGE;
  Adafruit_Fingerprint_Packet packet(FINGERPRINT_COMMANDPACKET, 1, &cmd);
  finger.writeStructuredPacket(packet);
  if (finger.getStructuredPacket(&packet) != FINGERPRINT_OK) return false;

  while (Serial2.available()) Serial2.read(); // Clear buffer[cite: 4]

  uint8_t chk = 0;
  const uint8_t XOR_KEY = 0x5A;

  while (true) {
    if (finger.getStructuredPacket(&packet) != FINGERPRINT_OK) return false;
    uint16_t len = (packet.length >= 2) ? (packet.length - 2) : 0;
    
    for (uint16_t i = 0; i < len; i++) {
      uint8_t c = packet.data[i] ^ XOR_KEY;
      chk ^= c;
      if (c == 0xFF || c == 0xFE) { 
        Serial2.write(0xFE); 
        Serial2.write(c == 0xFF ? 0xFD : 0xFE); 
      } else { 
        Serial2.write(c); 
      }
    }
    if (packet.type == FINGERPRINT_ENDDATAPACKET) break;
  }
  
  // Bug fix: The checksum byte itself must be escaped if it is 0xFF or 0xFE!
  if (chk == 0xFF || chk == 0xFE) { 
    Serial2.write(0xFE); 
    Serial2.write(chk == 0xFF ? 0xFD : 0xFE); 
  } else { 
    Serial2.write(chk); 
  }
  
  Serial2.write(0xFF); // End of frame terminator
  return true;
}

void setup() {
  Serial.begin(115200);
  Serial1.begin(57600); // Fingerprint Sensor[cite: 6]
  
  finger.begin(57600);
  fpgaSerial.begin();
  display.begin();

  if (!finger.verifyPassword()) {
    Serial.println(F("Fingerprint Sensor Error!"));
    while(1);
  }
  finger.setPacketSize(FINGERPRINT_PACKET_SIZE_32);
}

void loop() {
  uint32_t now = millis();

  switch (currentState) {
    case STATE_WAITING_INITIAL_FINGER:
      display.updateInfoPanel(0, "Place Finger", 0);
      if (captureFingerprint()) {
        currentState = STATE_PROCESSING;
        fingerprintReady = true;
      }
      break;

    case STATE_RUNNING:
      if (now - lastGameUpdate >= 300) { 
        gameOfLife.update(); 
        lastGameUpdate = now; 
      }
      if (now - lastDisplayUpdate >= 100) { 
        display.renderGrid(gameOfLife); 
        // Pass currentSeed to show it during animation[cite: 2]
        display.updateInfoPanel(gameOfLife.getGeneration(), "Running", currentSeed);
        lastDisplayUpdate = now; 
      }
      if (finger.getImage() == FINGERPRINT_OK) {
        stateTime = now;
        currentState = STATE_WAITING_FINGER;
      }
      break;

    case STATE_WAITING_FINGER:
      display.updateInfoPanel(gameOfLife.getGeneration(), "Scanning...", currentSeed);
      if (captureFingerprint()) {
        currentState = STATE_PROCESSING;
        fingerprintReady = true;
      } else if (now - stateTime > 5000) {
        currentState = STATE_RUNNING;
      }
      break;

    case STATE_PROCESSING:
      if (fingerprintReady && sendImageToFPGA()) {
        currentSeed = fpgaSerial.receiveSeedFromFPGABinary(); // Store global seed
        gameOfLife.initialize(currentSeed);
        fingerprintReady = false;
        stateTime = now;
        currentState = STATE_RESTARTING;
      } else {
        currentState = STATE_RUNNING;
      }
      break;

    case STATE_RESTARTING:
      // Show new seed during initialization phase[cite: 2]
      display.updateInfoPanel(gameOfLife.getGeneration(), "New Seed!", currentSeed);
      display.renderGrid(gameOfLife);
      if (now - stateTime > 2000) currentState = STATE_RUNNING;
      break;
  }
}
