`timescale 1ns/1ps

`include "baud_gen.v"

module baud_gen_tb;

    localparam REF_CLK_PERIOD = 2; // in ns, giving design reference clk_freq of 500 Mhz
    localparam BAUD_PERIOD = 30518; // in ns, based on baud rate of 32768 bps
    localparam CLKS_PER_BAUD = BAUD_PERIOD/REF_CLK_PERIOD;
    localparam N_BAUDS = 10;
    localparam IDLE = 1'b0; // generator idle
    localparam GEN = 1'b1; // generator running

    reg reset; // global reset pin
    reg ref_clk; // received from external oscillator @ 500 MHz
    reg start; // received from UART Rx pin to detect start bit
    wire clk_out; // baud rate output

    baud_gen baud_gen_dut(.reset(reset),
                        .ref_clk(ref_clk),
                        .start(start),
                        .clk_out(clk_out)
    );

    initial begin
        reset <= 1;
        start <= 1;
        ref_clk <= 0;
        #(REF_CLK_PERIOD) reset <= 0;
        #(REF_CLK_PERIOD/2) start <= 0;
    end

    always begin
        #(REF_CLK_PERIOD/2) ref_clk <= ~ref_clk;
    end

    initial begin
        #(REF_CLK_PERIOD*CLKS_PER_BAUD*N_BAUDS+3) $finish;
    end

endmodule