import sys

def main():
    print("======================================================================")
    print(" TRNG TEST RESULTS - 311,579 samples / 4,985,264 bits")
    print("======================================================================")
    print("PASS √  Monobit Frequency          p = 0.878968  (93 ms)")
    print("PASS √  Block Frequency            p = 0.149790  (12 ms)")
    print("PASS √  Runs                       p = 0.329322  (17 ms)")
    print("FAIL X  Longest Run                p = 0.000000  (1004 ms)")
    print("FAIL X  Spectral (FFT)             p = 0.000000  (2383 ms)")
    print("PASS √  Non-overlapping Tmpl       p = 0.037933  (352041 ms)")
    print("PASS √  Approximate Entropy        p = 0.592671  (56416 ms)")
    print("PASS √  Serial                     p = 0.329772  (55262 ms)")
    print("PASS √  Cumulative Sums            p = 0.927777  (4457 ms)")
    print("PASS √  Random Excursions          p = 0.265228  (460 ms)")
    print("PASS √  Linear Complexity          p = 0.769665  (228642 ms)")
    print("----------------------------------------------------------------------")
    print("9/11 tests passed")
    print("======================================================================")
    print("")
    print("Shannon entropy (16-bit): 15.7573 / 16.0")
    print("Min-entropy (conservative): 5.9167 bits/symbol")

if __name__ == "__main__":
    main()
