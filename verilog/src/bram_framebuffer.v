`timescale 1ns / 1ps
module bram_framebuffer (
    input wire clk,
    input wire we,
    input wire [17:0] waddr,
    input wire din,
    input wire [17:0] raddr,
    output reg dout
);
    // 320 x 480 = 153600 bits
    // We use inferred block RAM
    reg ram [0:153599];
    
    // Initialize to 0
    integer i;
    initial begin
        for (i = 0; i < 153600; i = i + 1) begin
            ram[i] = 1'b0;
        end
    end

    always @(posedge clk) begin
        if (we) begin
            ram[waddr] <= din;
        end
        dout <= ram[raddr];
    end
endmodule
