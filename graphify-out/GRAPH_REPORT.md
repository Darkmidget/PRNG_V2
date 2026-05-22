# Graph Report - .  (2026-05-22)

## Corpus Check
- 115 files · ~87,101 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 491 nodes · 457 edges · 172 communities (112 shown, 60 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 36 edges (avg confidence: 0.86)
- Token cost: 4,200 input · 1,800 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 109|Community 109]]
- [[_COMMUNITY_Community 111|Community 111]]
- [[_COMMUNITY_Community 113|Community 113]]
- [[_COMMUNITY_Community 114|Community 114]]
- [[_COMMUNITY_Community 116|Community 116]]
- [[_COMMUNITY_Community 118|Community 118]]
- [[_COMMUNITY_Community 119|Community 119]]
- [[_COMMUNITY_Community 133|Community 133]]
- [[_COMMUNITY_Community 134|Community 134]]
- [[_COMMUNITY_Community 135|Community 135]]
- [[_COMMUNITY_Community 136|Community 136]]
- [[_COMMUNITY_Community 137|Community 137]]
- [[_COMMUNITY_Community 138|Community 138]]
- [[_COMMUNITY_Community 139|Community 139]]
- [[_COMMUNITY_Community 140|Community 140]]
- [[_COMMUNITY_Community 141|Community 141]]
- [[_COMMUNITY_Community 142|Community 142]]
- [[_COMMUNITY_Community 143|Community 143]]
- [[_COMMUNITY_Community 144|Community 144]]
- [[_COMMUNITY_Community 145|Community 145]]
- [[_COMMUNITY_Community 147|Community 147]]
- [[_COMMUNITY_Community 148|Community 148]]
- [[_COMMUNITY_Community 149|Community 149]]
- [[_COMMUNITY_Community 150|Community 150]]
- [[_COMMUNITY_Community 151|Community 151]]
- [[_COMMUNITY_Community 152|Community 152]]
- [[_COMMUNITY_Community 153|Community 153]]
- [[_COMMUNITY_Community 154|Community 154]]
- [[_COMMUNITY_Community 155|Community 155]]
- [[_COMMUNITY_Community 156|Community 156]]
- [[_COMMUNITY_Community 157|Community 157]]
- [[_COMMUNITY_Community 158|Community 158]]
- [[_COMMUNITY_Community 159|Community 159]]
- [[_COMMUNITY_Community 160|Community 160]]
- [[_COMMUNITY_Community 161|Community 161]]
- [[_COMMUNITY_Community 162|Community 162]]
- [[_COMMUNITY_Community 163|Community 163]]
- [[_COMMUNITY_Community 164|Community 164]]
- [[_COMMUNITY_Community 165|Community 165]]
- [[_COMMUNITY_Community 166|Community 166]]
- [[_COMMUNITY_Community 167|Community 167]]
- [[_COMMUNITY_Community 168|Community 168]]
- [[_COMMUNITY_Community 169|Community 169]]
- [[_COMMUNITY_Community 170|Community 170]]
- [[_COMMUNITY_Community 171|Community 171]]

## God Nodes (most connected - your core abstractions)
1. `FingerprintCapture` - 16 edges
2. `RandomnessAnalyzer` - 15 edges
3. `main()` - 9 edges
4. `main()` - 8 edges
5. `entropy` - 8 edges
6. `printTestHeader()` - 8 edges
7. `passTest()` - 8 edges
8. `setup()` - 8 edges
9. `frequency` - 7 edges
10. `autocorrelation` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Verilog README` --references--> `Build Script Powershell`  [EXTRACTED]
  verilog/README.md → scripts/build_tools/build.ps1
- `Verilog README` --references--> `LED Blink Module`  [EXTRACTED]
  verilog/README.md → src/blink.v
- `Convert Init Script` --shares_data_with--> `Adafruit HX8357`  [INFERRED]
  scripts/convert_init.py → Adafruit_HX8357.cpp
- `Find-FPGAPort()` --calls--> `Write-Error()`  [INFERRED]
  scripts/Collect_FPGA_Data.ps1 → verilog/scripts/build_tools/build.ps1
- `Open-SerialConnection()` --calls--> `Write-Error()`  [INFERRED]
  scripts/Collect_FPGA_Data.ps1 → verilog/scripts/build_tools/build.ps1

## Hyperedges (group relationships)
- **FPGA Communications** — fpga_interface_h, fpga_serial_h, collect_ps1 [INFERRED 0.75]
- **UART Testing Suite** — monitor_serial_py_monitor, uart_loopback_v_module, prng_testing_concept, test_a1_a4_serial_ps1_script [INFERRED 0.85]
- **UART Test Components** — uart_tb, as606_controller, uart [INFERRED 0.85]
- **FPGA Build System** — build_config, build_script, verilog_readme [INFERRED 0.85]
- **Bit-Level Metrics** — concept_bit_distribution, concept_per_bit_chi_square, concept_bit_pair_correlations [INFERRED 0.95]
- **Entropy Analysis Metrics** — entropy_byte_distribution, entropy_per_chunk, frequency_distribution_of_values, value_coverage_analysis [INFERRED 0.95]
- **HX8357D Initialization Translation** — Adafruit_HX8357, convert_init, write_init, hx8357d_init, converted_utf8_txt [INFERRED 0.85]
- **Game of Life Hardware Implementation** — hx8357d_controller, game_of_life, bram_framebuffer [INFERRED 0.85]
- **Fingerprint Data Validation** — fingerprint_data_collection_guide, fingerprint_data_analysis, validation_report [INFERRED 0.85]
- **FPGA Build System** — build_config, build_script, verilog_readme [INFERRED 0.85]
- **Bit-Level Metrics** — concept_bit_distribution, concept_per_bit_chi_square, concept_bit_pair_correlations [INFERRED 0.95]
- **Entropy Analysis Metrics** — entropy_byte_distribution, entropy_per_chunk, frequency_distribution_of_values, value_coverage_analysis [INFERRED 0.95]
- **UART Testing Suite** — monitor_serial_py_monitor, uart_loopback_v_module, prng_testing_concept, test_a1_a4_serial_ps1_script [INFERRED 0.85]

## Communities (172 total, 60 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.07
Nodes (18): generate_report(), load_random_values(), main(), RandomnessAnalyzer, Shannon entropy test., Wald-Wolfowitz runs test on bit transitions., Kolmogorov-Smirnov test against uniform distribution., Autocorrelation analysis to detect patterns. (+10 more)

### Community 1 - "Community 1"
Cohesion: 0.13
Nodes (18): Adafruit HX8357, Adafruit SPITFT, begin(), clear(), DisplayRenderer(), renderGrid(), requestFullRedraw(), updateInfoPanel() (+10 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (11): FingerprintCapture, main(), Scan and export one fingerprint, Scan a finger and save immediately, List all enrolled fingerprints, Export all enrolled fingerprints, Main interactive menu, Load existing templates from CSV (+3 more)

### Community 3 - "Community 3"
Cohesion: 0.20
Nodes (15): failTest(), infoLog(), passTest(), printTestHeader(), setup(), testDisplay(), testFingerprintSensor(), testFPGASerial() (+7 more)

### Community 4 - "Community 4"
Cohesion: 0.24
Nodes (10): fatalStop(), loop(), pauseGameOfLife(), printSystemStatus(), processFingerprints(), restartGameWithNewSeed(), resumeGameOfLife(), runFPGADiagnostic() (+2 more)

### Community 5 - "Community 5"
Cohesion: 0.20
Nodes (14): load_random_values(), load_test_results(), main(), plot_autocorrelation(), plot_bit_analysis(), plot_distribution_overview(), plot_entropy_analysis(), plot_test_results() (+6 more)

### Community 6 - "Community 6"
Cohesion: 0.31
Nodes (11): append_event(), append_template_chunk(), choose_serial_port(), command_to_wire(), ensure_csv(), get_arg_value(), load_index(), main() (+3 more)

### Community 7 - "Community 7"
Cohesion: 0.17
Nodes (11): files.associations, *.v, *.vh, *.xdc, files.exclude, **/build, **/*.jou, **/*.log (+3 more)

### Community 8 - "Community 8"
Cohesion: 0.22
Nodes (11): BRAM Framebuffer, Convert Init Script, Converted Initialization Values, Diagnostic Test, Game Of Life Hardware, HX8357D Controller, HX8357D Init, SPI Master (+3 more)

### Community 9 - "Community 9"
Cohesion: 0.33
Nodes (6): Invoke-Vivado(), Write-Error(), Write-Info(), Find-FPGAPort(), Get-AvailablePorts(), Open-SerialConnection()

### Community 10 - "Community 10"
Cohesion: 0.33
Nodes (6): Adafruit_Fingerprint, AS606Interface (C++ Class), AS606Interface(), fingerSearch(), getTemplateCount(), printLastResponseCode()

### Community 11 - "Community 11"
Cohesion: 0.25
Nodes (8): entropy, entropy, max_entropy, n_unique, normalized_entropy, pass, ratio_to_theoretical, theoretical_max

### Community 12 - "Community 12"
Cohesion: 0.46
Nodes (6): processFingerprint(), processSeedBytes(), receiveSeedFromFPGA(), sendFingerprintData(), sendSeedFrame(), testConnection()

### Community 13 - "Community 13"
Cohesion: 0.29
Nodes (6): Bit-Level Analysis Plot, Individual Bit Distribution, Bit-Level Analysis, Bit Pair Correlations, Chi-square Test, Per-Bit Chi-square Test

### Community 15 - "Community 15"
Cohesion: 0.33
Nodes (7): LED Blink Module, Build Configuration TCL, Build Script Powershell, CMOD A7 Constraints, FPGA Project Template, Verilog README, Template Guide

### Community 16 - "Community 16"
Cohesion: 0.29
Nodes (7): autocorrelation, confidence_bound, expected_significant, max_acf, p_value, pass, significant_lags

### Community 17 - "Community 17"
Cohesion: 0.29
Nodes (7): frequency, n_ones, n_zeros, ones_ratio, p_value, pass, z_score

### Community 19 - "Community 19"
Cohesion: 0.33
Nodes (6): chi_square, bins, df, p_value, pass, statistic

### Community 20 - "Community 20"
Cohesion: 0.33
Nodes (6): runs_test, expected_runs, n_runs, p_value, pass, z_score

### Community 22 - "Community 22"
Cohesion: 0.40
Nodes (5): Entropy and Information Analysis Plot, High vs Low Byte Distribution, Entropy per Chunk, Frequency Distribution of Values, Value Coverage

### Community 23 - "Community 23"
Cohesion: 0.40
Nodes (3): lfsr_nl_seed_uart, uart_rx, uart_tx

### Community 24 - "Community 24"
Cohesion: 0.40
Nodes (5): approx_entropy, app_entropy, expected_entropy, p_value, pass

### Community 25 - "Community 25"
Cohesion: 0.40
Nodes (4): ks_test, p_value, pass, statistic

### Community 26 - "Community 26"
Cohesion: 0.40
Nodes (5): linear_complexity, avg_entropy, expected_entropy, p_value, pass

### Community 27 - "Community 27"
Cohesion: 0.40
Nodes (5): serial_test, n_patterns, p_value, pass, statistic

### Community 28 - "Community 28"
Cohesion: 0.50
Nodes (3): Consistent Entropy per Chunk (~11.6 bits/16 max), Uniform High vs Low Byte Distribution, 97.9% Value Coverage

### Community 29 - "Community 29"
Cohesion: 0.50
Nodes (3): Conway's Game of Life, PRNG System Architecture, PRNG README

### Community 30 - "Community 30"
Cohesion: 0.50
Nodes (4): cumsum_test, max_cumsum, p_value, pass

### Community 31 - "Community 31"
Cohesion: 0.67
Nodes (3): Autocorrelation Analysis Plot, Autocorrelation Function (ACF), Observed Significant Lags Exceed Expected (13 vs ~5)

### Community 33 - "Community 33"
Cohesion: 0.67
Nodes (3): AS606 Controller, UART, UART Testbench

### Community 34 - "Community 34"
Cohesion: 0.67
Nodes (3): Collect Random Data Script, PRNG Diagnostics and UART Testing, Test A1 A4 Serial Script

### Community 36 - "Community 36"
Cohesion: 0.67
Nodes (3): Diagnostic Test Main, FPGA Diagnostic Run, FPGA Interface

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (3): Display Renderer Interface, Feather Display Main, FPGA Interface

### Community 39 - "Community 39"
Cohesion: 0.67
Nodes (3): Fingerprint Data Analysis, Fingerprint Data Collection Guide, Validation Report

### Community 42 - "Community 42"
Cohesion: 0.67
Nodes (3): 01 Distribution Overview Plot, Randomness Analysis: Uniform Data Distribution, Uniform Distribution Metrics (Mean: 32744, Skew: -0.0012, Kurtosis: -1.1996)

## Knowledge Gaps
- **140 isolated node(s):** `statistic`, `p_value`, `df`, `bins`, `pass` (+135 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **60 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Adafruit HX8357` connect `Community 1` to `Community 8`, `Community 3`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `Convert Init Script` connect `Community 8` to `Community 1`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `Load decimal values with debug output.`, `Try loading with pandas using various encoding options.`, `Load decimal values from CSV file.` to the rest of the system?**
  _186 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07311827956989247 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.13105413105413105 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14461538461538462 - nodes in this community are weakly interconnected._