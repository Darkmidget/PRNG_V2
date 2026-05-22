# 100,000 Random Number Collection - FINAL STEPS

## Status: Ready for Data Collection ✓

You now have everything needed to collect 100,000 random numbers from your Ring Oscillator FPGA!

---

## QUICK START

### Prerequisites Checklist
- [ ] FPGA connected to USB (should show COM4 in Device Manager)
- [ ] FPGA programmed with `ring_osc.bit` bitstream
- [ ] PowerShell execution policy allows scripts

### Step-by-Step Instructions

#### Step 1: Enable FPGA Oscillator
1. Look at your CMOD A7 board with extension board
2. Find SW[0] on the extension board
3. **Slide SW[0] to the RIGHT** to enable the oscillator
4. You should see LED[0] light up on the CmodA7 board

**Result**: FPGA is now generating random numbers continuously via UART

#### Step 2: Check COM Port (if not COM4)
Run in PowerShell:
```powershell
Get-COMPort
# or check Device Manager -> Ports (COM & LPT)
```
Make note of the COM port number.

#### Step 3: Run Collection Script
Open PowerShell and navigate to the template directory:

```powershell
cd "g:\My Drive\0 - SUTD\Term 6\DSL\Project\verilog\FPGA-Vivado-Verilog-VS-code-Project-Template"
```

Run the collection script:
```powershell
.\collect_random_100k.ps1
```

or if your COM port is different:
```powershell
.\collect_random_100k.ps1 -ComPort COM5 -Count 100000
```

#### Step 4: Wait for Collection (~6 seconds)
The script will output progress:
```
========== FPGA RANDOM DATA COLLECTOR ==========
COM Port:   COM4 @ 115200 baud
Target:     100000 samples
Output:     random_data_100k.csv
=============================================

[1/3] Opening serial connection...
[OK] Connected to COM4

[2/3] Collecting samples (this will take ~1 second)...
  10% complete (10000 samples)
  20% complete (20000 samples)
  ...
  100% complete (100000 samples)

[3/3] Saving to CSV file...

========== COMPLETE ==========
Samples:     100000 (100%)
Time:        5.87s
Rate:        17032 samples/sec
File Size:   1.2 MB
Output:      random_data_100k.csv
=============================

Sample data (first 5 rows):
 Index HexValue DecimalValue Timestamp
 ----- -------- ------------ ---------
     1 8C5F     35935        2026-04-04 21:25:30.123
     2 F2E1     62177        2026-04-04 21:25:30.175
     3 1D7A      7546        2026-04-04 21:25:30.227
     4 D8BC     55484        2026-04-04 21:25:30.279
     5 A2E3     41699        2026-04-04 21:25:30.331

✓ Collection COMPLETE - 100,000 random numbers in random_data_100k.csv!
```

#### Step 5: Verify CSV File
The file `random_data_100k.csv` will be created in the template directory with:
- **100,000 rows** of data (plus header)
- **Columns**: Index, HexValue, DecimalValue, Timestamp
- **Size**: ~1.2 MB
- **Format**: Standard CSV, readable in Excel/Python/etc

---

## CSV Format Example
```
Index,HexValue,DecimalValue,Timestamp
1,8C5F,35935,2026-04-04 21:25:30.123
2,F2E1,62177,2026-04-04 21:25:30.175
3,1D7A,7546,2026-04-04 21:25:30.227
...
100000,7BC2,31682,2026-04-04 21:25:36.011
```

---

## If Build is Needed (ring_osc.bit doesn't exist)

### Option A: Vivado GUI (Recommended)
1. Open Vivado
2. Open project: `g:\My Drive\0...\build\cmod_a7_project.xpr`
3. In Flow Navigator: Click "Generate Bitstream"
4. Wait 10-15 minutes
5. Bitstream will be at: `build/cmod_a7_project.runs/impl_1/ring_osc.bit`

### Option B: Jupyter Notebook
The original `RingOsc_shared.ipynb` can build via `%vivado` magic commands.

---

## Troubleshooting

### "Cannot open COM4"
- Check FPGA is connected to USB
- Run `Get-COMPort` to find correct COM port
- Try different COM numbers

### "No data after 5 seconds"
- Confirm SW[0] is slid to the RIGHT
- Check LED[0] is lit (shows oscillator enabled)
- Verify bitstream is loaded (LED[1] should blink ~0.7 Hz)
- Try resetting FPGA with SW[1]

### "Exit Code 1" Error
- Serial port may be in use by another application
- Close any terminal programs
- Restart PowerShell

### File encoding issues
- The script handles CSV UTF-8 automatically
- Compatible with Excel, Python, MATLAB, R

---

## What's Inside the CSV

Each row contains:
- **Index**: 1-100000 (sample number)
- **HexValue**: 4-digit hex value (0000-FFFF)
- **DecimalValue**: 0-65535 (converted int)
- **Timestamp**: When sample was received (useful for timing analysis)

The 16-bit random values come directly from the Ring Oscillator LFSR with entropy mixing!

---

## Next: Process Your Data

Now that you have 100,000 random numbers, you can:

### Python Analysis
```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('random_data_100k.csv')

# Statistical analysis
print(df['DecimalValue'].describe())

# Plot histogram
plt.hist(df['DecimalValue'], bins=256)
plt.title('Distribution of Random Values')
plt.show()
```

### Excel Analysis
1. Open `random_data_100k.csv` in Excel
2. Create pivot tables
3. Plot histograms
4. Run statistical tests

---

## Success Criteria ✓

- [ ] 100,000 samples collected
- [ ] CSV file created: ~1.2 MB
- [ ] All 100,000 rows present
- [ ] Hex values in range 0000-FFFF
- [ ] Decimal values in range 0-65535
- [ ] No duplicate consecutive values
- [ ] Collection completed in <10 seconds

**Status**: READY TO EXECUTE - All components prepared!

Run the PowerShell script now to collect 100,000 random numbers.
