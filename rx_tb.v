`timescale 1ns/1ps

module rx_tb;

    localparam REF_CLK_PERIOD = 2; // in ns, giving design reference clk_freq of 500 Mhz
    localparam BAUD_PERIOD = 30518; // in ns, based on baud rate of 32768 bps
    localparam CLKS_PER_BAUD = BAUD_PERIOD/REF_CLK_PERIOD;

    // testbench variables
    localparam N_SAMPLES = 5;
    integer clk_count; // clock count to keep track of sending bits
    integer ref_clk_count; // global clock count
    reg [11:0] Rx_samples [0:N_SAMPLES-1]; // memory to store sample bits
    integer baud_count; // number of sample bits sent
    integer sample_i;
    reg send_status; // to enable data transfer

    reg reset; // global reset
    reg ser_in; // serial input pin from host

    //baud_gen pins
    reg ref_clk;

    wire baud_clk; // baud_gen to UART_Tx

    // UART Rx pins
    wire [7:0] par_out;
    wire Rx_valid;
    wire err_par;
    wire err_stop;

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
    
    initial begin
        reset <= 0;
        ser_in <= 1;
        ref_clk <= 0;
        clk_count <= 0;
        ref_clk_count <= 0;
        baud_count <= 0;
        send_status <= 0;
        sample_i <= 0;
        $readmemb("sample_in.mem", Rx_samples);
    end

    always begin
        #(REF_CLK_PERIOD/2) ref_clk = ~ref_clk;
    end

    initial begin // reset the whole design
        #(REF_CLK_PERIOD/4) reset <= 1;
        #(REF_CLK_PERIOD/2) reset <= 0;
    end

    always@(posedge ref_clk) begin
        
        ref_clk_count <= ref_clk_count + 1;

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