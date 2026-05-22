`timescale 1ns / 1ps

module as606_controller #(
    parameter CLK_FREQ = 12_000_000,
    parameter BAUD_RATE = 57600
)(
    input wire clk,
    input wire rst,
    
    // UART interface to AS606
    input wire rx_in,
    output wire tx_out,
    
    // Control interface
    input wire start_scan,
    output reg scan_done,
    output reg [7:0] status_code
);

    wire rx_valid;
    wire [7:0] rx_data;
    wire tx_busy;
    reg tx_start;
    reg [7:0] tx_data;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_out(tx_out)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx_in(rx_in),
        .rx_valid(rx_valid),
        .rx_data(rx_data)
    );

    // Basic AS606 Command: Get Image (0x01)
    // Packet: 0xEF 0x01 0xFF 0xFF 0xFF 0xFF 0x01 0x00 0x03 0x01 0x00 0x05
    localparam PKT_LEN = 12;
    reg [7:0] cmd_get_image [0:PKT_LEN-1];
    
    initial begin
        cmd_get_image[0] = 8'hEF;
        cmd_get_image[1] = 8'h01;
        cmd_get_image[2] = 8'hFF;
        cmd_get_image[3] = 8'hFF;
        cmd_get_image[4] = 8'hFF;
        cmd_get_image[5] = 8'hFF;
        cmd_get_image[6] = 8'h01; // Command packet
        cmd_get_image[7] = 8'h00; // Length high
        cmd_get_image[8] = 8'h03; // Length low
        cmd_get_image[9] = 8'h01; // Instruction: Get Image
        cmd_get_image[10]= 8'h00; // Checksum high
        cmd_get_image[11]= 8'h05; // Checksum low
    end

    localparam STATE_IDLE = 3'd0;
    localparam STATE_SEND_CMD = 3'd1;
    localparam STATE_WAIT_TX = 3'd2;
    localparam STATE_WAIT_RX = 3'd3;
    localparam STATE_DONE = 3'd4;

    reg [2:0] state;
    reg [3:0] byte_idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
            tx_start <= 0;
            tx_data <= 0;
            scan_done <= 0;
            status_code <= 0;
            byte_idx <= 0;
        end else begin
            tx_start <= 0; // Default off
            
            case (state)
                STATE_IDLE: begin
                    scan_done <= 0;
                    byte_idx <= 0;
                    if (start_scan) begin
                        state <= STATE_SEND_CMD;
                    end
                end
                
                STATE_SEND_CMD: begin
                    if (!tx_busy) begin
                        tx_data <= cmd_get_image[byte_idx];
                        tx_start <= 1;
                        state <= STATE_WAIT_TX;
                    end
                end
                
                STATE_WAIT_TX: begin
                    if (!tx_busy && !tx_start) begin
                        if (byte_idx < PKT_LEN - 1) begin
                            byte_idx <= byte_idx + 1;
                            state <= STATE_SEND_CMD;
                        end else begin
                            state <= STATE_WAIT_RX;
                            byte_idx <= 0; // reuse for RX count
                        end
                    end
                end
                
                STATE_WAIT_RX: begin
                    // Read back response. A typical response is 12 bytes.
                    if (rx_valid) begin
                        byte_idx <= byte_idx + 1;
                        if (byte_idx == 9) begin
                            // byte 9 is typically the confirmation code
                            status_code <= rx_data;
                        end
                        if (byte_idx == 11) begin
                            state <= STATE_DONE;
                        end
                    end
                end
                
                STATE_DONE: begin
                    scan_done <= 1;
                    if (!start_scan) begin
                        state <= STATE_IDLE;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
