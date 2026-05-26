`timescale 1ns / 1ps

// UART Transceiver Module
// Parameterized for Clock Frequency and Baud Rate

module uart_tx #(
    parameter CLK_FREQ = 12_000_000,
    parameter BAUD_RATE = 57600
)(
    input wire clk,
    input wire rst,
    input wire tx_start,
    input wire [7:0] tx_data,
    output reg tx_busy,
    output reg tx_out
);

    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] tx_data_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_busy <= 0;
            tx_out <= 1;
            clk_count <= 0;
            bit_index <= 0;
            tx_data_r <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out <= 1;
                    tx_busy <= 0;
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if (tx_start) begin
                        tx_data_r <= tx_data;
                        state <= START;
                        tx_busy <= 1;
                    end
                end

                START: begin
                    tx_out <= 0;
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA;
                    end
                end

                DATA: begin
                    tx_out <= tx_data_r[bit_index];
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_out <= 1;
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= IDLE;
                        tx_busy <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule


module uart_rx #(
    parameter CLK_FREQ = 12_000_000,
    parameter BAUD_RATE = 57600
)(
    input wire clk,
    input wire rst,
    input wire rx_in,
    output reg rx_valid,
    output reg [7:0] rx_data
);

    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;
    
    // Double-register rx_in to avoid metastability
    reg rx_r1, rx_r2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_r1 <= 1;
            rx_r2 <= 1;
        end else begin
            rx_r1 <= rx_in;
            rx_r2 <= rx_r1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rx_valid <= 0;
            rx_data <= 0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            // Default pulse
            rx_valid <= 0;
            
            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if (rx_r2 == 0) begin // Start bit detected
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == (CLOCKS_PER_BIT - 1) / 2) begin
                        if (rx_r2 == 0) begin
                            clk_count <= 0;
                            state <= DATA;
                        end else begin
                            state <= IDLE; // False start bit
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                DATA: begin
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        rx_data[bit_index] <= rx_r2;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= IDLE;
                        rx_valid <= 1; // Pulse valid at end of stop bit
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
