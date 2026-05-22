#!/usr/bin/env python3
"""Debug CSV structure."""

import os

csv_path = r"data analysis\random_values_ojas_flsr.csv"

with open(csv_path, 'rb') as f:
    data = f.read()

# Skip BOM
if data.startswith(b'\xef\xbb\xbf'):
    data = data[3:]

print(f"Total bytes: {len(data)}")
print(f"First 500 bytes (hex):")
print(data[:500].hex())

print(f"\n\nChecking for common line endings:")
crlf = b'\x0d\x0a'
lf = b'\x0a'
cr = b'\x0d'
utf16_crlf = b'\x0d\x00\x0a\x00'
utf16_lf = b'\x0a\x00'

print(f"  CRLF (0D0A): {data.count(crlf)}")
print(f"  LF (0A): {data.count(lf)}")
print(f"  CR (0D): {data.count(cr)}")
print(f"  UTF-16 LE CRLF: {data.count(utf16_crlf)}")
print(f"  UTF-16 LE LF: {data.count(utf16_lf)}")

# Let's try to decode just the first part
print(f"\nFirst 500 characters decoded:")
text = data[:2000].decode('utf-16-le', errors='replace')
print(repr(text))
