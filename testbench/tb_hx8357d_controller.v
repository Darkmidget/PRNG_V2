`timescale 1ns / 1ps

module tb_hx8357d_controller();

    reg clk;
    reg rst_n;
    
    wire tft_sck;
    wire tft_mosi;
    wire tft_cs;
    wire tft_dc;
    wire tft_rst;
    wire display_ready;
    
    hx8357d_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .tft_sck(tft_sck),
        .tft_mosi(tft_mosi),
        .tft_cs(tft_cs),
        .tft_dc(tft_dc),
        .tft_rst(tft_rst),
        .display_ready(display_ready)
    );
    
    // 12 MHz Clock
    always #41.666 clk = ~clk;
    
    initial begin
        clk = 0;
        rst_n = 0;
        
        #100;
        rst_n = 1;
        
        // Wait for some time to see the initialization kick off.
        // The delays in the real hardware are huge (10ms-120ms), which is 
        // millions of clock cycles. We are increasing the wait time so 
        // the reset state machine and initialization sequence can fully complete.
        
        wait(display_ready == 1);
        $display("Display is ready! Initialization completed successfully at time %0t ns.", $time);
        
        #10_000;
        
        $display("Testbench complete.");
        $finish;
    end

    // Safety timeout in case initialization gets stuck
    initial begin
        #2_000_000_000;
        $display("Error: Testbench timeout! display_ready never asserted.");
        $finish;
    end

endmodule
