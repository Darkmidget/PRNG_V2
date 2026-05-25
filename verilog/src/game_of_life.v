`timescale 1ns / 1ps
module game_of_life (
    input wire clk,
    input wire rst_n,
    
    // Control interface
    input wire start_init,    // Pulse to initialize with random data
    input wire [15:0] seed,   // PRNG seed
    input wire start_gen,     // Pulse to start calculating next generation
    output reg gen_done,      // High when generation calculation is complete
    output reg buf_sel,       // 0 = read A, write B; 1 = read B, write A
    
    // BRAM Interface (Read port for computing)
    output reg [17:0] raddr,
    input wire rdata,
    
    // BRAM Interface (Write port for computing)
    output reg we,
    output reg [17:0] waddr,
    output reg wdata
);

    // States
    localparam ST_IDLE = 4'd0;
    localparam ST_INIT = 4'd1;
    localparam ST_CALC = 4'd2;
    localparam ST_R1 = 4'd3;
    localparam ST_R2 = 4'd4;
    localparam ST_R3 = 4'd5;
    localparam ST_R4 = 4'd6;
    localparam ST_R5 = 4'd7;
    localparam ST_R6 = 4'd8;
    localparam ST_R7 = 4'd9;
    localparam ST_R8 = 4'd10;
    localparam ST_R9 = 4'd11;
    localparam ST_WRITE = 4'd12;

    reg [3:0] state;
    reg [8:0] x; // 0-319
    reg [8:0] y; // 0-479
    
    // Simple PRNG for init
    reg [15:0] lfsr;
    wire lfsr_fb = lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3];
    
    // Neighbor accumulation
    reg [3:0] neighbors;
    reg current_state;
    
    // Helper function for address (handles edge wrapping)
    function [17:0] calc_addr;
        input [8:0] cx;
        input [8:0] cy;
        begin
            calc_addr = cy * 320 + cx;
        end
    endfunction
    
    wire [8:0] x_left  = (x == 0) ? 319 : x - 1;
    wire [8:0] x_right = (x == 319) ? 0 : x + 1;
    wire [8:0] y_up    = (y == 0) ? 479 : y - 1;
    wire [8:0] y_down  = (y == 479) ? 0 : y + 1;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            gen_done <= 1'b0;
            buf_sel <= 1'b0;
            we <= 1'b0;
            waddr <= 18'd0;
            wdata <= 1'b0;
            raddr <= 18'd0;
            x <= 9'd0;
            y <= 9'd0;
            lfsr <= 16'hACE1;
        end else begin
            we <= 1'b0; // Default de-assert
            gen_done <= 1'b0;
            
            case (state)
                ST_IDLE: begin
                    if (start_init) begin
                        lfsr <= seed;
                        x <= 9'd0;
                        y <= 9'd0;
                        state <= ST_INIT;
                    end else if (start_gen) begin
                        x <= 9'd0;
                        y <= 9'd0;
                        state <= ST_R1;
                        raddr <= calc_addr(x_left, y_up);
                    end
                end
                
                ST_INIT: begin
                    // Fill current buffer with random data
                    we <= 1'b1;
                    waddr <= calc_addr(x, y);
                    wdata <= lfsr[0]; // Use lowest bit of LFSR
                    lfsr <= {lfsr[14:0], lfsr_fb};
                    
                    if (x == 319) begin
                        x <= 9'd0;
                        if (y == 479) begin
                            state <= ST_IDLE;
                            gen_done <= 1'b1;
                            buf_sel <= ~buf_sel; // FIX: toggle buffer so the one we just wrote to becomes active!
                        end else begin
                            y <= y + 1;
                        end
                    end else begin
                        x <= x + 1;
                    end
                end
                
                // Read sequence for cell (x, y)
                // We request address at ST_Rn, data arrives at ST_Rn+1
                ST_R1: begin
                    raddr <= calc_addr(x, y_up); // Req 2
                    state <= ST_R2;
                end
                ST_R2: begin
                    raddr <= calc_addr(x_right, y_up); // Req 3
                    neighbors <= rdata; // Accumulate 1
                    state <= ST_R3;
                end
                ST_R3: begin
                    raddr <= calc_addr(x_left, y); // Req 4
                    neighbors <= neighbors + rdata; // Accumulate 2
                    state <= ST_R4;
                end
                ST_R4: begin
                    raddr <= calc_addr(x_right, y); // Req 5
                    neighbors <= neighbors + rdata; // Accumulate 3
                    state <= ST_R5;
                end
                ST_R5: begin
                    raddr <= calc_addr(x_left, y_down); // Req 6
                    neighbors <= neighbors + rdata; // Accumulate 4
                    state <= ST_R6;
                end
                ST_R6: begin
                    raddr <= calc_addr(x, y_down); // Req 7
                    neighbors <= neighbors + rdata; // Accumulate 5
                    state <= ST_R7;
                end
                ST_R7: begin
                    raddr <= calc_addr(x_right, y_down); // Req 8
                    neighbors <= neighbors + rdata; // Accumulate 6
                    state <= ST_R8;
                end
                ST_R8: begin
                    raddr <= calc_addr(x, y); // Req own state (9)
                    neighbors <= neighbors + rdata; // Accumulate 7
                    state <= ST_R9;
                end
                ST_R9: begin
                    neighbors <= neighbors + rdata; // Accumulate 8
                    state <= ST_WRITE;
                end
                ST_WRITE: begin
                    current_state <= rdata; // Own state arrives here
                    
                    // Apply Conway's rules
                    we <= 1'b1;
                    waddr <= calc_addr(x, y);
                    if (rdata == 1'b1) begin
                        wdata <= (neighbors == 2 || neighbors == 3) ? 1'b1 : 1'b0;
                    end else begin
                        wdata <= (neighbors == 3) ? 1'b1 : 1'b0;
                    end
                    
                    // Increment coordinates
                    if (x == 319) begin
                        x <= 9'd0;
                        if (y == 479) begin
                            state <= ST_IDLE;
                            gen_done <= 1'b1;
                            buf_sel <= ~buf_sel; // Swap buffers
                        end else begin
                            y <= y + 1;
                            state <= ST_R1;
                            raddr <= calc_addr(9'd0 == 0 ? 319 : 9'd0 - 1, y + 1 == 0 ? 479 : y); // Pipelining first read
                        end
                    end else begin
                        x <= x + 1;
                        state <= ST_R1;
                        raddr <= calc_addr(x, y_up); // x + 1 - 1 = x
                    end
                end
            endcase
            
            // Fix the pipelining of first read for next cell
            if (state == ST_WRITE) begin
                if (x == 319) begin
                    if (y != 479) begin
                        raddr <= calc_addr(319, y); // Next is (0, y+1), so left-up is (319, y)
                    end
                end else begin
                    raddr <= calc_addr(x, y_up); // Next is (x+1, y), so left-up is (x, y_up)
                end
            end
        end
    end
endmodule
