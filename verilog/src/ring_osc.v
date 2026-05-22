module ring_osc(
    input         sysclk,
    input  [1:0]  SW,
    input  [1:0]  btn,
    output [5:0]  HEX,
    output        DP,
    output [6:0]  SEG,
    output [1:0]  led,
    output        tx,
    output wire [15:0] prng_out
);

    wire rstn   = 1'b1;           // Always out of reset
    wire en     = 1'b1;           // Oscillator always enabled
    wire freeze =  btn[0];

    // 31-stage ring oscillator
    (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *) wire [30:0] ring;

    (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *)
        LUT2 #(.INIT(4'b0111)) ring_gate (
        .I0(ring[30]),
        .I1(en),
        .O (ring[0])
    );

    genvar i;
    generate
        for (i = 1; i < 31; i = i + 1) begin : ring_stages
            (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *)
            LUT1 #(.INIT(2'b01)) inv (
                .I0(ring[i-1]),
                .O (ring[i])
            );
        end
    endgenerate

    wire osc_out = ring[30];

    // 2-FF CDC sampler
    (* KEEP = "TRUE" *) reg ff0, ff1;
    always @(posedge sysclk or negedge rstn) begin
        if (!rstn) begin ff0 <= 1'b0; ff1 <= 1'b0; end
        else       begin ff0 <= osc_out; ff1 <= ff0; end
    end

    wire entropy_bit = ff1;

    // Multi-tap entropy
    (* KEEP = "TRUE" *) wire tap7  = ring[7];
    (* KEEP = "TRUE" *) wire tap15 = ring[15];
    (* KEEP = "TRUE" *) wire tap22 = ring[22];

    wire entropy_bit_xor = ff1 ^ tap7 ^ tap15 ^ tap22;

    reg [15:0] lfsr;
    wire lfsr_feedback = lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]
                                  ^ entropy_bit_xor;
    always @(posedge sysclk or negedge rstn) begin
        if (!rstn) lfsr <= lfsr ^ 16'hACE1;
        else       lfsr <= {lfsr[14:0], lfsr_feedback};
    end
    
    assign prng_out = lfsr;

    function [15:0] xor_mix;
        input [15:0] x;
        reg   [15:0] h;
        begin
            h = x ^ (x >> 7);
            h = h ^ (h << 9);
            h = h ^ (h >> 13);
            xor_mix = h;
        end
    endfunction

    // DISPLAY UPDATE - Keep for visual feedback (optional, doesn't affect UART)
    reg [23:0] update_ctr;
    reg        update_tick;
    always @(posedge sysclk or negedge rstn) begin
        if (!rstn) begin
            update_ctr  <= 24'd0;
            update_tick <= 1'b0;
        end else begin
            update_tick <= (update_ctr == 24'd11999999);
            if (update_ctr == 24'd11999999) update_ctr <= 24'd0;
            else                            update_ctr <= update_ctr + 1;
        end
    end

    reg [15:0] display_word;
    always @(posedge sysclk or negedge rstn) begin
        if (!rstn)                      display_word <= xor_mix(lfsr ^ 16'hACE1);
        else if (update_tick & ~freeze) display_word <= xor_mix(lfsr);
    end

    // 4 hex nibbles for display
    wire [3:0] digit3 = display_word[15:12];
    wire [3:0] digit2 = display_word[11:8];
    wire [3:0] digit1 = display_word[7:4];
    wire [3:0] digit0 = display_word[3:0];

    // 7-seg mux
    reg [13:0] mux_ctr;
    reg [1:0]  digit_sel;
    always @(posedge sysclk or negedge rstn) begin
        if (!rstn) begin mux_ctr <= 14'd0; digit_sel <= 2'd0; end
        else if (mux_ctr == 14'd11999) begin
            mux_ctr   <= 14'd0;
            digit_sel <= digit_sel + 1;
        end else mux_ctr <= mux_ctr + 1;
    end

    function [6:0] hex2seg;
        input [3:0] d;
        case (d)
            4'h0: hex2seg = 7'b1000000;
            4'h1: hex2seg = 7'b1111001;
            4'h2: hex2seg = 7'b0100100;
            4'h3: hex2seg = 7'b0110000;
            4'h4: hex2seg = 7'b0011001;
            4'h5: hex2seg = 7'b0010010;
            4'h6: hex2seg = 7'b0000010;
            4'h7: hex2seg = 7'b1111000;
            4'h8: hex2seg = 7'b0000000;
            4'h9: hex2seg = 7'b0010000;
            4'hA: hex2seg = 7'b0001000;
            4'hB: hex2seg = 7'b0000011;
            4'hC: hex2seg = 7'b1000110;
            4'hD: hex2seg = 7'b0100001;
            4'hE: hex2seg = 7'b0000110;
            4'hF: hex2seg = 7'b0001110;
        endcase
    endfunction

    reg [3:0] cur_nibble;
    always @(*) begin
        case (digit_sel)
            2'd0: cur_nibble = digit3;
            2'd1: cur_nibble = digit2;
            2'd2: cur_nibble = digit1;
            2'd3: cur_nibble = digit0;
        endcase
    end

    assign SEG = ~hex2seg(cur_nibble);
    assign HEX[3] = ~(digit_sel == 2'd0);
    assign HEX[2] = ~(digit_sel == 2'd1);
    assign HEX[1] = ~(digit_sel == 2'd2);
    assign HEX[0] = ~(digit_sel == 2'd3);
    assign HEX[5:4] = 2'b11;
    assign DP = 1'b0;

    // LEDs
    reg [23:0] hb_ctr;
    reg        led0_reg, led1_reg;

    always @(posedge sysclk or negedge rstn) begin
        if (!rstn) begin
            hb_ctr   <= 24'd0;
            led0_reg <= 1'b0;
            led1_reg <= 1'b0;
        end else begin
            hb_ctr   <= hb_ctr + 1;
            led0_reg <= en;
            led1_reg <= hb_ctr[23];
        end
    end

    assign led[0] = led0_reg;
    assign led[1] = led1_reg;

    // ========================================================================
    // UART TX - CONTINUOUS MODE @ 115200 baud
    // Sends "XXXX\r\n" continuously as fast as possible (every ~52 µs)
    // ========================================================================
    localparam CLKS_PER_BIT = 104;

    function [7:0] nibble2ascii;
        input [3:0] n;
        nibble2ascii = (n < 4'd10) ? (8'd48 + n) : (8'd55 + n);
    endfunction

    reg [7:0]  tx_buf [0:5];
    reg [2:0]  tx_byte_idx;
    reg [3:0]  tx_bit_idx;
    reg [6:0]  tx_clk_ctr;
    reg        tx_busy;
    reg        tx_reg;

    assign tx = tx_reg;

    always @(posedge sysclk or negedge rstn) begin
        if (!rstn) begin
            tx_busy     <= 1'b0;
            tx_reg      <= 1'b1;
            tx_byte_idx <= 3'd0;
            tx_bit_idx  <= 4'd0;
            tx_clk_ctr  <= 7'd0;
        end else begin

            // =================================================================
            // KEY CHANGE: Load new value when tx_busy becomes 0 (transmission complete)
            // This means we send a new value immediately after the previous one finishes
            // =================================================================
            if (!tx_busy) begin
                // Use CURRENT lfsr value, not display_word (which updates at 1 Hz)
                tx_buf[0] <= nibble2ascii(lfsr[15:12]);
                tx_buf[1] <= nibble2ascii(lfsr[11:8]);
                tx_buf[2] <= nibble2ascii(lfsr[7:4]);
                tx_buf[3] <= nibble2ascii(lfsr[3:0]);
                tx_buf[4] <= 8'h0D; // CR
                tx_buf[5] <= 8'h0A; // LF
                tx_busy     <= 1'b1;
                tx_byte_idx <= 3'd0;
                tx_bit_idx  <= 4'd0;
                tx_clk_ctr  <= 7'd0;
            end

            // Transmit bit-by-bit
            if (tx_busy) begin
                if (tx_clk_ctr < CLKS_PER_BIT - 1) begin
                    tx_clk_ctr <= tx_clk_ctr + 1;
                end else begin
                    tx_clk_ctr <= 7'd0;
                    case (tx_bit_idx)
                        4'd0: tx_reg <= 1'b0; // start bit
                        4'd1: tx_reg <= tx_buf[tx_byte_idx][0];
                        4'd2: tx_reg <= tx_buf[tx_byte_idx][1];
                        4'd3: tx_reg <= tx_buf[tx_byte_idx][2];
                        4'd4: tx_reg <= tx_buf[tx_byte_idx][3];
                        4'd5: tx_reg <= tx_buf[tx_byte_idx][4];
                        4'd6: tx_reg <= tx_buf[tx_byte_idx][5];
                        4'd7: tx_reg <= tx_buf[tx_byte_idx][6];
                        4'd8: tx_reg <= tx_buf[tx_byte_idx][7];
                        4'd9: begin
                            tx_reg <= 1'b1; // stop bit
                            if (tx_byte_idx == 3'd5) begin
                                tx_busy <= 1'b0; // done all 6 bytes, trigger next load
                            end else begin
                                tx_byte_idx <= tx_byte_idx + 1;
                                tx_bit_idx  <= 4'd0;
                            end
                        end
                    endcase
                    if (tx_bit_idx < 4'd9) tx_bit_idx <= tx_bit_idx + 1;
                end
            end

        end
    end

endmodule
