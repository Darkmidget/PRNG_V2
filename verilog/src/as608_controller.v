`timescale 1ns / 1ps

module as608_controller #(
    parameter CLK_FREQ = 12_000_000,
    parameter BAUD_RATE = 57600
)(
    input wire clk,
    input wire rst,
    
    // UART interface to AS608
    input wire rx_in,
    output wire tx_out,
    
    // Control interface
    input wire start_scan,
    output reg scan_done = 0,
    output reg [7:0] status_code = 0,
    output wire waiting_for_finger,
    output wire processing_finger,
    
    // Template RAM interface (Read-Only for external modules)
    input wire [8:0] template_addr,
    output reg [7:0] template_data
);

    wire rx_valid;
    wire [7:0] rx_data;
    wire tx_busy;
    reg tx_start = 0;
    reg [7:0] tx_data = 0;

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

    // 512-byte RAM for the fingerprint template
    reg [7:0] template_ram [0:511];
    
    always @(posedge clk) begin
        template_data <= template_ram[template_addr];
    end

    // Command packets
    // 1. GenImg: 0xEF 0x01 0xFF 0xFF 0xFF 0xFF 0x01 0x00 0x03 0x01 0x00 0x05
    // 2. Img2Tz: 0xEF 0x01 0xFF 0xFF 0xFF 0xFF 0x01 0x00 0x04 0x02 0x01 0x00 0x08
    // 3. UpChar: 0xEF 0x01 0xFF 0xFF 0xFF 0xFF 0x01 0x00 0x04 0x08 0x01 0x00 0x0E
    
    reg [7:0] cmd_genimg [0:11];
    reg [7:0] cmd_img2tz [0:12];
    reg [7:0] cmd_upchar [0:12];
    
    initial begin
        // GenImg
        cmd_genimg[0] = 8'hEF; cmd_genimg[1] = 8'h01; cmd_genimg[2] = 8'hFF; cmd_genimg[3] = 8'hFF;
        cmd_genimg[4] = 8'hFF; cmd_genimg[5] = 8'hFF; cmd_genimg[6] = 8'h01; cmd_genimg[7] = 8'h00;
        cmd_genimg[8] = 8'h03; cmd_genimg[9] = 8'h01; cmd_genimg[10]= 8'h00; cmd_genimg[11]= 8'h05;

        // Img2Tz (Buffer 1)
        cmd_img2tz[0] = 8'hEF; cmd_img2tz[1] = 8'h01; cmd_img2tz[2] = 8'hFF; cmd_img2tz[3] = 8'hFF;
        cmd_img2tz[4] = 8'hFF; cmd_img2tz[5] = 8'hFF; cmd_img2tz[6] = 8'h01; cmd_img2tz[7] = 8'h00;
        cmd_img2tz[8] = 8'h04; cmd_img2tz[9] = 8'h02; cmd_img2tz[10]= 8'h01; cmd_img2tz[11]= 8'h00;
        cmd_img2tz[12]= 8'h08;

        // UpChar (Buffer 1)
        cmd_upchar[0] = 8'hEF; cmd_upchar[1] = 8'h01; cmd_upchar[2] = 8'hFF; cmd_upchar[3] = 8'hFF;
        cmd_upchar[4] = 8'hFF; cmd_upchar[5] = 8'hFF; cmd_upchar[6] = 8'h01; cmd_upchar[7] = 8'h00;
        cmd_upchar[8] = 8'h04; cmd_upchar[9] = 8'h08; cmd_upchar[10]= 8'h01; cmd_upchar[11]= 8'h00;
        cmd_upchar[12]= 8'h0E;
    end

    localparam STATE_IDLE           = 4'd0;
    
    localparam STATE_TX_GENIMG      = 4'd1;
    localparam STATE_RX_GENIMG      = 4'd2;
    
    localparam STATE_TX_IMG2TZ      = 4'd3;
    localparam STATE_RX_IMG2TZ      = 4'd4;
    
    localparam STATE_TX_UPCHAR      = 4'd5;
    localparam STATE_RX_UPCHAR_ACK  = 4'd6;
    
    localparam STATE_RX_DATA_HDR    = 4'd7;
    localparam STATE_RX_DATA_PAYLOAD= 4'd8;
    localparam STATE_RX_DATA_CHK    = 4'd9;
    
    localparam STATE_DONE           = 4'd10;

    reg [3:0] state = STATE_IDLE;
    reg [8:0] byte_idx = 0;
    reg [15:0] payload_len = 0;
    reg [8:0] ram_write_addr = 0;
    reg [7:0] packet_flag = 0;

    assign waiting_for_finger = (state == STATE_TX_GENIMG || state == STATE_RX_GENIMG);
    assign processing_finger = (state >= STATE_TX_IMG2TZ && state < STATE_DONE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
            tx_start <= 0;
            tx_data <= 0;
            scan_done <= 0;
            status_code <= 0;
            byte_idx <= 0;
            payload_len <= 0;
            ram_write_addr <= 0;
            packet_flag <= 0;
        end else begin
            tx_start <= 0;
            
            case (state)
                STATE_IDLE: begin
                    scan_done <= 0;
                    byte_idx <= 0;
                    ram_write_addr <= 0;
                    if (start_scan) begin
                        state <= STATE_TX_GENIMG;
                    end
                end
                
                // --- GenImg ---
                STATE_TX_GENIMG: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data <= cmd_genimg[byte_idx];
                        tx_start <= 1;
                        if (byte_idx == 11) begin
                            state <= STATE_RX_GENIMG;
                            byte_idx <= 0;
                        end else begin
                            byte_idx <= byte_idx + 1;
                        end
                    end
                end
                STATE_RX_GENIMG: begin
                    if (rx_valid) begin
                        case (byte_idx)
                            0: begin
                                if (rx_data == 8'hEF) byte_idx <= 1;
                                else byte_idx <= 0;
                            end
                            1: begin
                                if (rx_data == 8'h01) byte_idx <= 2;
                                else byte_idx <= 0;
                            end
                            2, 3, 4, 5: begin
                                if (rx_data == 8'hFF) byte_idx <= byte_idx + 1;
                                else byte_idx <= 0;
                            end
                            6: begin
                                if (rx_data == 8'h07) byte_idx <= 7;
                                else byte_idx <= 0;
                            end
                            7: begin
                                if (rx_data == 8'h00) byte_idx <= 8;
                                else byte_idx <= 0;
                            end
                            8: begin
                                if (rx_data == 8'h03) byte_idx <= 9;
                                else byte_idx <= 0;
                            end
                            9: begin
                                status_code <= rx_data;
                                byte_idx <= 10;
                            end
                            10: begin
                                byte_idx <= 11;
                            end
                            11: begin
                                byte_idx <= 0;
                                if (status_code == 0) begin
                                    state <= STATE_TX_IMG2TZ;
                                end else if (status_code == 8'h02) begin
                                    // No finger detected, try again
                                    state <= STATE_TX_GENIMG;
                                end else begin
                                    state <= STATE_DONE; // Error, exit early
                                end
                            end
                            default: byte_idx <= 0;
                        endcase
                    end
                end
                
                // --- Img2Tz ---
                STATE_TX_IMG2TZ: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data <= cmd_img2tz[byte_idx];
                        tx_start <= 1;
                        if (byte_idx == 12) begin
                            state <= STATE_RX_IMG2TZ;
                            byte_idx <= 0;
                        end else begin
                            byte_idx <= byte_idx + 1;
                        end
                    end
                end
                STATE_RX_IMG2TZ: begin
                    if (rx_valid) begin
                        case (byte_idx)
                            0: begin
                                if (rx_data == 8'hEF) byte_idx <= 1;
                                else byte_idx <= 0;
                            end
                            1: begin
                                if (rx_data == 8'h01) byte_idx <= 2;
                                else byte_idx <= 0;
                            end
                            2, 3, 4, 5: begin
                                if (rx_data == 8'hFF) byte_idx <= byte_idx + 1;
                                else byte_idx <= 0;
                            end
                            6: begin
                                if (rx_data == 8'h07) byte_idx <= 7;
                                else byte_idx <= 0;
                            end
                            7: begin
                                if (rx_data == 8'h00) byte_idx <= 8;
                                else byte_idx <= 0;
                            end
                            8: begin
                                if (rx_data == 8'h03) byte_idx <= 9;
                                else byte_idx <= 0;
                            end
                            9: begin
                                status_code <= rx_data;
                                byte_idx <= 10;
                            end
                            10: begin
                                byte_idx <= 11;
                            end
                            11: begin
                                byte_idx <= 0;
                                if (status_code == 0) begin
                                    state <= STATE_TX_UPCHAR;
                                end else begin
                                    state <= STATE_DONE; // Error, exit early
                                end
                            end
                            default: byte_idx <= 0;
                        endcase
                    end
                end
                
                // --- UpChar ---
                STATE_TX_UPCHAR: begin
                    if (!tx_busy && !tx_start) begin
                        tx_data <= cmd_upchar[byte_idx];
                        tx_start <= 1;
                        if (byte_idx == 12) begin
                            state <= STATE_RX_UPCHAR_ACK;
                            byte_idx <= 0;
                        end else begin
                            byte_idx <= byte_idx + 1;
                        end
                    end
                end
                STATE_RX_UPCHAR_ACK: begin
                    if (rx_valid) begin
                        case (byte_idx)
                            0: begin
                                if (rx_data == 8'hEF) byte_idx <= 1;
                                else byte_idx <= 0;
                            end
                            1: begin
                                if (rx_data == 8'h01) byte_idx <= 2;
                                else byte_idx <= 0;
                            end
                            2, 3, 4, 5: begin
                                if (rx_data == 8'hFF) byte_idx <= byte_idx + 1;
                                else byte_idx <= 0;
                            end
                            6: begin
                                if (rx_data == 8'h07) byte_idx <= 7;
                                else byte_idx <= 0;
                            end
                            7: begin
                                if (rx_data == 8'h00) byte_idx <= 8;
                                else byte_idx <= 0;
                            end
                            8: begin
                                if (rx_data == 8'h03) byte_idx <= 9;
                                else byte_idx <= 0;
                            end
                            9: begin
                                status_code <= rx_data;
                                byte_idx <= 10;
                            end
                            10: begin
                                byte_idx <= 11;
                            end
                            11: begin
                                byte_idx <= 0;
                                if (status_code == 0) begin
                                    state <= STATE_RX_DATA_HDR;
                                end else begin
                                    state <= STATE_DONE; // Error, exit early
                                end
                            end
                            default: byte_idx <= 0;
                        endcase
                    end
                end
                
                // --- Data Packet parsing ---
                STATE_RX_DATA_HDR: begin
                    if (rx_valid) begin
                        case (byte_idx)
                            0: begin
                                if (rx_data == 8'hEF) byte_idx <= 1;
                                else byte_idx <= 0;
                            end
                            1: begin
                                if (rx_data == 8'h01) byte_idx <= 2;
                                else byte_idx <= 0;
                            end
                            2, 3, 4, 5: begin
                                if (rx_data == 8'hFF) byte_idx <= byte_idx + 1;
                                else byte_idx <= 0;
                            end
                            6: begin
                                if (rx_data == 8'h02 || rx_data == 8'h08) begin
                                    packet_flag <= rx_data;
                                    byte_idx <= 7;
                                end else begin
                                    byte_idx <= 0;
                                end
                            end
                            7: begin
                                payload_len[15:8] <= rx_data;
                                byte_idx <= 8;
                            end
                            8: begin
                                payload_len[7:0] <= rx_data;
                                state <= STATE_RX_DATA_PAYLOAD;
                                byte_idx <= 0;
                            end
                            default: byte_idx <= 0;
                        endcase
                    end
                end
                
                STATE_RX_DATA_PAYLOAD: begin
                    if (rx_valid) begin
                        if (byte_idx < payload_len - 2) begin
                            template_ram[ram_write_addr] <= rx_data;
                            ram_write_addr <= ram_write_addr + 1;
                            
                            if (byte_idx == payload_len - 3) begin
                                state <= STATE_RX_DATA_CHK;
                                byte_idx <= 0;
                            end else begin
                                byte_idx <= byte_idx + 1;
                            end
                        end
                    end
                end
                
                STATE_RX_DATA_CHK: begin
                    if (rx_valid) begin
                        byte_idx <= byte_idx + 1;
                        if (byte_idx == 1) begin
                            if (packet_flag == 8'h08) begin
                                state <= STATE_DONE;
                            end else begin
                                state <= STATE_RX_DATA_HDR;
                                byte_idx <= 0;
                            end
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
