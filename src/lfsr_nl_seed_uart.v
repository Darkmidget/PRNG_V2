`timescale 1ns / 1ps
module lfsr_nl_seed_uart(
    input  wire       sysclk,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [1:0] led
);

    localparam CLK_FREQ     = 12_000_000;
    localparam BAUD_RATE    = 115_200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam ST_IDLE          = 3'd0;
    localparam ST_SEND_BYTE0    = 3'd1;
    localparam ST_WAIT_BYTE0    = 3'd2;
    localparam ST_SEND_BYTE1    = 3'd3;
    localparam ST_WAIT_BYTE1    = 3'd4;

    // Simple power-on reset
    reg [3:0] rst_counter = 4'd0;
    reg       rst = 1'b1;
    always @(posedge sysclk) begin
        if (rst_counter != 4'd15) begin
            rst_counter <= rst_counter + 1'b1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    // UART RX
    wire [7:0] rx_data;
    wire       rx_valid;

    lfsr_uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) rx_inst (
        .clk       (sysclk),
        .rst       (rst),
        .rx_line   (uart_rx),
        .data_out  (rx_data),
        .data_valid(rx_valid)
    );

    // UART TX
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    lfsr_uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) tx_inst (
        .clk    (sysclk),
        .rst    (rst),
        .data_in(tx_data),
        .start  (tx_start),
        .tx_line(uart_tx),
        .busy   (tx_busy)
    );

    // ---------------------------------------------------------------------
    // LFSR_NL_Modified_Von core pieces (from notebook): XADC + VN + mixing
    // ---------------------------------------------------------------------
    wire [15:0] xadc_do;
    wire        xadc_drdy;
    wire        xadc_eoc;

    XADC #(
        .INIT_40(16'h9000), .INIT_41(16'h2ef0), .INIT_42(16'h0400),
        .INIT_48(16'h0800), .INIT_49(16'h0000)
    ) xadc_inst (
        .DCLK     (sysclk),
        .DRDY     (xadc_drdy),
        .DO       (xadc_do),
        .EOC      (xadc_eoc),
        .DEN      (xadc_eoc),
        .DADDR    (7'h00),
        .RESET    (rst),
        .VP       (1'b0),
        .VN       (1'b0),
        .VAUXP    (16'h0000),
        .VAUXN    (16'h0000),
        .CONVST   (1'b0),
        .CONVSTCLK(1'b0),
        .DI       (16'h0000),
        .DWE      (1'b0)
    );

    reg vn_state;
    reg vn_bit_a;
    reg vn_valid;
    reg clean_bit;

    always @(posedge sysclk) begin
        if (rst) begin
            vn_state <= 1'b0;
            vn_valid <= 1'b0;
            clean_bit <= 1'b0;
        end else if (xadc_drdy) begin
            if (!vn_state) begin
                vn_bit_a <= xadc_do[0];
                vn_state <= 1'b1;
                vn_valid <= 1'b0;
            end else begin
                vn_state <= 1'b0;
                if (vn_bit_a != xadc_do[0]) begin
                    clean_bit <= vn_bit_a;
                    vn_valid  <= 1'b1;
                end else begin
                    vn_valid <= 1'b0;
                end
            end
        end else begin
            vn_valid <= 1'b0;
        end
    end

    reg [15:0] free_ctr;
    always @(posedge sysclk) begin
        if (rst) begin
            free_ctr <= 16'hFFFF;
        end else begin
            free_ctr <= free_ctr + 16'd31957;
        end
    end

    function [15:0] xor_mix;
        input [15:0] x;
        reg   [15:0] h;
        begin
            h = x ^ (x >> 7);
            h = h * 16'h9E37;
            h = h ^ (h >> 9);
            h = h * 16'h8445;
            xor_mix = h ^ (h >> 13);
        end
    endfunction

    function [3:0] sbox;
        input [3:0] x;
        begin
            case (x)
                4'h0: sbox = 4'hE; 4'h1: sbox = 4'h4; 4'h2: sbox = 4'hD; 4'h3: sbox = 4'h1;
                4'h4: sbox = 4'h2; 4'h5: sbox = 4'hF; 4'h6: sbox = 4'hB; 4'h7: sbox = 4'h8;
                4'h8: sbox = 4'h3; 4'h9: sbox = 4'hA; 4'hA: sbox = 4'h6; 4'hB: sbox = 4'hC;
                4'hC: sbox = 4'h5; 4'hD: sbox = 4'h9; 4'hE: sbox = 4'h0; 4'hF: sbox = 4'h7;
            endcase
        end
    endfunction

    function [15:0] sbox_16;
        input [15:0] x;
        begin
            sbox_16 = {sbox(x[15:12]), sbox(x[11:8]), sbox(x[7:4]), sbox(x[3:0])};
        end
    endfunction

    // ---------------------------------------------------------------------
    // Fingerprint framing: variable-length bytes terminated by 0xFF
    // Seed policy: first two bytes only (big-endian), ignore remaining bytes
    // ---------------------------------------------------------------------
    reg [7:0] first_byte;
    reg [7:0] second_byte;
    reg [7:0] rx_count;

    reg [15:0] pending_seed;
    reg        pending_seed_valid;

    reg [15:0] rand_word;
    reg [2:0]  state;

    wire [15:0] seed_word = {first_byte, second_byte};

    wire [15:0] lfsr_seeded = pending_seed;
    wire        lfsr_feedback_seeded =
        lfsr_seeded[15] ^ lfsr_seeded[14] ^ lfsr_seeded[12] ^ lfsr_seeded[3] ^
        (lfsr_seeded[0] & lfsr_seeded[1]) ^ clean_bit;
    wire [15:0] lfsr_next_seeded = {lfsr_seeded[14:0], lfsr_feedback_seeded} + 16'h7A89;
    wire [15:0] rand_from_seed = xor_mix(sbox_16(lfsr_next_seeded) + sbox_16(free_ctr));

    always @(posedge sysclk) begin
        if (rst) begin
            first_byte        <= 8'h00;
            second_byte       <= 8'h00;
            rx_count          <= 8'd0;
            pending_seed      <= 16'h0000;
            pending_seed_valid<= 1'b0;
            rand_word         <= 16'h0000;
            tx_data           <= 8'h00;
            tx_start          <= 1'b0;
            state             <= ST_IDLE;
        end else begin
            tx_start <= 1'b0;

            if (rx_valid) begin
                if (rx_data == 8'hFF) begin
                    if (rx_count != 8'd0) begin
                        // Use first byte always; second byte defaults to 0x00 when absent.
                        pending_seed <= {first_byte, (rx_count >= 8'd2) ? second_byte : 8'h00};
                        pending_seed_valid <= 1'b1;
                    end
                    rx_count <= 8'd0;
                    first_byte  <= 8'h00;
                    second_byte <= 8'h00;
                end else begin
                    if (rx_count == 8'd0) begin
                        first_byte <= rx_data;
                        second_byte <= 8'h00;
                    end else if (rx_count == 8'd1) begin
                        second_byte <= rx_data;
                    end

                    if (rx_count != 8'hFF) begin
                        rx_count <= rx_count + 1'b1;
                    end
                end
            end

            case (state)
                ST_IDLE: begin
                    if (pending_seed_valid) begin
                        rand_word <= rand_from_seed;
                        pending_seed_valid <= 1'b0;
                        state <= ST_SEND_BYTE0;
                    end
                end

                ST_SEND_BYTE0: begin
                    if (!tx_busy) begin
                        tx_data  <= rand_word[7:0];
                        tx_start <= 1'b1;
                        state    <= ST_WAIT_BYTE0;
                    end
                end

                ST_WAIT_BYTE0: begin
                    if (!tx_busy && !tx_start) begin
                        state <= ST_SEND_BYTE1;
                    end
                end

                ST_SEND_BYTE1: begin
                    if (!tx_busy) begin
                        tx_data  <= rand_word[15:8];
                        tx_start <= 1'b1;
                        state    <= ST_WAIT_BYTE1;
                    end
                end

                ST_WAIT_BYTE1: begin
                    if (!tx_busy && !tx_start) begin
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    assign led[0] = (rx_count != 8'd0);
    assign led[1] = tx_busy;

endmodule


module lfsr_uart_rx #(
    parameter CLKS_PER_BIT = 104
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx_line,
    output reg  [7:0] data_out,
    output reg        data_valid
);

    localparam IDLE      = 3'd0;
    localparam START_BIT = 3'd1;
    localparam DATA_BITS = 3'd2;
    localparam STOP_BIT  = 3'd3;
    localparam CLEANUP   = 3'd4;

    reg [2:0]  state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0]  bit_index = 0;
    reg [7:0]  rx_shift = 0;

    reg rx_sync_1 = 1'b1;
    reg rx_sync_2 = 1'b1;
    always @(posedge clk) begin
        rx_sync_1 <= rx_line;
        rx_sync_2 <= rx_sync_1;
    end

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            clk_count  <= 0;
            bit_index  <= 0;
            data_valid <= 1'b0;
            data_out   <= 8'h00;
        end else begin
            data_valid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync_2 == 1'b0) begin
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_sync_2 == 1'b0) begin
                            clk_count <= 0;
                            state     <= DATA_BITS;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        rx_shift[bit_index] <= rx_sync_2;
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        data_out   <= rx_shift;
                        data_valid <= 1'b1;
                        clk_count  <= 0;
                        state      <= CLEANUP;
                    end
                end

                CLEANUP: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule


module lfsr_uart_tx #(
    parameter CLKS_PER_BIT = 104
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,
    input  wire       start,
    output reg        tx_line,
    output wire       busy
);

    localparam IDLE      = 3'd0;
    localparam START_BIT = 3'd1;
    localparam DATA_BITS = 3'd2;
    localparam STOP_BIT  = 3'd3;
    localparam CLEANUP   = 3'd4;

    reg [2:0]  state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0]  bit_index = 0;
    reg [7:0]  tx_data_reg = 0;

    assign busy = (state != IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx_line   <= 1'b1;
            clk_count <= 0;
            bit_index <= 0;
            tx_data_reg <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    tx_line   <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (start) begin
                        tx_data_reg <= data_in;
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx_line <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    tx_line <= tx_data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    tx_line <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state <= CLEANUP;
                    end
                end

                CLEANUP: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
