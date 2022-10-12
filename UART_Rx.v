`timescale 1ns/1ps

module UART_Rx(reset, baud_clk, ser_in, Rx_valid, par_out, err_par, err_stop);

    // number of bauds for frame sections
    localparam BAUD_START = 1;
    localparam BAUD_DATA = 8;
    localparam BAUD_PARITY = 1;
    localparam BAUD_STOP = 2;
    // localparam BAUD_RESET = BAUD_START + BAUD_DATA +  BAUD_PARITY + BAUD_STOP;

    localparam REF_CLK_PERIOD = 2; // in ns, giving design reference clk_freq of 500 Mhz
    localparam BAUD_PERIOD = 30518; // in ns, based on baud rate of 32768 bps
    localparam CLKS_PER_BAUD = BAUD_PERIOD/REF_CLK_PERIOD;

    localparam IDLE = 3'd0; // Rx idle
    localparam START = 3'd1; // reception started at negedge
    localparam DATA = 3'd2; // data being read
    localparam PARITY = 3'd3; // parity bit read
    localparam STOP = 3'd4; // stop bits being received

    localparam EVEN_PAR = 1'b0; // result for even parity
    localparam ODD_PAR = 1'b1; // result for odd parity

    localparam NO_ERR = 1'b0; // valid data output
    localparam PARITY_ERR = 1'b1; // parity check failed
    localparam STOP_ERR = 1'b1; // stop bit low

    input reset; // universal reset pin, sets internal registers to 0
    input baud_clk;  // baud pulses receieved from baud_gen
    input ser_in; // serial input from UARt device
    
    output reg [7:0] par_out; // parallel Rx output to host
    output reg Rx_valid; // high when data received and no parity error
    output reg err_par; // 1'b0 - no error | 1'b1 - parity error
    output reg err_stop; // 1'b0 - no error | 1'b1 - stop bit low error

    reg [2:0] Rx_state; // Rx states as described above
    reg [3:0] baud_count; // bauds received after start bit
    reg [7:0] Rx_shift; // shift reg to hold input serial data, LSB first
    reg parity_check; // continuous even parity check | ( 0 - even parity, 1 - odd parity ) after data bauds 
    reg parity_bit; // receive parity bit in this register

    always@(negedge ser_in) begin
        if(Rx_state == IDLE) begin
            Rx_state <= START;
            Rx_valid <= 0;
            par_out <= 8'd0;
            err_par <= 1'd0;
            err_stop <= 1'd0;
            Rx_shift <= 0; 
            parity_check <= 1'b0;
            parity_bit <= 1'b0;
        end
    end

    always@(posedge reset) Rx_state <= IDLE;

    always@(posedge baud_clk) begin
        
        case(Rx_state)

            START: begin
                baud_count <= 0;
                Rx_state <= Rx_state + 1;
            end
            
            DATA: begin

                Rx_shift <= {Rx_shift[6:0],ser_in}; // shift data from LSB to MSB 
                baud_count <= baud_count + 1;
                parity_check <= parity_check ^ ser_in; // update parity check register
                if(baud_count == BAUD_DATA-1) begin
                    Rx_state <= Rx_state + 1;
                    baud_count <= 0;
                end

            end

            PARITY: begin
                
                parity_bit <= ser_in;
                Rx_state <= Rx_state + 1;                

            end

            STOP: begin

                if(parity_bit^parity_check) begin // if parity_check != parity_bit received

                    err_par <= PARITY_ERR;
                    par_out <= 8'b0;

                end 
                else begin

                    err_par <= NO_ERR;
                    par_out <= Rx_shift;
                    Rx_valid <= 1'b1;

                end

                baud_count <= baud_count + 1;

                if(!ser_in) err_stop <= STOP_ERR;
                else err_stop <=  NO_ERR;

                if(baud_count == BAUD_STOP - 1) Rx_state <= IDLE; 

            end

        endcase

    end

endmodule
