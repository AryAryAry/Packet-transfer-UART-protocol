`timescale 1ns/1ps

module Rx_protocol_top(reset, ref_clk, ser_in, err_code, valid_intr);
    
    // protocol state definition
    localparam WAIT_START = 3'd0;
    localparam WAIT_SRC = 3'd1;
    localparam WAIT_DST = 3'd2;
    localparam WAIT_CNTR = 3'd3;
    localparam WAIT_TYPE = 3'd4;
    localparam WAIT_DATA = 3'd5;
    localparam WAIT_CRC_8 = 3'd6;
    localparam WAIT_STOP = 3'd7;

    // receiving device defaults
    localparam REF_CLK_PERIOD = 2; // in ns
    localparam TMOUT = 10000000; // in ns ~ 10ms
    localparam START_SEQ = 8'b10101010;
    localparam STOP_SEQ = 8'b01010101;
    localparam DEV_ADDR_H = 8'h01;
    localparam DEV_ADDR_L = 8'h23;
    localparam CRC8_POLY = 9'b100000111; // x^8 + x^2 + x + 1 CRC-8 CCITT Polynomial
    localparam DATA_BITS = 18*8; // bits to be covered under CRC check
    localparam CYC_TIMEOUT = TMOUT/REF_CLK_PERIOD;

    // error codes
    localparam NO_ERR = 3'd0; //default
    localparam ERR_PAR = 3'd1; // parity bit error in any byte
    localparam ERR_TMOUT = 3'd2; // timeout - 1ms without valid data
    localparam ERR_DEST_ADDR = 3'd3; // destination addr != device address
    localparam ERR_PACKET_CNT = 3'd4; // packet count for packet type P <= previous packet count
    localparam ERR_CRC = 3'd5; // CRC check failed 

    reg [2:0] state; // protocol state

    // inputs
    input reset;
    input ref_clk;
    input ser_in;
    
    // outputs
    output reg [2:0] err_code; // 3-bit error code
    output reg valid_intr; // pulsed high if no errors found

    // UART Rx output pins
    wire [7:0] par_out;
    wire Rx_valid;
    wire err_par;
    wire err_stop;

    // internal registers
    reg int_reset; // internal reset interrupt
    reg [23:0] timeout_count; // timeout counter - max value ~ 500k
    reg [DATA_BITS-1:0] crc_store; // shift register to store input data for CRC check
    reg reg_read; // signifies data has been captured
    reg [2:0] state_cnt; // considering max possible count == 8 for data bytes
    reg [23:0] tmp; // considering max packet section size = 4 bytes (packet count) over the frame, temp register should be {3 byte previous, current input byte}
    reg [7:0] prev_pkt_cnt; // last packet count

    // CRC check registers
    localparam MAX_SHIFT = 144; // 18*8 bits shifted left
    reg crc_read; // crc_check start
    reg crc_finish; // crc_check done
    reg [8:0] crc_shift; // 8+1 bits shift reg 
    reg [7:0] shift_cnt; // track operation progress 

    // instantiating interface and baud generator

    baud_gen baud_gen_inst(.reset(reset),
                            .ref_clk(ref_clk),
                            .start(ser_in),
                            .clk_out(baud_clk)
                            );

    UART_Rx UART_Rx_inst(.reset(reset),
                        .baud_clk(baud_clk),
                        .ser_in(ser_in),
                        .Rx_valid(Rx_valid),
                        .par_out(par_out),
                        .err_par(err_par),
                        .err_stop(err_stop)
                        );

    always@(posedge reset) begin
        int_reset <= 0;
        state <= WAIT_START;
        timeout_count <= 0;
        err_code <= 3'd0;
        valid_intr <= 0;
        crc_store <= 144'd0;
        reg_read <= 0;
        state_cnt <= 0;
        tmp <= 0;
        prev_pkt_cnt <= 0;
        crc_read <= 0;
        crc_shift <= 0;
        shift_cnt <= 0;
        crc_finish <= 0;
    end

    always@(posedge ref_clk) begin

        if (int_reset) begin
            int_reset <= 0;
            state <= WAIT_START;
            timeout_count <= 0;
            err_code <= 0;
            valid_intr <= 0;
            crc_store <= 144'd0;
            reg_read <= 0;
            state_cnt <= 0;
            tmp <= 0;
            prev_pkt_cnt <= 0;
            crc_read <= 0;
            crc_shift <= 0;
            shift_cnt <= 0;
            crc_finish <= 0;
        end
        else begin

            timeout_count <= timeout_count + 1;
            if(timeout_count == CYC_TIMEOUT && !Rx_valid) begin
                err_code <= ERR_TMOUT;
                int_reset <= 1;
            end

            if(err_par) begin
                int_reset <= 1;
            end

            if(!Rx_valid) reg_read <= 0; // set register ready for new input byte
            
            if(Rx_valid && !reg_read) begin // check for valid data and read into internal register

                reg_read <= 1;
                timeout_count <= 0;

                case (state)

                    WAIT_START:

                        if(par_out == START_SEQ) begin
                            if(state_cnt < 1) begin 
                                state_cnt <= state_cnt + 1;
                            end
                            else begin
                                state_cnt <= 0;
                                state <= WAIT_SRC; 
                            end
                        end
                        else begin
                            int_reset <= 1;
                        end

                    WAIT_SRC: begin
                        
                        if(state_cnt < 1) // more SRC BYTEs to come
                            state_cnt <= state_cnt + 1;
                        else begin // ALL SRC BYTEs received
                            state_cnt <= 0;
                            state <= WAIT_DST;
                        end

                        crc_store <= {crc_store[DATA_BITS-9:0],par_out}; // push 8 bits to LSB of register
                    
                    end

                    WAIT_DST: begin
                            
                        tmp <= {tmp[15:0], par_out}; // push 8 bits

                        if(state_cnt < 1) begin // more DST BYTEs to receive
                            state_cnt <= state_cnt + 1;
                        end
                        else begin // all DST BYTEs received
                            if({tmp[8:0],par_out} == {DEV_ADDR_L,DEV_ADDR_H}) begin // device addr - dest addr match
                                crc_store <= {crc_store[DATA_BITS-17:0],tmp[7:0],par_out}; // push 2 dst bytes 
                                state <= WAIT_CNTR;
                                state_cnt <= 0;
                            end
                            else begin
                                err_code <= ERR_DEST_ADDR; // dest addr not matching device addr
                                int_reset <= 1;
                            end
                            state_cnt <= 0;
                        end
                    end

                    WAIT_CNTR: begin

                        tmp <= {tmp[15:0], par_out}; // push 1 byte

                        if(state_cnt < 3) begin // more PCKT_CNTR BYTEs to receive
                            state_cnt <= state_cnt + 1;
                        end
                        else begin // all DST BYTEs received
                            if({tmp[23:0],par_out} > prev_pkt_cnt) begin // receiving packet for this device
                                crc_store <= {crc_store[DATA_BITS-33:0],tmp[23:0],par_out}; // push 4 pckt_count bytes
                                prev_pkt_cnt <= {tmp[23:0],par_out};
                                state <= WAIT_TYPE;
                            end
                            else begin
                                err_code <= ERR_DEST_ADDR; // dest addr not matching device addr
                                int_reset <= 1;
                            end
                            state_cnt <= 0;
                        end
                    end

                    WAIT_TYPE: begin

                        crc_store <= {crc_store[DATA_BITS-9:0],par_out}; // push 1 pkt_type byte 
                        state <= WAIT_DATA;
                    end

                    WAIT_DATA: begin

                        if(state_cnt < 7) begin 
                            state_cnt <= state_cnt + 1;
                        end
                        else begin
                            state_cnt <= 0;
                            state <= WAIT_CRC_8;
                        end
                        crc_store <= {crc_store[DATA_BITS-9:0],par_out}; // push 8 bits from LSB of register
                    end

                    WAIT_CRC_8: begin
                            
                        crc_store <= {crc_store[DATA_BITS-9:0],par_out}; // push 1 pkt_type byte 
                        state <= WAIT_STOP;
                        crc_read <= 1; // signal CRC checker to start operation
                    end

                    WAIT_STOP: begin

                        if(par_out == STOP_SEQ) begin
                            if(state_cnt < 1) begin 
                                state_cnt <= state_cnt + 1;
                            end
                            else begin
                                state_cnt <= 0;
                                valid_intr <= 1;
                                state <= WAIT_START; 
                            end
                        end
                        else begin
                            int_reset <= 1;
                        end
                    end

                endcase
            end
        end

        // CRC checker logic over 18 bytes of frame excluding start/stop bytes

        if(crc_read) begin    
            if(shift_cnt == MAX_SHIFT) begin
                crc_finish <= 1;
                crc_read <= 0;
            end
            else begin
                if(crc_shift[8]) begin // MSB 1
                   crc_shift <= crc_shift ^ CRC8_POLY; 
                end
                else begin // Shift left to get MSB 1
                    crc_shift <= {crc_shift[7:0], crc_store[DATA_BITS-1]}; // shift leading bit of stored data 
                    crc_store <= {crc_store[DATA_BITS-2:0],1'b0}; // shift stored data left
                    shift_cnt <= shift_cnt + 1; // increase count
                end
            end
        end

        if(crc_finish) begin
            if(crc_shift != 0) begin
                err_code <= ERR_CRC; 
                int_reset <= 1; 
            end
        end

    end

endmodule