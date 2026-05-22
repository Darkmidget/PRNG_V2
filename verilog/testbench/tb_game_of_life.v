`timescale 1ns / 1ps

module tb_game_of_life();

    reg clk;
    reg rst_n;
    
    // Control
    reg start_init;
    reg [15:0] seed;
    reg start_gen;
    wire gen_done;
    wire buf_sel;
    
    // Read/Write ports
    wire [17:0] raddr;
    wire rdata;
    wire we;
    wire [17:0] waddr;
    wire wdata;
    
    // BRAMs
    wire we_a = (~buf_sel) ? 1'b0 : we;
    wire we_b = (~buf_sel) ? we : 1'b0;
    
    wire [17:0] raddr_a = raddr;
    wire [17:0] raddr_b = raddr;
    
    wire dout_a;
    wire dout_b;
    
    assign rdata = (~buf_sel) ? dout_a : dout_b;
    
    bram_framebuffer bram_a (
        .clk(clk),
        .we(we_a),
        .waddr(waddr),
        .din(wdata),
        .raddr(raddr_a),
        .dout(dout_a)
    );
    
    bram_framebuffer bram_b (
        .clk(clk),
        .we(we_b),
        .waddr(waddr),
        .din(wdata),
        .raddr(raddr_b),
        .dout(dout_b)
    );
    
    game_of_life uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_init(start_init),
        .seed(seed),
        .start_gen(start_gen),
        .gen_done(gen_done),
        .buf_sel(buf_sel),
        .raddr(raddr),
        .rdata(rdata),
        .we(we),
        .waddr(waddr),
        .wdata(wdata)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #41.667 clk = ~clk; // ~12 MHz
    end
    
    initial begin
        // Reset
        rst_n = 0;
        start_init = 0;
        start_gen = 0;
        seed = 16'h1337;
        
        #100;
        rst_n = 1;
        
        // Initialize
        #100;
        start_init = 1;
        #100;
        start_init = 0;
        
        // Wait for init to complete
        wait(gen_done);
        
        #1000;
        
        // Generate first frame
        start_gen = 1;
        #100;
        start_gen = 0;
        
        wait(gen_done);
        
        #1000;
        
        // Generate second frame
        start_gen = 1;
        #100;
        start_gen = 0;
        
        wait(gen_done);
        
        #1000;
        $display("Simulation complete.");
        $finish;
    end

endmodule
