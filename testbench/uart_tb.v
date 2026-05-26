`timescale 1ns / 1ps

module uart_tb;

    // Parameters
    parameter CLK_FREQ = 12_000_000;
    parameter BAUD_RATE = 57600;
    parameter CLK_PERIOD = 1_000_000_000 / CLK_FREQ; // in ns (~83.33 ns)

    // Signals
    reg clk;
    reg rst;
    
    // UART signals
    wire tx_out;
    wire rx_valid;
    wire [7:0] rx_data;
    
    // AS608 controller signals
    reg start_scan;
    wire scan_done;
    wire [7:0] status_code;

    // Instantiate AS608 controller
    as608_controller #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx_in(tx_out), // Loopback TX to RX for simple test
        .tx_out(tx_out),
        .start_scan(start_scan),
        .scan_done(scan_done),
        .status_code(status_code)
    );

    // Also instantiate a standalone RX module to monitor TX output
    wire rx_monitor_valid;
    wire [7:0] rx_monitor_data;
    
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) monitor_rx (
        .clk(clk),
        .rst(rst),
        .rx_in(tx_out),
        .rx_valid(rx_monitor_valid),
        .rx_data(rx_monitor_data)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize
        rst = 1;
        start_scan = 0;
        
        // Reset system
        #1000;
        rst = 0;
        #1000;
        
        // Trigger a scan
        $display("[%0t] Starting AS608 Scan Command Transmission...", $time);
        start_scan = 1;
        
        // Wait for it to clear IDLE state
        #1000;
        start_scan = 0;
        
        // Wait for scan to complete
        wait(scan_done);
        $display("[%0t] Scan complete signal received. Status code: %02x", $time, status_code);
        
        #10000;
        $display("[%0t] Simulation finished successfully.", $time);
        $finish;
    end
    
    // Monitor TX output
    always @(posedge clk) begin
        if (rx_monitor_valid) begin
            $display("[%0t] Monitor received byte: %02x", $time, rx_monitor_data);
        end
    end

endmodule
