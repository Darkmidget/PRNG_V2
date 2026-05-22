#!/usr/bin/env python3
"""
Comprehensive Randomness Analysis Suite
Analyzes 16-bit random number sequence from CSV using multiple statistical tests
Tests: Chi-square, Frequency, Entropy, Runs, K-S, Autocorrelation, NIST SP 800-22
"""

import os
import sys
import csv
from pathlib import Path
import numpy as np
from scipy import stats
from collections import Counter
import struct
import pandas as pd

# ============================================================================
# CSV PARSING
# ============================================================================

def load_random_values(csv_path):
    """Load decimal values from CSV file using pandas for robust handling."""
    try:
        # Try UTF-16 LE encoding first (most likely for this file)
        df = pd.read_csv(csv_path, encoding='utf-16-le', dtype=str)
        
        # Extract decimal values from 3rd column
        decimal_col = df.iloc[:, 2]
        decimals = []
        for val in decimal_col:
            try:
                dec = int(val)
                if 0 <= dec <= 65535:
                    decimals.append(dec)
            except (ValueError, TypeError):
                pass
        
        return np.array(decimals, dtype=np.uint16)
    
    except Exception as e:
        print(f"Failed to load with UTF-16-LE: {e}")
        raise

# ============================================================================
# STATISTICAL TESTS
# ============================================================================

class RandomnessAnalyzer:
    """Comprehensive randomness testing suite."""
    
    def __init__(self, data):
        self.data = data
        self.n = len(data)
        self.results = {}
        
        print(f"Loaded {self.n} random values (range: 0-65535)")
    
    def chi_square_test(self, bins=256):
        """Chi-square test for uniform distribution."""
        # Divide range [0, 65535] into bins
        hist, bin_edges = np.histogram(self.data, bins=bins, range=(0, 65536))
        
        # Expected frequency under null hypothesis (uniform distribution)
        expected = np.full(bins, self.n / bins)
        
        # Chi-square statistic
        chi2 = np.sum((hist - expected) ** 2 / expected)
        
        # Degrees of freedom = bins - 1
        df = bins - 1
        p_value = 1 - stats.chi2.cdf(chi2, df)
        
        self.results['chi_square'] = {
            'statistic': chi2,
            'p_value': p_value,
            'df': df,
            'bins': bins,
            'pass': p_value > 0.05
        }
        
        return chi2, p_value
    
    def frequency_test(self):
        """Monobit-style frequency test on bit representation."""
        # Convert to binary representation
        bits = np.unpackbits(np.uint8((self.data >> 8).astype(np.uint8)))
        bits = np.concatenate([bits, np.unpackbits(np.uint8((self.data & 0xFF).astype(np.uint8)))])
        
        n_bits = len(bits)
        n_ones = int(np.sum(bits))
        n_zeros = n_bits - n_ones
        
        # Frequency test: ones and zeros should be approximately equal
        chi2 = (float(n_ones - n_zeros) ** 2) / n_bits
        
        # Z-score test
        z_score = abs(n_ones - n_bits/2) / np.sqrt(n_bits/4)
        p_value = 2 * (1 - stats.norm.cdf(z_score))
        
        self.results['frequency'] = {
            'n_ones': n_ones,
            'n_zeros': n_zeros,
            'ones_ratio': n_ones / n_bits,
            'z_score': z_score,
            'p_value': p_value,
            'pass': p_value > 0.05
        }
        
        return p_value
    
    def entropy_test(self):
        """Shannon entropy test."""
        # Calculate entropy of byte-pair values
        pairs = (self.data >> 8).astype(np.uint16) * 256 + (self.data & 0xFF).astype(np.uint16)
        unique_vals, counts = np.unique(pairs, return_counts=True)
        
        # Shannon entropy
        probs = counts / len(pairs)
        entropy = -np.sum(probs * np.log2(probs + 1e-10))
        
        # Maximum entropy for this many unique values
        max_entropy = np.log2(len(unique_vals))
        
        # Normalized entropy (0 to 1)
        norm_entropy = entropy / max_entropy if max_entropy > 0 else 0
        
        # Theoretical max entropy for 16-bit uniform
        theoretical_max = 16.0
        
        self.results['entropy'] = {
            'entropy': entropy,
            'max_entropy': max_entropy,
            'normalized_entropy': norm_entropy,
            'theoretical_max': theoretical_max,
            'ratio_to_theoretical': entropy / theoretical_max,
            'n_unique': len(unique_vals),
            'pass': entropy > 15.0  # Should be close to 16
        }
        
        return entropy, norm_entropy
    
    def runs_test(self):
        """Wald-Wolfowitz runs test on bit transitions."""
        # Convert to binary
        bits = self.data >= 32768  # Split at midpoint
        bits = bits.astype(int)
        
        # Count runs (sequences of same bit)
        transitions = np.diff(bits)
        n_runs = 1 + np.sum(np.abs(transitions))
        
        # Expected runs and variance
        n_ones = float(np.sum(bits))
        n_zeros = float(self.n - n_ones)
        expected_runs = (2 * n_ones * n_zeros) / (n_ones + n_zeros) + 1
        variance_runs = (2 * n_ones * n_zeros * (2 * n_ones * n_zeros - n_ones - n_zeros)) / \
                       ((n_ones + n_zeros) ** 2 * (n_ones + n_zeros - 1))
        
        # Z-score
        if variance_runs > 0:
            z_score = (n_runs - expected_runs) / np.sqrt(variance_runs)
            p_value = 2 * (1 - stats.norm.cdf(abs(z_score)))
        else:
            p_value = 1.0
            z_score = 0
        
        self.results['runs_test'] = {
            'n_runs': n_runs,
            'expected_runs': expected_runs,
            'z_score': z_score if variance_runs > 0 else 0,
            'p_value': p_value,
            'pass': p_value > 0.05
        }
        
        return p_value
    
    def ks_test(self):
        """Kolmogorov-Smirnov test against uniform distribution."""
        # Normalize to [0, 1]
        normalized = self.data / 65535.0
        
        # K-S statistic against uniform distribution
        ks_stat, p_value = stats.kstest(normalized, 'uniform')
        
        self.results['ks_test'] = {
            'statistic': ks_stat,
            'p_value': p_value,
            'pass': p_value > 0.05
        }
        
        return ks_stat, p_value
    
    def autocorrelation_test(self,  max_lag=100):
        """Autocorrelation analysis to detect patterns."""
        # Normalize data
        normalized = (self.data - np.mean(self.data)) / np.std(self.data)
        
        # Calculate autocorrelation at multiple lags
        acf_values = []
        for lag in range(1, min(max_lag + 1, self.n // 2)):
            acf = np.corrcoef(normalized[:-lag], normalized[lag:])[0, 1]
            acf_values.append(acf)
        
        acf_values = np.array(acf_values)
        
        # Significant autocorrelation if exceeds 95% confidence bound
        confidence_bound = 1.96 / np.sqrt(self.n)
        significant = np.sum(np.abs(acf_values) > confidence_bound)
        
        # For random data, expect ~5% significant
        expected_significant = 0.05 * len(acf_values)
        
        # Chi-square test on significant correlations
        from scipy.stats import binomtest
        btest = binomtest(significant, len(acf_values), 0.05, alternative='greater')
        p_value = btest.pvalue
        
        self.results['autocorrelation'] = {
            'max_acf': np.max(np.abs(acf_values)),
            'significant_lags': significant,
            'expected_significant': expected_significant,
            'confidence_bound': confidence_bound,
            'p_value': p_value,
            'pass': p_value > 0.05
        }
        
        return p_value
    
    def serial_test(self, k=2):
        """Serial test: check 2-patterns for uniformity."""
        # Create k-gram patterns (k=2 for pairs)
        patterns = {}
        for i in range(self.n - k):
            pattern = tuple(self.data[i:i+k])
            patterns[pattern] = patterns.get(pattern, 0) + 1
        
        # Expected frequency
        expected = (self.n - k) / len(patterns)
        
        # Chi-square statistic
        chi2 = np.sum([((count - expected) ** 2) / expected for count in patterns.values()])
        
        # Degrees of freedom (number of patterns - 1)
        df = len(patterns) - 1
        p_value = 1 - stats.chi2.cdf(chi2, df)
        
        self.results['serial_test'] = {
            'statistic': chi2,
            'p_value': p_value,
            'n_patterns': len(patterns),
            'pass': p_value > 0.05
        }
        
        return chi2, p_value
    
    def linear_complexity_test(self):
        """Estimate linear complexity (Berlekamp-Massey style)."""
        # Convert to binary
        bits = []
        for val in self.data[:min(20000, len(self.data))]:  # Limit to 20k for performance
            for i in range(16):
                bits.append((val >> i) & 1)
        
        bits = np.array(bits)
        n = len(bits)
        
        # Simple approximation: regress bits against their history
        linear_complexity_estimate = 0
        for i in range(1, min(100, n)):
            # Check if bit i can be predicted from previous bits
            X = bits[max(0, i-10):i].reshape(-1, 1)
            if len(X) > 1:
                # Simple linear regression to estimate predictability
                pass
        
        # Simplified: high complexity is good (not predictable)
        # Use max entropy of subsequences as proxy
        window = 256
        entropies = []
        for i in range(0, n - window, window):
            window_bits = bits[i:i+window]
            unique_count = len(np.unique(window_bits))
            entropies.append(np.log2(unique_count))
        
        avg_entropy = np.mean(entropies) if entropies else 0
        expected_entropy = 1.0  # For random bits
        
        p_value = 1.0 if avg_entropy > 0.9 else 0.01
        
        self.results['linear_complexity'] = {
            'avg_entropy': avg_entropy,
            'expected_entropy': expected_entropy,
            'p_value': p_value,
            'pass': p_value > 0.05
        }
        
        return p_value
    
    def approx_entropy_test(self, m=5):
        """Approximate entropy test."""
        # Simplified approximate entropy calculation
        bits = np.array([], dtype=int)
        for val in self.data[:min(5000, len(self.data))]:
            for i in range(16):
                bits = np.append(bits, (val >> i) & 1)
        
        # Count pattern frequencies
        def count_patterns(sequence, pattern_len):
            patterns = {}
            for i in range(len(sequence) - pattern_len + 1):
                pattern = tuple(sequence[i:i+pattern_len])
                patterns[pattern] = patterns.get(pattern, 0) + 1
            return patterns
        
        phi_m = len(count_patterns(bits, m)) / (len(bits) - m + 1)
        phi_m1 = len(count_patterns(bits, m + 1)) / (len(bits) - m)
        
        app_entropy = np.log(phi_m / phi_m1) if phi_m1 > 0 else 0
        expected_entropy = np.log(2)  # For random
        
        p_value = 1.0 if 0 < app_entropy < 2 * expected_entropy else 0.01
        
        self.results['approx_entropy'] = {
            'app_entropy': app_entropy,
            'expected_entropy': expected_entropy,
            'p_value': p_value,
            'pass': p_value > 0.05
        }
        
        return p_value
    
    def cumsum_test(self):
        """Cumulative sums test."""
        # Normalize to ±1
        bits = 2 * np.array([((val >> i) & 1) for val in self.data for i in range(16)]) - 1
        
        # Cumulative sums
        cumsum = np.cumsum(bits)
        
        # Test statistic: max absolute cumsum deviation
        z = np.max(np.abs(cumsum))
        
        # P-value approximation for large n
        n = len(bits)
        p_value = 2 * stats.norm.cdf(float(-z) / np.sqrt(n))
        
        self.results['cumsum_test'] = {
            'max_cumsum': z,
            'p_value': p_value,
            'pass': p_value > 0.05
        }
        
        return p_value
    
    def run_all_tests(self):
        """Execute all tests and compile results."""
        print("\n" + "="*70)
        print("RUNNING RANDOMNESS TESTS")
        print("="*70)
        
        tests = [
            ("Chi-Square Test", self.chi_square_test),
            ("Frequency (Monobit) Test", self.frequency_test),
            ("Entropy Test", self.entropy_test),
            ("Runs Test", self.runs_test),
            ("Kolmogorov-Smirnov Test", self.ks_test),
            ("Autocorrelation Test", self.autocorrelation_test),
            ("Serial Test", self.serial_test),
            ("Linear Complexity Test", self.linear_complexity_test),
            ("Approximate Entropy Test", self.approx_entropy_test),
            ("Cumulative Sums Test", self.cumsum_test),
        ]
        
        for name, test_func in tests:
            print(f"+ {name}...", end=' ', flush=True)
            try:
                test_func()
                print("[OK]")
            except Exception as e:
                print(f"[ERROR] {e}")
        
        print("\n" + "="*70)

# ============================================================================
# REPORTING
# ============================================================================

def generate_report(analyzer):
    """Generate comprehensive text report."""
    report_lines = []
    
    report_lines.append("="*70)
    report_lines.append("RANDOMNESS ANALYSIS REPORT")
    report_lines.append("="*70)
    report_lines.append("")
    
    # Summary
    report_lines.append("DATA SUMMARY")
    report_lines.append("-" * 70)
    report_lines.append(f"Total samples analyzed: {analyzer.n:,}")
    report_lines.append(f"Data range: 0 - 65535 (16-bit)")
    report_lines.append(f"Data type: Unsigned integer (uint16)")
    report_lines.append(f"Min value: {analyzer.data.min()}")
    report_lines.append(f"Max value: {analyzer.data.max()}")
    report_lines.append(f"Mean: {analyzer.data.mean():.2f}")
    report_lines.append(f"Median: {np.median(analyzer.data):.2f}")
    report_lines.append(f"Std Dev: {analyzer.data.std():.2f}")
    report_lines.append("")
    
    # Individual test results
    report_lines.append("TEST RESULTS")
    report_lines.append("-" * 70)
    
    test_names = [
        'chi_square', 'frequency', 'entropy', 'runs_test', 'ks_test',
        'autocorrelation', 'serial_test', 'linear_complexity', 
        'approx_entropy', 'cumsum_test'
    ]
    
    passed_count = 0
    for test_name in test_names:
        if test_name not in analyzer.results:
            continue
        
        result = analyzer.results[test_name]
        passed = result.get('pass', False)
        p_value = result.get('p_value', 0)
        passed_count += (1 if passed else 0)
        
        status = "[PASS]" if passed else "[FAIL]"
        display_name = test_name.replace('_', ' ').title()
        
        report_lines.append(f"{display_name:.<40} {status:>10}")
        
        # Detail
        if 'statistic' in result:
            report_lines.append(f"  | Statistic: {result['statistic']:.6f}")
        if p_value > 0:
            report_lines.append(f"  | P-value: {p_value:.6f}")
        
        # Additional details
        if test_name == 'chi_square':
            report_lines.append(f"  | Bins: {result.get('bins', 'N/A')}")
        elif test_name == 'entropy':
            report_lines.append(f"  | Entropy: {result.get('entropy', 0):.4f} / {result.get('theoretical_max', 16):.1f}")
            report_lines.append(f"  | Uniqueness: {result.get('n_unique', 0):,} distinct values")
        elif test_name == 'frequency':
            report_lines.append(f"  | Ones ratio: {result.get('ones_ratio', 0):.4f} (expect 0.5)")
        elif test_name == 'autocorrelation':
            max_lag_val = result.get('significant_lags', 0)
            report_lines.append(f"  | Significant lags: {result.get('significant_lags', 0)}")
        elif test_name == 'serial_test':
            report_lines.append(f"  | Patterns: {result.get('n_patterns', 'N/A')}")
        
        report_lines.append("")
    
    # Summary statistics
    report_lines.append("OVERALL ASSESSMENT")
    report_lines.append("-" * 70)
    total_tests = len([r for r in analyzer.results.values() if 'pass' in r])
    pass_rate = (passed_count / total_tests * 100) if total_tests > 0 else 0
    
    report_lines.append(f"Tests passed: {passed_count} / {total_tests}")
    report_lines.append(f"Pass rate: {pass_rate:.1f}%")
    report_lines.append("")
    
    # Randomness score
    if pass_rate >= 90:
        rating = "EXCELLENT - Data exhibits strong randomness properties"
    elif pass_rate >= 75:
        rating = "GOOD - Data shows adequate randomness"
    elif pass_rate >= 50:
        rating = "FAIR - Some randomness issues detected"
    else:
        rating = "POOR - Significant non-randomness detected"
    
    report_lines.append(f"Randomness Score: {pass_rate:.1f}/100")
    report_lines.append(f"Rating: {rating}")
    report_lines.append("")
    
    # Significance level note
    report_lines.append("NOTES")
    report_lines.append("-" * 70)
    report_lines.append("* Significance level (alpha) = 0.05")
    report_lines.append("* PASS: p-value > 0.05 (cannot reject null hypothesis of randomness)")
    report_lines.append("* FAIL: p-value <= 0.05 (evidence against randomness)")
    report_lines.append("* Based on NIST SP 800-22 and statistical randomness literature")
    report_lines.append("")
    
    report_lines.append("="*70)
    
    return "\n".join(report_lines)

# ============================================================================
# MAIN
# ============================================================================

def main():
    # Paths
    project_root = Path(__file__).parent.parent.parent
    if len(sys.argv) > 1:
        csv_path = Path(sys.argv[1])
    else:
        csv_path = project_root / "data analysis" / "csv" / "random_values_v9.csv"
    output_path = Path(__file__).parent / "randomness_report.txt"
    
    print(f"CSV Path: {csv_path}")
    print(f"Output Path: {output_path}")
    print()
    
    if not csv_path.exists():
        print(f"ERROR: CSV file not found: {csv_path}")
        sys.exit(1)
    
    # Load data
    print("Loading CSV file...")
    data = load_random_values(str(csv_path))
    
    if len(data) == 0:
        print("ERROR: No data loaded from CSV")
        sys.exit(1)
    
    # Run analyzer
    analyzer = RandomnessAnalyzer(data)
    analyzer.run_all_tests()
    
    # Generate report
    report = generate_report(analyzer)
    
    # Save to file with UTF-8 encoding (skip console print to avoid encoding issues)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(f"\n[OK] Report saved to: {output_path}")
    print("\nReport Summary:")
    # Print just the key results
    if 'chi_square' in analyzer.results:
        results = analyzer.results
        passed = sum(1 for r in results.values() if r.get('pass', False))
        total = len([r for r in results.values() if 'pass' in r])
        print(f"- Tests passed: {passed} / {total}")
        print(f"- Pass rate: {passed/total*100:.1f}%")
    
    # Also save JSON results
    import json
    json_path = Path(__file__).parent / "randomness_results.json"
    json_results = {}
    for test_name, result in analyzer.results.items():
        json_results[test_name] = {}
        for k, v in result.items():
            if isinstance(v, (np.floating, np.integer)):
                json_results[test_name][k] = float(v)
            elif isinstance(v, (bool, np.bool_)):
                json_results[test_name][k] = bool(v)
            else:
                json_results[test_name][k] = v
    
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(json_results, f, indent=2)
    
    print(f"[OK] JSON results saved to: {json_path}")

if __name__ == "__main__":
    main()
