`timescale 1ns/1ps

module protocol_tb;

    localparam REF_CLK_PERIOD = 2; // in ns, giving design reference clk_freq of 500 Mhz
    localparam BAUD_PERIOD = 30518; // in ns, based on baud rate of 32768 bps
    localparam CLKS_PER_BAUD = BAUD_PERIOD/REF_CLK_PERIOD;

    // testbench variables
    localparam N_SAMPLES = 22;
    integer clk_count; // clock count to keep track of sending bits
    integer ref_clk_count; // global clock count
    reg [11:0] Rx_samples [0:N_SAMPLES-1]; // memory to store sample bits
    integer baud_count; // number of sample bits sent
    integer sample_i; // index of next sample to send
    reg send_status; // to enable data transfer

    // input to protocol design

    reg reset; // global reset
    reg ser_in; // serial input pin from host
    reg ref_clk; // design reference clock

    // output from design 
    wire [2:0] err_code; // 3-but error code
    wire valid_intr; // valid packet received

    Rx_protocol_top protocol_inst(.reset(reset),
                                .ref_clk(ref_clk),
                                .ser_in(ser_in),
                                .err_code(err_code),
                                .valid_intr(valid_intr)
                                );
    
    initial begin
        reset <= 0;
        ser_in <= 1;
        ref_clk <= 0;
        clk_count <= 0;
        ref_clk_count <= 0;
        baud_count <= 0;
        send_status <= 0;
        sample_i <= 0;
        $readmemb("packet.mem", Rx_samples);
    end

    always begin
        #(REF_CLK_PERIOD/2) ref_clk = ~ref_clk;
    end

    initial begin // reset the whole design
        #(REF_CLK_PERIOD/4) reset <= 1;
        #(REF_CLK_PERIOD/2) reset <= 0;
    end

    always@(posedge ref_clk) begin
        
        if(ref_clk_count<4) ref_clk_count <= ref_clk_count + 1;

        if(ref_clk_count == 3) begin // initiating transfer
            send_status <= 1'b1;
        end

        if(send_status) begin
            
            clk_count <= clk_count + 1;

            if(clk_count == CLKS_PER_BAUD - 1) begin
                clk_count <= 0;
                if(baud_count == 11) begin
                    baud_count <= 0;
                    sample_i <= sample_i + 1;
                end
                else begin
                    baud_count <= baud_count + 1;
                end
                ser_in <= (Rx_samples[sample_i] >> (11 - baud_count)) & 1'b1; //  data bits sequence starts from MSB according to .mem file
            end
            
            if (sample_i ==  N_SAMPLES) $finish;

        end

    end

endmodule