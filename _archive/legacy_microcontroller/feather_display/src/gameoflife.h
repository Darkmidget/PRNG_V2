#ifndef GAMEOFLIFE_H
#define GAMEOFLIFE_H

#include <stdint.h>
#include <string.h>

// Grid dimensions: 40 columns x 60 rows (8-pixel cells on 320x480 display)
#define GOL_COLS 40
#define GOL_ROWS 60

// Pattern definitions for seeding
struct Pattern {
  const char* name;
  uint8_t width;
  uint8_t height;
  const uint8_t* data;  // Flattened 2D array (row-major)
};

// Classic pattern data (flattened row-major format)
// Glider (3x3)
static const uint8_t PATTERN_GLIDER[] = {
  0, 1, 0,
  0, 0, 1,
  1, 1, 1
};

// Blinker (1x3)
static const uint8_t PATTERN_BLINKER[] = {
  1,
  1,
  1
};

// Beacon (4x4)
static const uint8_t PATTERN_BEACON[] = {
  1, 1, 0, 0,
  1, 1, 0, 0,
  0, 0, 1, 1,
  0, 0, 1, 1
};

// Block (2x2)
static const uint8_t PATTERN_BLOCK[] = {
  1, 1,
  1, 1
};

// Tub (3x3)
static const uint8_t PATTERN_TUB[] = {
  0, 1, 0,
  1, 0, 1,
  0, 1, 0
};

// Beehive (3x3)
static const uint8_t PATTERN_BEEHIVE[] = {
  0, 1, 1,
  1, 0, 1,
  0, 1, 0
};

// Loaf (4x3)
static const uint8_t PATTERN_LOAF[] = {
  1, 1, 0,
  1, 0, 1,
  0, 1, 0
};

// Boat (3x3)
static const uint8_t PATTERN_BOAT[] = {
  1, 1, 0,
  1, 0, 1,
  0, 1, 0
};

// Toad (4x2)
static const uint8_t PATTERN_TOAD[] = {
  0, 1, 1, 1,
  1, 1, 1, 0
};

// Pulsar (13x13) - oscillator
static const uint8_t PATTERN_PULSAR[] = {
  0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1,
  1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1,
  1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1,
  0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0,
  1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1,
  1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1,
  1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0
};

// Lightweight Spaceship (LWSS) (5x4)
static const uint8_t PATTERN_LWSS[] = {
  1, 0, 0, 1, 0,
  0, 0, 0, 0, 1,
  1, 0, 0, 0, 1,
  0, 1, 1, 1, 1
};

// Pattern library
static const Pattern PATTERNS[] = {
  {"Glider", 3, 3, PATTERN_GLIDER},
  {"Blinker", 1, 3, PATTERN_BLINKER},
  {"Beacon", 4, 4, PATTERN_BEACON},
  {"Block", 2, 2, PATTERN_BLOCK},
  {"Tub", 3, 3, PATTERN_TUB},
  {"Beehive", 3, 3, PATTERN_BEEHIVE},
  {"Loaf", 4, 3, PATTERN_LOAF},
  {"Boat", 3, 3, PATTERN_BOAT},
  {"Toad", 4, 2, PATTERN_TOAD},
  {"Pulsar", 13, 13, PATTERN_PULSAR},
  {"LWSS", 5, 4, PATTERN_LWSS},
};

#define NUM_PATTERNS (sizeof(PATTERNS) / sizeof(PATTERNS[0]))

class GameOfLife {
private:
  // Current and next generation grids
  uint8_t grid[GOL_ROWS][GOL_COLS];
  uint8_t nextGrid[GOL_ROWS][GOL_COLS];
  uint32_t generation;
  
  // Optimized neighbor counting - wraps at edges
  inline uint8_t countNeighbors(uint8_t x, uint8_t y) const {
    uint8_t count = 0;
    
    // Check all 8 neighbors (with wrapping)
    for (int8_t dy = -1; dy <= 1; dy++) {
      for (int8_t dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;  // Skip center cell
        
        // Wrap-around boundaries
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
  
  // Initialize grid with deterministic random fill using LCG PRNG.
  // Same seed always produces identical initial grid (deterministic).
  // Seed range: 0–65535 (uint16_t).
  void initialize(uint16_t seed) {
    // Clear grid
    memset(grid, 0, sizeof(grid));
    memset(nextGrid, 0, sizeof(nextGrid));
    generation = 0;
    
    // Linear Congruential Generator (LCG) for deterministic pseudorandom numbers
    // Seeded with the provided seed to ensure reproducibility
    uint32_t lcg_state = seed;
    
    auto lcg_next = [&lcg_state]() -> uint16_t {
      // Standard LCG parameters
      lcg_state = lcg_state * 1664525u + 1013904223u;
      return (uint16_t)(lcg_state >> 16);  // Return upper 16 bits
    };
    
    // Fill grid with random cells at ~25% density for interesting dynamics
    const uint8_t density_percent = 25;  // Tune 0..100 for initial density
    
    for (uint8_t y = 0; y < GOL_ROWS; ++y) {
      for (uint8_t x = 0; x < GOL_COLS; ++x) {
        // Use LCG to generate pseudorandom number 0-99, place cell if below density
        grid[y][x] = (lcg_next() % 100) < density_percent ? 1 : 0;
      }
    }
  }
  
  // Compute next generation using Conway's rules
  void update() {
    for (uint8_t y = 0; y < GOL_ROWS; y++) {
      for (uint8_t x = 0; x < GOL_COLS; x++) {
        uint8_t neighbors = countNeighbors(x, y);
        uint8_t alive = grid[y][x];
        
        // Conway's Game of Life rules:
        // 1. Any live cell with 2-3 neighbors survives
        // 2. Any dead cell with exactly 3 neighbors becomes alive
        // 3. All other cells die or stay dead
        
        if (alive && (neighbors == 2 || neighbors == 3)) {
          nextGrid[y][x] = 1;  // Survival
        } else if (!alive && neighbors == 3) {
          nextGrid[y][x] = 1;  // Birth
        } else {
          nextGrid[y][x] = 0;  // Death or stayed dead
        }
      }
    }
    
    // Swap grids
    memcpy(grid, nextGrid, sizeof(grid));
    generation++;
  }
  
  // Accessors
  inline uint8_t getCell(uint8_t x, uint8_t y) const {
    if (x < GOL_COLS && y < GOL_ROWS) {
      return grid[y][x];
    }
    return 0;
  }
  
  inline uint32_t getGeneration() const {
    return generation;
  }
  
  const char* getPatternName(uint16_t seed) const {
    // Return descriptive name based on seed.
    // With deterministic init, this helps identify which seed produced which pattern.
    static char buffer[32];
    snprintf(buffer, sizeof(buffer), "Seed-%u", seed);
    return buffer;
  }
  
  // Debug function to count alive cells
  uint16_t countAliveCells() const {
    uint16_t count = 0;
    for (uint8_t y = 0; y < GOL_ROWS; y++) {
      for (uint8_t x = 0; x < GOL_COLS; x++) {
        if (grid[y][x]) count++;
      }
    }
    return count;
  }
  
  // Debug function to print grid state
  void debugPrintGrid() const {
    Serial.println(F("Grid State (. = dead, X = alive):"));
    for (uint8_t y = 0; y < GOL_ROWS; y++) {
      for (uint8_t x = 0; x < GOL_COLS; x++) {
        Serial.print(grid[y][x] ? 'X' : '.');
      }
      Serial.println();
    }
  }
};

#endif // GAMEOFLIFE_H
