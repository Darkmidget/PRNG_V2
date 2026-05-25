`timescale 1ns / 1ps

module fpga_main (
    input wire clk,
    input wire [0:0] btn, // Active high button
    
    // UART interface to AS606
    input wire as606_rx,
    output wire as606_tx,
    
    // SPI physical interface to HX8357D
    output wire tft_sck,
    output wire tft_mosi,
    output wire tft_cs,
    output wire tft_dc,
    output wire tft_rst,
    
    // Debug LEDs
    output wire [1:0] led
);

    wire rst_sys = 1'b0; // System reset not driven externally, tie off
    
    // AS606 connections
    wire scan_done;
    wire [7:0] status_code;
    reg start_scan_reg = 0;
    
    as606_controller #(
        .CLK_FREQ(12_000_000),
        .BAUD_RATE(57600)
    ) thumbprint_scanner (
        .clk(clk),
        .rst(rst_sys),
        .rx_in(as606_rx),
        .tx_out(as606_tx),
        .start_scan(start_scan_reg),
        .scan_done(scan_done),
        .status_code(status_code)
    );
    
    // Ring oscillator / PRNG connections
    wire [15:0] prng_val;
    wire [5:0] hex_nc;
    wire dp_nc;
    wire [6:0] seg_nc;
    wire ring_tx_nc;
    
    ring_osc random_gen (
        .sysclk(clk),
        .SW(2'b00),
        .btn({1'b0, 1'b0}),
        .HEX(hex_nc),
        .DP(dp_nc),
        .SEG(seg_nc),
        .led(), // we use our own led mapping below
        .tx(ring_tx_nc),
        .prng_out(prng_val)
    );
    
    // FSM to control workflow
    localparam S_WAIT = 0;
    localparam S_SCAN = 1;
    localparam S_GOL  = 2;
    
    reg [1:0] state = S_WAIT;
    reg tft_rst_n_reg = 0;
    reg [15:0] captured_seed = 0;
    
    // Debounce btn[0] slightly
    reg [15:0] btn_debounce = 0;
    reg btn_pressed = 0;
    always @(posedge clk) begin
        if (btn[0]) begin
            if (btn_debounce < 16'hFFFF) btn_debounce <= btn_debounce + 1;
            if (btn_debounce == 16'hFFFE) btn_pressed <= 1;
        end else begin
            btn_debounce <= 0;
            btn_pressed <= 0;
        end
    end
    
    always @(posedge clk) begin
        case (state)
            S_WAIT: begin
                start_scan_reg <= 0;
                if (btn_pressed) begin
                    // Capture seed and transition to GOL state
                    captured_seed <= prng_val;
                    state <= S_GOL;
                end
            end
            
            S_SCAN: begin
                // Unused now, keeping for reference
                state <= S_GOL;
            end
            
            S_GOL: begin
                tft_rst_n_reg <= 1; // Release display reset, it will initialize and start GOL
                // We stay here forever
            end
        endcase
    end
    
    // Display controller
    wire disp_ready;
    hx8357d_controller display_ctrl (
        .clk(clk),
        .rst_n(tft_rst_n_reg),
        .prng_seed(captured_seed),
        
        .tft_sck(tft_sck),
        .tft_mosi(tft_mosi),
        .tft_cs(tft_cs),
        .tft_dc(tft_dc),
        .tft_rst(tft_rst),
        
        .display_ready(disp_ready)
    );

    // Status LEDs
    assign led[0] = (state == S_WAIT) ? 1'b1 : 1'b0;
    assign led[1] = (state == S_GOL) ? disp_ready : 1'b0;

endmodule
