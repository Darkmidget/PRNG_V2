`timescale 1ns / 1ps

module hx8357d_controller (
    input wire clk,          // 12 MHz system clock
    input wire rst_n,        // Active low system reset
    input wire [15:0] prng_seed, // Dynamic PRNG seed
    
    // SPI physical interface
    output wire tft_sck,
    output wire tft_mosi,
    output wire tft_cs,
    output wire tft_dc,
    output reg  tft_rst,
    
    // Status
    output wire display_ready
);

    // Hardware reset state machine
    localparam RESET_IDLE = 0;
    localparam RESET_LOW  = 1;
    localparam RESET_WAIT = 2;
    localparam RESET_DONE = 3;
    
    reg [1:0] rst_state;
    reg [20:0] reset_timer;
    reg init_start;
    
    // Reset sequence: wait a bit, bring RST low for 10ms, bring it high, wait 120ms
    always @(posedge clk) begin
        if (!rst_n) begin
            rst_state <= RESET_IDLE;
            tft_rst <= 1'b1;
            init_start <= 1'b0;
            reset_timer <= 21'd0;
        end else begin
            case (rst_state)
                RESET_IDLE: begin
                    tft_rst <= 1'b0; // Pull low
                    reset_timer <= 21'd120_000; // ~10ms at 12MHz
                    rst_state <= RESET_LOW;
                end
                
                RESET_LOW: begin
                    if (reset_timer == 0) begin
                        tft_rst <= 1'b1; // Bring high
                        reset_timer <= 21'd1_440_000; // wait ~120ms before init
                        rst_state <= RESET_WAIT;
                    end else begin
                        reset_timer <= reset_timer - 1;
                    end
                end
                
                RESET_WAIT: begin
                    if (reset_timer == 0) begin
                        init_start <= 1'b1; // Kick off the SPI init FSM
                        rst_state <= RESET_DONE;
                    end else begin
                        reset_timer <= reset_timer - 1;
                    end
                end
                
                RESET_DONE: begin
                    // Stay here
                end
            endcase
        end
    end

    // Interconnects
    wire [7:0] init_spi_data;
    wire init_spi_start;
    wire init_tft_dc;
    wire init_tft_cs;
    wire init_done;
    
    wire spi_ready;
    wire [7:0] spi_data;
    wire spi_start;
    
    // Draw FSM signals
    reg [7:0] draw_spi_data;
    reg draw_spi_start;
    reg draw_tft_dc;
    reg draw_tft_cs;
    
    assign spi_data = init_done ? draw_spi_data : init_spi_data;
    assign spi_start = init_done ? draw_spi_start : init_spi_start;
    assign tft_dc = init_done ? draw_tft_dc : init_tft_dc;
    assign tft_cs = init_done ? draw_tft_cs : init_tft_cs;
    assign display_ready = init_done;
    
    // Game of life signals
    reg gol_start_init;
    reg gol_start_gen;
    wire gol_gen_done;
    wire gol_buf_sel;
    
    wire [17:0] gol_raddr;
    wire gol_we;
    wire [17:0] gol_waddr;
    wire gol_wdata;
    reg gol_rdata;
    // Draw FSM signals & states
    localparam DRAW_IDLE = 0;
    localparam DRAW_CMD  = 1;
    localparam DRAW_WAIT_CMD = 2;
    localparam DRAW_PIX_H = 3;
    localparam DRAW_WAIT_H = 4;
    localparam DRAW_PIX_L = 5;
    localparam DRAW_WAIT_L = 6;
    localparam DRAW_GOL_WAIT = 7;
    
    reg [3:0] draw_state;
    reg [17:0] draw_count;
    reg gol_init_done;

    // Display read signals
    reg [17:0] disp_raddr;
    wire disp_rdata_a;
    wire disp_rdata_b;
    
    // BRAMs (Ping-Pong buffers)
    // buf_sel = 0: Active buffer is A. Display reads A. GOL reads A, writes B.
    // buf_sel = 1: Active buffer is B. Display reads B. GOL reads B, writes A.

    wire we_a = (gol_buf_sel == 1) ? gol_we : 1'b0;
    wire we_b = (gol_buf_sel == 0) ? gol_we : 1'b0;
    
    wire is_drawing = (draw_state != DRAW_IDLE && draw_state != DRAW_GOL_WAIT);
    wire [17:0] shared_raddr = is_drawing ? disp_raddr : gol_raddr;
    
    wire [17:0] raddr_a = (gol_buf_sel == 0) ? shared_raddr : 18'd0;
    wire [17:0] raddr_b = (gol_buf_sel == 1) ? shared_raddr : 18'd0;
    
    wire [17:0] waddr_a = gol_waddr;
    wire [17:0] waddr_b = gol_waddr;
    
    bram_framebuffer bram_a (
        .clk(clk),
        .we(we_a),
        .waddr(waddr_a),
        .din(gol_wdata),
        .raddr(raddr_a),
        .dout(disp_rdata_a)
    );
    
    bram_framebuffer bram_b (
        .clk(clk),
        .we(we_b),
        .waddr(waddr_b),
        .din(gol_wdata),
        .raddr(raddr_b),
        .dout(disp_rdata_b)
    );
    
    always @(*) begin
        if (gol_buf_sel == 0) gol_rdata = disp_rdata_a;
        else                  gol_rdata = disp_rdata_b;
    end
    
    wire cur_disp_pixel = (gol_buf_sel == 0) ? disp_rdata_a : disp_rdata_b;
    
    game_of_life gol_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start_init(gol_start_init),
        .seed(prng_seed), // Wired to the output of the ring_osc PRNG
        .start_gen(gol_start_gen),
        .gen_done(gol_gen_done),
        .buf_sel(gol_buf_sel),
        .raddr(gol_raddr),
        .rdata(gol_rdata),
        .we(gol_we),
        .waddr(gol_waddr),
        .wdata(gol_wdata)
    );
    
    always @(posedge clk) begin
        if (!rst_n || !init_done) begin
            draw_state <= DRAW_IDLE;
            draw_spi_start <= 0;
            draw_tft_cs <= 1;
            draw_tft_dc <= 1;
            disp_raddr <= 0;
            gol_start_init <= 0;
            gol_start_gen <= 0;
            draw_count <= 0;
            gol_init_done <= 0;
        end else begin
            gol_start_init <= 0;
            gol_start_gen <= 0;
            draw_spi_start <= 0;
            
            case (draw_state)
                DRAW_IDLE: begin
                    if (!gol_init_done) begin
                        gol_start_init <= 1;
                        gol_init_done <= 1;
                        draw_state <= DRAW_GOL_WAIT;
                    end else begin
                        draw_tft_cs <= 0;
                        draw_tft_dc <= 0; // Command
                        draw_spi_data <= 8'h2C; // RAMWR
                        draw_spi_start <= 1;
                        draw_state <= DRAW_WAIT_CMD;
                        disp_raddr <= 0;
                        draw_count <= 0;
                    end
                end
                DRAW_WAIT_CMD: begin
                    if (spi_ready && !draw_spi_start) begin
                        draw_tft_dc <= 1; // Data
                        draw_state <= DRAW_PIX_H;
                    end
                end
                DRAW_PIX_H: begin
                    draw_spi_data <= cur_disp_pixel ? 8'h07 : 8'h00; // Green vs Black (High byte)
                    draw_spi_start <= 1;
                    draw_state <= DRAW_WAIT_H;
                end
                DRAW_WAIT_H: begin
                    if (spi_ready && !draw_spi_start) begin
                        draw_state <= DRAW_PIX_L;
                    end
                end
                DRAW_PIX_L: begin
                    draw_spi_data <= cur_disp_pixel ? 8'hE0 : 8'h00; // Green vs Black (Low byte)
                    draw_spi_start <= 1;
                    draw_state <= DRAW_WAIT_L;
                end
                DRAW_WAIT_L: begin
                    if (spi_ready && !draw_spi_start) begin
                        if (draw_count == 153599) begin
                            draw_tft_cs <= 1; // End frame
                            gol_start_gen <= 1; // Trigger next generation
                            draw_state <= DRAW_GOL_WAIT;
                        end else begin
                            disp_raddr <= disp_raddr + 1;
                            draw_count <= draw_count + 1;
                            draw_state <= DRAW_PIX_H;
                        end
                    end
                end
                DRAW_GOL_WAIT: begin
                    if (gol_gen_done) begin
                        draw_state <= DRAW_IDLE;
                    end
                end
            endcase
        end
    end

    // The SPI Master
    spi_master spi_inst (
        .clk(clk),
        .rst(~rst_n),
        .data_in(spi_data),
        .start(spi_start),
        .ready(spi_ready),
        .sck(tft_sck),
        .mosi(tft_mosi)
    );
    
    // The Initialization FSM
    hx8357d_init init_inst (
        .clk(clk),
        .rst(~init_start), // held in reset until HW reset is done
        .spi_data(init_spi_data),
        .spi_start(init_spi_start),
        .spi_ready(spi_ready),
        .tft_dc(init_tft_dc),
        .tft_cs(init_tft_cs),
        .init_done(init_done)
    );

endmodule
