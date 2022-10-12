`timescale 1ns/1ps

module baud_gen(reset, ref_clk, start, clk_out);

    // UART specifications
    localparam REF_CLK_PERIOD = 2; // in ns, giving design reference clk_freq of 500 Mhz
    localparam BAUD_PERIOD = 30518; // in ns, based on baud rate of 32768 bps
    localparam CLKS_PER_BAUD = BAUD_PERIOD/REF_CLK_PERIOD;
    localparam IDLE = 1'b0; // generator idle
    localparam GEN = 1'b1; // generator running

    // number of bauds for frame sections
    localparam BAUD_START = 1;
    localparam BAUD_DATA = 8;
    localparam BAUD_PARITY = 1;
    localparam BAUD_STOP = 2;
    localparam BAUD_RESET = BAUD_START + BAUD_DATA + BAUD_PARITY + BAUD_STOP;

    input reset; // global reset pin
    input ref_clk; // received from external oscillator @ 500 MHz
    input start; // received from UART Rx pin to detect start bit
    output reg clk_out; // baud rate output

    reg baud_gen_state;
    reg [15:0] clk_count;
    reg [3:0] baud_count;

    always@(negedge start) begin
        if(baud_gen_state == IDLE && reset == 0) baud_gen_state <= GEN; 
    end

    always@(posedge ref_clk) begin
        
        if(reset == 1) begin
            baud_gen_state <= IDLE;
            clk_count <= 0;
            baud_count <= 0;
        end
        else begin
            case(baud_gen_state)
                
                IDLE : begin
                    clk_out <= 0;
                end

                GEN : begin

                    if (clk_count == (CLKS_PER_BAUD/2)) begin
                        clk_out <= 1; // output 1 reference clock long pulse
                        if(baud_count == BAUD_RESET-1) begin
                            baud_gen_state <= IDLE;
                            clk_count <= 0;
                            baud_count <= 0;
                        end
                        else clk_count <= clk_count + 1;
                    end 
                    else if(clk_count == CLKS_PER_BAUD-1) begin // cycle back to 0 for capturing next input bit
                        clk_count <= 0;
                        baud_count <= baud_count + 1;
                    end
                    else begin
                        clk_out <= 0;
                        clk_count <= clk_count + 1;
                    end

                end

            endcase

        end

    end

endmodule