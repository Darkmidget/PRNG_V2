initd = [
    0x01, # HX8357_SWRESET
    0x80 + 100 // 5, # Soft reset, then delay 100 ms
    0xB9, # HX8357D_SETC
    3,
    0xFF,
    0x83,
    0x57,
    0xFF,
    0x80 + 500 // 5, # No command, just delay 500 ms
    0xB3, # HX8357_SETRGB
    4,
    0x80,
    0x00,
    0x06,
    0x06, # 0x80 enables SDO pin (0x00 disables)
    0xB6, # HX8357D_SETCOM
    1,
    0x25, # -1.52V
    0xB0, # HX8357_SETOSC
    1,
    0x68, # Normal mode 70Hz, Idle mode 55 Hz
    0xCC, # HX8357_SETPANEL
    1,
    0x05, # BGR, Gate direction swapped
    0xB1, # HX8357_SETPWR1
    6,
    0x00, # Not deep standby
    0x15, # BT
    0x1C, # VSPR
    0x1C, # VSNR
    0x83, # AP
    0xAA, # FS
    0xC0, # HX8357D_SETSTBA
    6,
    0x50, # OPON normal
    0x50, # OPON idle
    0x01, # STBA
    0x3C, # STBA
    0x1E, # STBA
    0x08, # GEN
    0xB4, # HX8357D_SETCYC
    7,
    0x02, # NW 0x02
    0x40, # RTN
    0x00, # DIV
    0x2A, # DUM
    0x2A, # DUM
    0x0D, # GDON
    0x78, # GDOFF
    0xE0, # HX8357D_SETGAMMA
    34,
    0x02, 0x0A, 0x11, 0x1d, 0x23, 0x35, 0x41, 0x4b, 0x4b, 0x42, 0x3A, 0x27, 0x1B, 0x08, 0x09, 0x03, 0x02, 0x0A, 0x11, 0x1d, 0x23, 0x35, 0x41, 0x4b, 0x4b, 0x42, 0x3A, 0x27, 0x1B, 0x08, 0x09, 0x03, 0x00, 0x01,
    0x3A, # HX8357_COLMOD
    1,
    0x55, # 16 bit
    0x36, # HX8357_MADCTL
    1,
    0xC0,
    0x35, # HX8357_TEON
    1,
    0x00, # TW off
    0x44, # HX8357_TEARLINE
    2,
    0x00,
    0x02,
    0x11, # HX8357_SLPOUT
    0x80 + 150 // 5, # Exit Sleep, then delay 150 ms
    0x29, # HX8357_DISPON
    0x80 + 50 // 5, # Main screen turn on, delay 50 ms
    0, # END OF COMMAND LIST
]

idx = 0
rom_idx = 0
out = []
while idx < len(initd):
    cmd = initd[idx]
    if cmd == 0:
        out.append(f"init_rom[{rom_idx}] = 18'h3FFFF; // END OF SEQUENCE")
        rom_idx += 1
        break
    idx += 1
    x = initd[idx]
    numArgs = x & 0x7F
    
    if cmd != 0xFF:
        if (x & 0x80):
            val = (1 << 17) | (1 << 16) | (numArgs << 8) | cmd
            out.append(f"init_rom[{rom_idx}] = 18'h{val:05X}; // CMD 0x{cmd:02X}, wait {numArgs*5}ms")
            rom_idx += 1
            idx += 1
        else:
            val = (1 << 17) | cmd
            out.append(f"init_rom[{rom_idx}] = 18'h{val:05X}; // CMD 0x{cmd:02X}")
            rom_idx += 1
            idx += 1 # move to first arg
            for i in range(numArgs):
                arg = initd[idx + i]
                val = arg
                out.append(f"init_rom[{rom_idx}] = 18'h{val:05X}; // ARG 0x{arg:02X}")
                rom_idx += 1
            idx += numArgs # point past last arg
    else:
        if (x & 0x80):
            val = (1 << 17) | (1 << 16) | (numArgs << 8) | 0
            out.append(f"init_rom[{rom_idx}] = 18'h{val:05X}; // Delay only {numArgs*5}ms")
            rom_idx += 1
        idx += 1

print("    initial begin")
print("\n".join("        " + line for line in out))
print("    end")

