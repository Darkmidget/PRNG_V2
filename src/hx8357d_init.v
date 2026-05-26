`timescale 1ns / 1ps

module hx8357d_init (
    input wire clk,          // 12 MHz system clock
    input wire rst,          // Active high reset
    
    // SPI Master Interface
    output reg [7:0] spi_data,
    output reg spi_start,
    input wire spi_ready,
    
    // Display Interface
    output reg tft_dc,       // 0=Command, 1=Data
    output reg tft_cs,       // Active low chip select
    
    // Status
    output reg init_done
);

    // States
    localparam STATE_IDLE    = 0;
    localparam STATE_READ    = 1;
    localparam STATE_WAIT_SPI= 2;
    localparam STATE_DELAY   = 3;
    localparam STATE_DONE    = 4;

    reg [2:0] state;
    
    // ROM holding the initialization sequence
    // Format: { Is_Cmd (1bit), Is_Delay (1bit), Delay_x5ms (8bits), Payload (8bits) }
    reg [17:0] init_rom [0:85];
    reg [6:0] rom_addr;
    
    // Delay counter for 12 MHz clock
    // 5 ms at 12 MHz = 60,000 cycles
    reg [15:0] tick_5ms_counter;
    reg [7:0] delay_counter;
    
    wire [17:0] current_cmd = init_rom[rom_addr];
    wire is_cmd      = current_cmd[17];
    wire is_delay    = current_cmd[16];
    wire [7:0] delay_val = current_cmd[15:8];
    wire [7:0] payload   = current_cmd[7:0];
    wire is_end      = (current_cmd == 18'h3FFFF);

    initial begin
        init_rom[0] = 18'h31401; // CMD 0x01, wait 100ms
        init_rom[1] = 18'h200B9; // CMD 0xB9
        init_rom[2] = 18'h000FF; // ARG 0xFF
        init_rom[3] = 18'h00083; // ARG 0x83
        init_rom[4] = 18'h00057; // ARG 0x57
        init_rom[5] = 18'h36400; // Delay only 500ms
        init_rom[6] = 18'h200B3; // CMD 0xB3
        init_rom[7] = 18'h00080; // ARG 0x80
        init_rom[8] = 18'h00000; // ARG 0x00
        init_rom[9] = 18'h00006; // ARG 0x06
        init_rom[10] = 18'h00006; // ARG 0x06
        init_rom[11] = 18'h200B6; // CMD 0xB6
        init_rom[12] = 18'h00025; // ARG 0x25
        init_rom[13] = 18'h200B0; // CMD 0xB0
        init_rom[14] = 18'h00068; // ARG 0x68
        init_rom[15] = 18'h200CC; // CMD 0xCC
        init_rom[16] = 18'h00005; // ARG 0x05
        init_rom[17] = 18'h200B1; // CMD 0xB1
        init_rom[18] = 18'h00000; // ARG 0x00
        init_rom[19] = 18'h00015; // ARG 0x15
        init_rom[20] = 18'h0001C; // ARG 0x1C
        init_rom[21] = 18'h0001C; // ARG 0x1C
        init_rom[22] = 18'h00083; // ARG 0x83
        init_rom[23] = 18'h000AA; // ARG 0xAA
        init_rom[24] = 18'h200C0; // CMD 0xC0
        init_rom[25] = 18'h00050; // ARG 0x50
        init_rom[26] = 18'h00050; // ARG 0x50
        init_rom[27] = 18'h00001; // ARG 0x01
        init_rom[28] = 18'h0003C; // ARG 0x3C
        init_rom[29] = 18'h0001E; // ARG 0x1E
        init_rom[30] = 18'h00008; // ARG 0x08
        init_rom[31] = 18'h200B4; // CMD 0xB4
        init_rom[32] = 18'h00002; // ARG 0x02
        init_rom[33] = 18'h00040; // ARG 0x40
        init_rom[34] = 18'h00000; // ARG 0x00
        init_rom[35] = 18'h0002A; // ARG 0x2A
        init_rom[36] = 18'h0002A; // ARG 0x2A
        init_rom[37] = 18'h0000D; // ARG 0x0D
        init_rom[38] = 18'h00078; // ARG 0x78
        init_rom[39] = 18'h200E0; // CMD 0xE0
        init_rom[40] = 18'h00002; // ARG 0x02
        init_rom[41] = 18'h0000A; // ARG 0x0A
        init_rom[42] = 18'h00011; // ARG 0x11
        init_rom[43] = 18'h0001D; // ARG 0x1D
        init_rom[44] = 18'h00023; // ARG 0x23
        init_rom[45] = 18'h00035; // ARG 0x35
        init_rom[46] = 18'h00041; // ARG 0x41
        init_rom[47] = 18'h0004B; // ARG 0x4B
        init_rom[48] = 18'h0004B; // ARG 0x4B
        init_rom[49] = 18'h00042; // ARG 0x42
        init_rom[50] = 18'h0003A; // ARG 0x3A
        init_rom[51] = 18'h00027; // ARG 0x27
        init_rom[52] = 18'h0001B; // ARG 0x1B
        init_rom[53] = 18'h00008; // ARG 0x08
        init_rom[54] = 18'h00009; // ARG 0x09
        init_rom[55] = 18'h00003; // ARG 0x03
        init_rom[56] = 18'h00002; // ARG 0x02
        init_rom[57] = 18'h0000A; // ARG 0x0A
        init_rom[58] = 18'h00011; // ARG 0x11
        init_rom[59] = 18'h0001D; // ARG 0x1D
        init_rom[60] = 18'h00023; // ARG 0x23
        init_rom[61] = 18'h00035; // ARG 0x35
        init_rom[62] = 18'h00041; // ARG 0x41
        init_rom[63] = 18'h0004B; // ARG 0x4B
        init_rom[64] = 18'h0004B; // ARG 0x4B
        init_rom[65] = 18'h00042; // ARG 0x42
        init_rom[66] = 18'h0003A; // ARG 0x3A
        init_rom[67] = 18'h00027; // ARG 0x27
        init_rom[68] = 18'h0001B; // ARG 0x1B
        init_rom[69] = 18'h00008; // ARG 0x08
        init_rom[70] = 18'h00009; // ARG 0x09
        init_rom[71] = 18'h00003; // ARG 0x03
        init_rom[72] = 18'h00000; // ARG 0x00
        init_rom[73] = 18'h00001; // ARG 0x01
        init_rom[74] = 18'h2003A; // CMD 0x3A
        init_rom[75] = 18'h00055; // ARG 0x55
        init_rom[76] = 18'h20036; // CMD 0x36
        init_rom[77] = 18'h000C0; // ARG 0xC0
        init_rom[78] = 18'h20035; // CMD 0x35
        init_rom[79] = 18'h00000; // ARG 0x00
        init_rom[80] = 18'h20044; // CMD 0x44
        init_rom[81] = 18'h00000; // ARG 0x00
        init_rom[82] = 18'h00002; // ARG 0x02
        init_rom[83] = 18'h31E11; // CMD 0x11, wait 150ms
        init_rom[84] = 18'h30A29; // CMD 0x29, wait 50ms
        init_rom[85] = 18'h3FFFF; // END OF SEQUENCE
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            init_done <= 1'b0;
            rom_addr <= 7'd0;
            tft_cs <= 1'b1;
            spi_start <= 1'b0;
            tick_5ms_counter <= 16'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (!init_done) begin
                        tft_cs <= 1'b1; // Keep CS high by default
                        state <= STATE_READ;
                    end
                end
                
                STATE_READ: begin
                    if (is_end) begin
                        tft_cs <= 1'b1; // De-assert CS
                        init_done <= 1'b1;
                        state <= STATE_DONE;
                    end else if (spi_ready) begin
                        tft_dc <= ~is_cmd; // DC=0 for cmd, 1 for data
                        spi_data <= payload;
                        if (!is_cmd && is_delay) begin
                            // This is a delay-only step, don't trigger SPI!
                            tft_cs <= 1'b1; // CS high during delay
                            delay_counter <= delay_val;
                            tick_5ms_counter <= 16'd60_000;
                            state <= STATE_DELAY;
                        end else begin
                            tft_cs <= 1'b0; // Assert CS for transmission
                            spi_start <= 1'b1;
                            state <= STATE_WAIT_SPI;
                        end
                    end
                end
                
                STATE_WAIT_SPI: begin
                    spi_start <= 1'b0;
                    if (spi_ready && !spi_start) begin
                        tft_cs <= 1'b1; // De-assert CS immediately when byte is sent
                        // Transaction complete
                        if (is_delay) begin
                            delay_counter <= delay_val;
                            tick_5ms_counter <= 16'd60_000;
                            state <= STATE_DELAY;
                        end else begin
                            rom_addr <= rom_addr + 1;
                            state <= STATE_READ;
                        end
                    end
                end
                
                STATE_DELAY: begin
                    tft_cs <= 1'b1; // Ensure CS remains high during delays
                    if (tick_5ms_counter == 0) begin
                        if (delay_counter == 0) begin
                            rom_addr <= rom_addr + 1;
                            state <= STATE_READ;
                        end else begin
                            delay_counter <= delay_counter - 1;
                            tick_5ms_counter <= 16'd60_000;
                        end
                    end else begin
                        tick_5ms_counter <= tick_5ms_counter - 1;
                    end
                end
                
                STATE_DONE: begin
                    // Done
                end
            endcase
        end
    end

endmodule
