`timescale 1ns / 1ps

module spi_master (
    input wire clk,          // System clock
    input wire rst,          // Active high reset
    
    // User interface
    input wire [7:0] data_in,
    input wire start,
    output reg ready,
    
    // SPI physical interface
    output reg sck,
    output reg mosi
);

    // Using a simple state machine and clock divider
    // For a 12MHz system clock, we might not even need a divider for the HX8357D
    // which can typically handle SPI up to 10-20MHz. But let's add a small divider
    // for safety (e.g., divide by 2 -> 6MHz SPI clock)
    
    reg [2:0] state;
    reg [2:0] bit_counter;
    reg [7:0] shift_reg;
    reg clk_div; // simple div by 2
    reg sck_en;
    
    localparam IDLE  = 3'd0;
    localparam SETUP = 3'd1;
    localparam HIGH  = 3'd2;
    localparam LOW   = 3'd3;
    localparam DONE  = 3'd4;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            ready <= 1'b1;
            sck <= 1'b0;
            mosi <= 1'b0;
            bit_counter <= 3'd7;
            shift_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    sck <= 1'b0;
                    if (start) begin
                        ready <= 1'b0;
                        shift_reg <= data_in;
                        bit_counter <= 3'd7;
                        state <= SETUP;
                    end
                end
                
                SETUP: begin
                    // Output the data on MOSI
                    mosi <= shift_reg[7];
                    shift_reg <= {shift_reg[6:0], 1'b0};
                    sck <= 1'b0;
                    state <= HIGH;
                end
                
                HIGH: begin
                    // Rising edge of SCK, device samples MOSI
                    sck <= 1'b1;
                    state <= LOW;
                end
                
                LOW: begin
                    // Falling edge of SCK
                    sck <= 1'b0;
                    if (bit_counter == 0) begin
                        state <= DONE;
                    end else begin
                        bit_counter <= bit_counter - 1;
                        state <= SETUP;
                    end
                end
                
                DONE: begin
                    ready <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
