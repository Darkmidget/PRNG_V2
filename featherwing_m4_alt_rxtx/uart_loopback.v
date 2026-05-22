//==========================================================
// UART Loopback Test for CMOD A7-35T
//
// Receives bytes from UART RX (DIP pin 23) and echoes them
// back on UART TX (DIP pin 22). Also blinks LEDs to indicate
// activity.
//
// Baud rate: 115200
// Clock:     12 MHz (CMOD A7 onboard oscillator)
//
// Wiring to Feather M4:
//   CMOD DIP 22 (FPGA TX)  -> Feather A4 (Serial3 RX)
//   CMOD DIP 23 (FPGA RX)  <- Feather A1 (Serial3 TX)
//   CMOD DIP 25 (GND)      -- Feather GND
//==========================================================

module uart_loopback (
    input  wire clk,          // 12 MHz onboard clock
    input  wire uart_rx,      // DIP pin 23 - from Feather TX
    output wire uart_tx,      // DIP pin 22 - to Feather RX
    output wire led0,         // Activity LED
    output wire led1          // Heartbeat LED
);

    //------------------------------------------------------
    // Parameters
    //------------------------------------------------------
    parameter CLK_FREQ  = 12_000_000;
    parameter BAUD_RATE = 115_200;
    parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;  // 104 ticks per bit

    //------------------------------------------------------
    // Reset (simple power-on reset)
    //------------------------------------------------------
    reg [3:0] rst_counter = 4'd0;
    reg rst = 1'b1;
    always @(posedge clk) begin
        if (rst_counter != 4'd15) begin
            rst_counter <= rst_counter + 1'b1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    //------------------------------------------------------
    // UART Receiver
    //------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) rx_inst (
        .clk       (clk),
        .rst       (rst),
        .rx_line   (uart_rx),
        .data_out  (rx_data),
        .data_valid(rx_valid)
    );

    //------------------------------------------------------
    // UART Transmitter
    //------------------------------------------------------
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) tx_inst (
        .clk      (clk),
        .rst      (rst),
        .data_in  (tx_data),
        .start    (tx_start),
        .tx_line  (uart_tx),
        .busy     (tx_busy)
    );

    //------------------------------------------------------
    // Loopback logic: when a byte arrives, send it back
    //------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            tx_data  <= 8'h00;
            tx_start <= 1'b0;
        end else begin
            tx_start <= 1'b0;  // default
            if (rx_valid && !tx_busy) begin
                tx_data  <= rx_data;
                tx_start <= 1'b1;
            end
        end
    end

    //------------------------------------------------------
    // LED indicators
    //------------------------------------------------------
    // LED0: turns on briefly when a byte is received
    reg [23:0] activity_counter = 24'd0;
    always @(posedge clk) begin
        if (rx_valid)
            activity_counter <= 24'd6_000_000;  // ~500ms
        else if (activity_counter != 0)
            activity_counter <= activity_counter - 1'b1;
    end
    assign led0 = (activity_counter != 0);

    // LED1: heartbeat so you know the FPGA is running
    reg [23:0] heartbeat = 24'd0;
    always @(posedge clk) heartbeat <= heartbeat + 1'b1;
    assign led1 = heartbeat[23];  // ~1.4 Hz blink at 12 MHz

endmodule


//==========================================================
// UART Receiver Module
//==========================================================
module uart_rx #(
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

    // Synchronize RX to clock domain (avoid metastability)
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
        end else begin
            data_valid <= 1'b0;  // default

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync_2 == 1'b0)  // start bit detected
                        state <= START_BIT;
                end

                START_BIT: begin
                    // Wait to middle of start bit to confirm
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
                        clk_count        <= 0;
                        rx_shift[bit_index] <= rx_sync_2;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP_BIT;
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

                default: state <= IDLE;
            endcase
        end
    end

endmodule


//==========================================================
// UART Transmitter Module
//==========================================================
module uart_tx #(
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
            tx_line   <= 1'b1;  // UART idle is HIGH
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_line   <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (start) begin
                        tx_data_reg <= data_in;
                        state       <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx_line <= 1'b0;  // start bit is LOW
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    tx_line <= tx_data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    tx_line <= 1'b1;  // stop bit is HIGH
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        state     <= CLEANUP;
                    end
                end

                CLEANUP: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
