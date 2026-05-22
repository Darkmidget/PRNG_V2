#!/usr/bin/env python3
"""
Visualization Script for Randomness Analysis
Creates plots and visualizations of the random number data and test results
"""

import os
import sys
import json
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from scipy import stats
import warnings

warnings.filterwarnings('ignore')

# ============================================================================
# DATA LOADING
# ============================================================================

def load_random_values(csv_path):
    """Load decimal values from CSV file."""
    df = pd.read_csv(csv_path, encoding='utf-16-le', dtype=str)
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

def load_test_results(json_path):
    """Load test results from JSON."""
    with open(json_path, 'r', encoding='utf-8') as f:
        return json.load(f)

# ============================================================================
# PLOT FUNCTIONS
# ============================================================================

def plot_distribution_overview(data):
    """Create comprehensive distribution overview."""
    fig = plt.figure(figsize=(16, 10))
    gs = gridspec.GridSpec(3, 3, figure=fig, hspace=0.35, wspace=0.3)
    
    # 1. Histogram
    ax1 = fig.add_subplot(gs[0, :2])
    ax1.hist(data, bins=256, color='steelblue', edgecolor='black', alpha=0.7)
    ax1.axvline(data.mean(), color='red', linestyle='--', linewidth=2, label=f'Mean: {data.mean():.1f}')
    ax1.axvline(np.median(data), color='green', linestyle='--', linewidth=2, label=f'Median: {np.median(data):.1f}')
    ax1.set_xlabel('Random Value (0-65535)')
    ax1.set_ylabel('Frequency')
    ax1.set_title('Distribution of Random Values (256 Bins)')
    ax1.legend()
    ax1.grid(axis='y', alpha=0.3)
    
    # 2. Statistics box
    ax2 = fig.add_subplot(gs[0, 2])
    ax2.axis('off')
    stats_text = f"""
    STATISTICS
    
    Samples: {len(data):,}
    Min: {data.min()}
    Max: {data.max()}
    Mean: {data.mean():.2f}
    Median: {np.median(data):.2f}
    StdDev: {data.std():.2f}
    Skewness: {stats.skew(data):.4f}
    Kurtosis: {stats.kurtosis(data):.4f}
    """
    ax2.text(0.1, 0.5, stats_text, fontfamily='monospace', fontsize=10,
             verticalalignment='center', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    # 3. CDF
    ax3 = fig.add_subplot(gs[1, 0])
    sorted_data = np.sort(data)
    cdf = np.arange(1, len(sorted_data) + 1) / len(sorted_data)
    ax3.plot(sorted_data, cdf, linewidth=2, color='darkblue')
    ax3.set_xlabel('Value')
    ax3.set_ylabel('Cumulative Probability')
    ax3.set_title('Cumulative Distribution Function (CDF)')
    ax3.grid(alpha=0.3)
    
    # 4. Q-Q Plot
    ax4 = fig.add_subplot(gs[1, 1])
    stats.probplot(data, dist="uniform", plot=ax4)
    ax4.set_title('Q-Q Plot (vs Uniform Distribution)')
    ax4.grid(alpha=0.3)
    
    # 5. Box plot
    ax5 = fig.add_subplot(gs[1, 2])
    bp = ax5.boxplot(data, vert=True, patch_artist=True)
    bp['boxes'][0].set_facecolor('lightblue')
    ax5.set_ylabel('Value')
    ax5.set_title('Box Plot')
    ax5.grid(axis='y', alpha=0.3)
    
    # 6. Histogram (64 bins for detail)
    ax6 = fig.add_subplot(gs[2, 0])
    ax6.hist(data, bins=64, color='coral', edgecolor='black', alpha=0.7)
    ax6.set_xlabel('Value')
    ax6.set_ylabel('Frequency')
    ax6.set_title('Distribution (64 Bins - Detail View)')
    ax6.grid(axis='y', alpha=0.3)
    
    # 7. Bit distribution
    ax7 = fig.add_subplot(gs[2, 1])
    all_bits = []
    for val in data:
        for i in range(16):
            all_bits.append((val >> i) & 1)
    bit_counts = [sum(1 for b in all_bits if b == 1), sum(1 for b in all_bits if b == 0)]
    colors = ['#ff9999', '#66b3ff']
    ax7.bar(['Ones', 'Zeros'], bit_counts, color=colors, edgecolor='black')
    ax7.set_ylabel('Count')
    ax7.set_title('Bit Distribution (All 16 Bits)')
    ratio = bit_counts[0] / sum(bit_counts)
    ax7.text(0.5, max(bit_counts) * 0.5, f'Ratio: {ratio:.4f}\n(expect 0.5)', 
             ha='center', fontsize=10, bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.5))
    
    # 8. Running mean
    ax8 = fig.add_subplot(gs[2, 2])
    window_size = max(100, len(data) // 1000)
    running_mean = np.convolve(data, np.ones(window_size)/window_size, mode='valid')
    ax8.plot(running_mean, linewidth=1, color='darkgreen')
    ax8.axhline(data.mean(), color='red', linestyle='--', linewidth=2, label='Overall Mean')
    ax8.set_xlabel('Sample Index')
    ax8.set_ylabel('Running Mean')
    ax8.set_title(f'Running Mean (window={window_size})')
    ax8.legend()
    ax8.grid(alpha=0.3)
    
    plt.suptitle('Randomness Analysis: Data Distribution Overview', fontsize=16, fontweight='bold', y=0.995)
    return fig

def plot_test_results(results):
    """Visualize test results."""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('Randomness Test Results Summary', fontsize=16, fontweight='bold')
    
    # Extract test names and p-values
    test_names = []
    p_values = []
    pass_status = []
    
    for test_name in ['chi_square', 'frequency', 'entropy', 'runs_test', 'ks_test',
                      'autocorrelation', 'serial_test', 'linear_complexity', 
                      'approx_entropy', 'cumsum_test']:
        if test_name in results:
            result = results[test_name]
            p_val = result.get('p_value', 0)
            p_values.append(p_val)
            test_names.append(test_name.replace('_', ' ').title())
            pass_status.append(1 if p_val > 0.05 else 0)
    
    # 1. P-value bar chart
    ax1 = axes[0, 0]
    colors = ['green' if p > 0.05 else 'red' for p in p_values]
    bars = ax1.barh(test_names, p_values, color=colors, edgecolor='black', alpha=0.7)
    ax1.axvline(0.05, color='black', linestyle='--', linewidth=2, label='Significance (0.05)')
    ax1.set_xlabel('P-value')
    ax1.set_title('P-values by Test')
    ax1.legend()
    ax1.grid(axis='x', alpha=0.3)
    
    # 2. Pass/Fail summary
    ax2 = axes[0, 1]
    passed = sum(pass_status)
    failed = len(pass_status) - passed
    colors_pie = ['#66b3ff', '#ff9999']
    wedges, texts, autotexts = ax2.pie([passed, failed], labels=['Passed', 'Failed'], 
                                         autopct='%1.1f%%', colors=colors_pie, startangle=90)
    ax2.set_title(f'Test Results: {passed}/{len(pass_status)} Passed')
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
    
    # 3. P-value distribution
    ax3 = axes[1, 0]
    ax3.hist(p_values, bins=15, color='steelblue', edgecolor='black', alpha=0.7)
    ax3.axvline(0.05, color='red', linestyle='--', linewidth=2, label='Threshold')
    ax3.set_xlabel('P-value')
    ax3.set_ylabel('Frequency')
    ax3.set_title('Distribution of P-values')
    ax3.legend()
    ax3.grid(axis='y', alpha=0.3)
    
    # 4. Test details table
    ax4 = axes[1, 1]
    ax4.axis('off')
    
    # Create summary table
    table_data = []
    for i, test in enumerate(test_names):
        status = 'PASS' if pass_status[i] else 'FAIL'
        p_val = p_values[i]
        table_data.append([test, f'{p_val:.4f}', status])
    
    table = ax4.table(cellText=table_data,
                      colLabels=['Test Name', 'P-value', 'Status'],
                      cellLoc='center',
                      loc='center',
                      colWidths=[0.4, 0.3, 0.3])
    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 1.8)
    
    # Color the header
    for i in range(3):
        table[(0, i)].set_facecolor('#4472C4')
        table[(0, i)].set_text_props(weight='bold', color='white')
    
    # Color the status cells
    for i in range(len(table_data)):
        if table_data[i][2] == 'PASS':
            table[(i+1, 2)].set_facecolor('#90EE90')
        else:
            table[(i+1, 2)].set_facecolor('#FFB6C6')
    
    plt.tight_layout()
    return fig

def plot_autocorrelation(data, max_lag=100):
    """Plot autocorrelation analysis."""
    fig, axes = plt.subplots(2, 1, figsize=(14, 8))
    fig.suptitle('Autocorrelation Analysis', fontsize=16, fontweight='bold')
    
    # Normalize data
    normalized = (data - np.mean(data)) / np.std(data)
    
    # Calculate autocorrelation at multiple lags
    acf_values = []
    for lag in range(1, max_lag + 1):
        acf = np.corrcoef(normalized[:-lag], normalized[lag:])[0, 1]
        acf_values.append(acf)
    
    acf_values = np.array(acf_values)
    
    # 1. Autocorrelation plot
    ax1 = axes[0]
    ax1.bar(range(1, max_lag + 1), acf_values, color='steelblue', edgecolor='black', alpha=0.7)
    
    # Confidence bounds (95%)
    confidence_bound = 1.96 / np.sqrt(len(data))
    ax1.axhline(confidence_bound, color='red', linestyle='--', linewidth=2, label='95% Confidence Bound')
    ax1.axhline(-confidence_bound, color='red', linestyle='--', linewidth=2)
    ax1.axhline(0, color='black', linestyle='-', linewidth=0.5)
    
    ax1.set_xlabel('Lag')
    ax1.set_ylabel('Autocorrelation')
    ax1.set_title('Autocorrelation Function (ACF)')
    ax1.legend()
    ax1.grid(axis='y', alpha=0.3)
    
    # 2. Significant lags
    ax2 = axes[1]
    significant = np.sum(np.abs(acf_values) > confidence_bound)
    expected_significant = 0.05 * max_lag
    
    ax2.bar(['Observed\nSignificant', 'Expected\nSignificant'], 
            [significant, expected_significant], 
            color=['coral', 'lightblue'], edgecolor='black', alpha=0.7)
    ax2.set_ylabel('Count')
    ax2.set_title('Significant Lags Detection (95% Confidence)')
    ax2.text(0, max(significant, expected_significant) * 0.7, 
             f'Observed: {significant}\nExpected: ~{expected_significant:.0f}',
             ha='center', fontsize=11, bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.5))
    
    plt.tight_layout()
    return fig

def plot_bit_analysis(data):
    """Analyze individual bits."""
    fig = plt.figure(figsize=(14, 8))
    gs = gridspec.GridSpec(2, 2, figure=fig, hspace=0.35, wspace=0.3)
    
    # Per-bit distribution
    ax1 = fig.add_subplot(gs[0, :])
    bit_ratios = []
    for bit_pos in range(16):
        bit_values = [(val >> bit_pos) & 1 for val in data]
        ratio = sum(bit_values) / len(bit_values)
        bit_ratios.append(ratio)
    
    colors = ['green' if 0.45 < r < 0.55 else 'red' for r in bit_ratios]
    ax1.bar(range(16), bit_ratios, color=colors, edgecolor='black', alpha=0.7)
    ax1.axhline(0.5, color='black', linestyle='--', linewidth=2, label='Expected (0.5)')
    ax1.axhline(0.45, color='orange', linestyle=':', linewidth=1.5, label='Acceptable Range')
    ax1.axhline(0.55, color='orange', linestyle=':', linewidth=1.5)
    ax1.set_xlabel('Bit Position')
    ax1.set_ylabel('Ratio of Ones')
    ax1.set_title('Individual Bit Distribution (One Ratio per Bit Position)')
    ax1.set_ylim([0.3, 0.7])
    ax1.legend()
    ax1.grid(axis='y', alpha=0.3)
    
    # Chi-square per bit
    ax2 = fig.add_subplot(gs[1, 0])
    chi2_values = []
    for bit_pos in range(16):
        bit_values = [(val >> bit_pos) & 1 for val in data]
        ones = int(sum(bit_values))
        zeros = len(bit_values) - ones
        chi2 = ((ones - zeros) ** 2) / len(bit_values)
        chi2_values.append(chi2)
    
    ax2.bar(range(16), chi2_values, color='steelblue', edgecolor='black', alpha=0.7)
    ax2.set_xlabel('Bit Position')
    ax2.set_ylabel('Chi-square Statistic')
    ax2.set_title('Per-Bit Chi-square Test')
    ax2.grid(axis='y', alpha=0.3)
    
    # Bit pair correlation
    ax3 = fig.add_subplot(gs[1, 1])
    pair_corr = []
    pair_labels = []
    for i in range(8):
        for j in range(i+1, min(i+3, 16)):
            bit_i = [(val >> i) & 1 for val in data]
            bit_j = [(val >> j) & 1 for val in data]
            corr = np.corrcoef(bit_i, bit_j)[0, 1]
            pair_corr.append(corr)
            pair_labels.append(f'{i},{j}')
    
    ax3.scatter(range(len(pair_corr)), pair_corr, alpha=0.6, s=50, color='darkgreen')
    ax3.axhline(0, color='black', linestyle='-', linewidth=0.5)
    ax3.set_xlabel('Bit Pairs')
    ax3.set_ylabel('Correlation')
    ax3.set_title('Bit Pair Correlations')
    ax3.grid(axis='y', alpha=0.3)
    
    plt.suptitle('Bit-Level Analysis', fontsize=16, fontweight='bold', y=0.995)
    return fig

def plot_entropy_analysis(data):
    """Analyze entropy."""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('Entropy and Information Analysis', fontsize=16, fontweight='bold')
    
    # 1. Byte distribution
    ax1 = axes[0, 0]
    high_bytes = (data >> 8).astype(np.uint8)
    low_bytes = (data & 0xFF).astype(np.uint8)
    
    ax1.hist([high_bytes, low_bytes], bins=256, label=['High Byte', 'Low Byte'], 
             color=['steelblue', 'coral'], alpha=0.7, edgecolor='black')
    ax1.set_xlabel('Byte Value (0-255)')
    ax1.set_ylabel('Frequency')
    ax1.set_title('High vs Low Byte Distribution')
    ax1.legend()
    ax1.grid(axis='y', alpha=0.3)
    
    # 2. Entropy over chunks
    ax2 = axes[0, 1]
    chunk_size = max(1000, len(data) // 100)
    chunk_entropies = []
    
    for i in range(0, len(data), chunk_size):
        chunk = data[i:i+chunk_size]
        if len(chunk) < 10:
            continue
        unique_vals, counts = np.unique(chunk, return_counts=True)
        probs = counts / len(chunk)
        entropy = -np.sum(probs * np.log2(probs + 1e-10))
        chunk_entropies.append(entropy)
    
    ax2.plot(chunk_entropies, linewidth=2, color='darkgreen', marker='o', markersize=4)
    ax2.axhline(16, color='red', linestyle='--', linewidth=2, label='Maximum (16 bits)')
    ax2.set_xlabel('Chunk Index')
    ax2.set_ylabel('Entropy (bits)')
    ax2.set_title(f'Entropy per Chunk (size={chunk_size})')
    ax2.legend()
    ax2.grid(alpha=0.3)
    
    # 3. Frequency of values
    ax3 = axes[1, 0]
    unique_vals, counts = np.unique(data, return_counts=True)
    max_count = max(counts)
    ax3.hist(counts, bins=50, color='steelblue', edgecolor='black', alpha=0.7)
    ax3.axvline(len(data) / len(unique_vals), color='red', linestyle='--', linewidth=2, 
                label=f'Expected Average')
    ax3.set_xlabel('Frequency Count')
    ax3.set_ylabel('Number of Values')
    ax3.set_title('Frequency Distribution of Values')
    ax3.legend()
    ax3.grid(axis='y', alpha=0.3)
    
    # 4. Value uniqueness
    ax4 = axes[1, 1]
    total_possible = 65536  # 2^16
    unique_count = len(unique_vals)
    coverage = unique_count / total_possible * 100
    
    ax4.barh(['Unique Values', 'Unused Values'], 
             [unique_count, total_possible - unique_count], 
             color=['#66b3ff', '#ff9999'], edgecolor='black', alpha=0.7)
    ax4.set_xlabel('Count')
    ax4.set_title(f'Value Coverage: {coverage:.1f}% ({unique_count}/65536)')
    ax4.text(unique_count * 0.5, 0.5, f'{coverage:.1f}%', ha='center', fontsize=12, fontweight='bold')
    
    plt.tight_layout()
    return fig

# ============================================================================
# MAIN
# ============================================================================

def main():
    # Script is in data analysis/pythonscripts, CSV is in data analysis/csv/
    if len(sys.argv) > 1:
        csv_path = Path(sys.argv[1])
    else:
        csv_path = Path(__file__).parent.parent / "csv" / "random_values_v9.csv"
    script_dir = Path(__file__).parent
    
    print("[OK] Loading data...")
    data = load_random_values(str(csv_path))
    print(f"[OK] Loaded {len(data):,} values")
    
    # Create output directory for plots
    plots_dir = script_dir / "plots"
    plots_dir.mkdir(exist_ok=True)
    print(f"[OK] Plots will be saved to: {plots_dir}")
    
    # Generate plots
    print("\n[OK] Generating plots...")
    
    print("  + Distribution overview...", end='', flush=True)
    fig1 = plot_distribution_overview(data)
    fig1.savefig(plots_dir / "01_distribution_overview.png", dpi=150, bbox_inches='tight')
    print(" [SAVED]")
    
    print("  + Test results...", end='', flush=True)
    results_path = script_dir / "randomness_results.json"
    if results_path.exists():
        results = load_test_results(results_path)
        fig2 = plot_test_results(results)
        fig2.savefig(plots_dir / "02_test_results_summary.png", dpi=150, bbox_inches='tight')
        print(" [SAVED]")
    else:
        print(" [SKIPPED - no results file]")
    
    print("  + Autocorrelation...", end='', flush=True)
    fig3 = plot_autocorrelation(data, max_lag=100)
    fig3.savefig(plots_dir / "03_autocorrelation_analysis.png", dpi=150, bbox_inches='tight')
    print(" [SAVED]")
    
    print("  + Bit-level analysis...", end='', flush=True)
    fig4 = plot_bit_analysis(data)
    fig4.savefig(plots_dir / "04_bit_level_analysis.png", dpi=150, bbox_inches='tight')
    print(" [SAVED]")
    
    print("  + Entropy analysis...", end='', flush=True)
    fig5 = plot_entropy_analysis(data)
    fig5.savefig(plots_dir / "05_entropy_analysis.png", dpi=150, bbox_inches='tight')
    print(" [SAVED]")
    
    print("\n[OK] All plots generated successfully!")
    print(f"\nPlots saved to: {plots_dir}")
    print("\nGenerated files:")
    print("  - 01_distribution_overview.png")
    print("  - 02_test_results_summary.png")
    print("  - 03_autocorrelation_analysis.png")
    print("  - 04_bit_level_analysis.png")
    print("  - 05_entropy_analysis.png")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
