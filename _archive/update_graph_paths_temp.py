import os
import glob

# For JSON/quoted contexts
quoted_replacements = [
    # Legacy files -> Archive
    ('"src/', '"_archive/legacy_microcontroller/src/'),
    ('"Adafruit_HX8357.cpp', '"_archive/legacy_microcontroller/Adafruit_HX8357.cpp'),
    ('"Adafruit_HX8357.h', '"_archive/legacy_microcontroller/Adafruit_HX8357.h'),
    ('"esp32_fingerprint/', '"_archive/legacy_microcontroller/esp32_fingerprint/'),
    ('"feather_display/', '"_archive/legacy_microcontroller/feather_display/'),
    ('"featherwing_m4_alt_rxtx/', '"_archive/legacy_microcontroller/featherwing_m4_alt_rxtx/'),
    ('"platformio.ini', '"_archive/legacy_microcontroller/platformio.ini'),

    # Verilog files -> Root
    ('"verilog/src/', '"src/'),
    ('"verilog/testbench/', '"testbench/'),
    ('"verilog/constraints/', '"constraints/'),
    ('"verilog/scripts/', '"scripts/'),
    ('"verilog/README.md', '"_archive/verilog_README.md'),
    ('"verilog/uart_loopback.v', '"_archive/uart_loopback.v'),
    ('"verilog/', '"'),

    # Moved scripts -> Proper folders
    ('"query.py', '"graphify-out/query.py'),
    ('"filter_detect.py', '"graphify-out/filter_detect.py'),
    ('"get_stats.py', '"graphify-out/get_stats.py'),
    ('"artix7_parts.txt', '"scripts/hardware_info/artix7_parts.txt'),
    ('"parts.txt', '"scripts/hardware_info/parts.txt'),
    ('"dump_artix7.tcl', '"scripts/hardware_info/dump_artix7.tcl'),
    ('"dump_parts.tcl', '"scripts/hardware_info/dump_parts.tcl'),
    ('"find_flash.tcl', '"scripts/hardware_info/find_flash.tcl'),
    ('"find_hw_flash.tcl', '"scripts/hardware_info/find_hw_flash.tcl'),
    ('"find_offline.tcl', '"scripts/hardware_info/find_offline.tcl'),
    ('"fpga_main.bit', '"build/bitstreams/fpga_main.bit'),
    ('"fpga_main.mcs', '"build/bitstreams/fpga_main.mcs'),
    ('"fpga_main.prm', '"build/bitstreams/fpga_main.prm'),
    ('"ring_osc.bit', '"build/bitstreams/ring_osc.bit'),
    ('"reaction_game_tb_sim.wdb', '"testbench/sim_waves/reaction_game_tb_sim.wdb'),
    ('"tb_game_of_life_sim.wdb', '"testbench/sim_waves/tb_game_of_life_sim.wdb'),
    ('"tb_hx8357d_controller_sim.wdb', '"testbench/sim_waves/tb_hx8357d_controller_sim.wdb'),
    ('"tb_lfsr_nl_seed_uart_sim.wdb', '"testbench/sim_waves/tb_lfsr_nl_seed_uart_sim.wdb'),
    ('"vivado.jou', '"build/logs/vivado.jou'),
    ('"vivado.log', '"build/logs/vivado.log'),
    ('"dfx_runtime.txt', '"_archive/dfx_runtime.txt'),
]

# For plain text/markdown contexts
unquoted_replacements = [
    # Legacy files -> Archive
    ('Adafruit_HX8357.cpp', '_archive/legacy_microcontroller/Adafruit_HX8357.cpp'),
    ('Adafruit_HX8357.h', '_archive/legacy_microcontroller/Adafruit_HX8357.h'),
    ('platformio.ini', '_archive/legacy_microcontroller/platformio.ini'),
    ('esp32_fingerprint/', '_archive/legacy_microcontroller/esp32_fingerprint/'),
    ('feather_display/', '_archive/legacy_microcontroller/feather_display/'),
    ('featherwing_m4_alt_rxtx/', '_archive/legacy_microcontroller/featherwing_m4_alt_rxtx/'),

    # Verilog files -> Root
    ('verilog/src/', 'src/'),
    ('verilog/testbench/', 'testbench/'),
    ('verilog/constraints/', 'constraints/'),
    ('verilog/scripts/', 'scripts/'),
    ('verilog/README.md', '_archive/verilog_README.md'),
    ('verilog/uart_loopback.v', '_archive/uart_loopback.v'),
    ('verilog/', ''),

    # Moved scripts -> Proper folders
    ('query.py', 'graphify-out/query.py'),
    ('filter_detect.py', 'graphify-out/filter_detect.py'),
    ('get_stats.py', 'graphify-out/get_stats.py'),
    ('artix7_parts.txt', 'scripts/hardware_info/artix7_parts.txt'),
    ('parts.txt', 'scripts/hardware_info/parts.txt'),
    ('dump_artix7.tcl', 'scripts/hardware_info/dump_artix7.tcl'),
    ('dump_parts.tcl', 'scripts/hardware_info/dump_parts.tcl'),
    ('find_flash.tcl', 'scripts/hardware_info/find_flash.tcl'),
    ('find_hw_flash.tcl', 'scripts/hardware_info/find_hw_flash.tcl'),
    ('find_offline.tcl', 'scripts/hardware_info/find_offline.tcl'),
    ('fpga_main.bit', 'build/bitstreams/fpga_main.bit'),
    ('fpga_main.mcs', 'build/bitstreams/fpga_main.mcs'),
    ('fpga_main.prm', 'build/bitstreams/fpga_main.prm'),
    ('ring_osc.bit', 'build/bitstreams/ring_osc.bit'),
    ('reaction_game_tb_sim.wdb', 'testbench/sim_waves/reaction_game_tb_sim.wdb'),
    ('tb_game_of_life_sim.wdb', 'testbench/sim_waves/tb_game_of_life_sim.wdb'),
    ('tb_hx8357d_controller_sim.wdb', 'testbench/sim_waves/tb_hx8357d_controller_sim.wdb'),
    ('tb_lfsr_nl_seed_uart_sim.wdb', 'testbench/sim_waves/tb_lfsr_nl_seed_uart_sim.wdb'),
    ('vivado.jou', 'build/logs/vivado.jou'),
    ('vivado.log', 'build/logs/vivado.log'),
    ('dfx_runtime.txt', '_archive/dfx_runtime.txt'),
]

# Files to update in graphify-out
files_to_update = [
    ('graphify-out/graph.json', True),
    ('graphify-out/.graphify_extract.json', True),
    ('graphify-out/.graphify_detect.json', True),
    ('graphify-out/.graphify_analysis.json', True),
    ('graphify-out/manifest.json', True),
    ('graphify-out/cost.json', True),
    ('graphify-out/graph.html', False),
    ('graphify-out/GRAPH_REPORT.md', False),
]

def update_files():
    print(">> Updating paths in Graphify files...")
    for pattern, is_json in files_to_update:
        for filepath in glob.glob(pattern):
            if os.path.exists(filepath):
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    original_content = content
                    
                    # Apply quoted replacements first (specifically for JSON structures)
                    for old_str, new_str in quoted_replacements:
                        content = content.replace(old_str, new_str)
                    
                    # Apply unquoted replacements for free text / markdown / HTML contexts
                    for old_str, new_str in unquoted_replacements:
                        # Make sure not to double-replace already replaced paths
                        content = content.replace(old_str, new_str)
                    
                    if content != original_content:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(content)
                        print(f"   + Updated: {filepath}")
                except Exception as e:
                    print(f"   X Error updating {filepath}: {e}")

if __name__ == '__main__':
    update_files()
