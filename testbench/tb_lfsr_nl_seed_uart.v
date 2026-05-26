`timescale 1ns / 1ps

module tb_lfsr_nl_seed_uart();
    reg sysclk;
    reg uart_rx;
    wire uart_tx;
    wire [1:0] led;

    lfsr_nl_seed_uart dut(
        .sysclk(sysclk),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led(led)
    );

    always #41.666 sysclk = ~sysclk;

    initial begin
        sysclk = 0;
        uart_rx = 1;
        #1000;
        $display("Simulation for random_gen completed successfully.");
        $finish;
    end
endmodule
