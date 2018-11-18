`default_nettype none
module spi_client (
    input               i_clock,
    input               i_reset,
    output              o_active,           // high whenever chip selected

    input               i_spi_clk,          // spi clock
    input               i_spi_cs,           // spi chip select, low to select

    output reg          o_miso,             // output to master
    input               i_mosi,             // input from master
   
    output reg          o_data_in_valid,    // data from master is ready to read on the data_in_data reg
    output reg          o_data_in_start,    // high for first byte received after cs goes low
    output reg [7:0]    o_data_in_data,     // data register from master

    input               i_data_out_valid,   // data in the input data bus is valid to read
    output reg          o_data_out_ready,   // data has been registered
    input [7:0]         i_data_out_data     // input data to send to the master
);


    assign o_active = !i_spi_cs;

    // data coming from master goes here
    reg [2:0] in_bit = 0;
    reg [7:0] data_in = 0;

    // data to send goes here
    reg [2:0] out_bit = 0;
    reg [7:0] data_out = 0;


    reg first_byte = 0;
    reg start_status = 0; // registers data_in_start


    always @(posedge i_spi_clk, posedge i_spi_cs) begin
        if(i_spi_cs) begin                  // reset state
            in_bit <= 0;
            first_byte <= 1;
        end else begin                      // receiving data
            data_in[3'd7-in_bit] <= i_mosi;
            in_bit <= in_bit + 1;
            if(in_bit == 7)
                first_byte <= 0;
        end
    end

    always @(negedge i_spi_clk, posedge i_spi_cs) begin
        if(i_spi_cs) begin                  // reset state
            out_bit <= 0;
        end else begin
            o_miso <= data_out[3'd7-out_bit];
            out_bit <= out_bit + 1;
        end
    end

    localparam DATA_IN_WAIT = 0;
    localparam DATA_IN_RX = 1;
    localparam DATA_IN_READY = 2;
    localparam DATA_IN_ENDSTATE = 3;
    reg [$clog2(DATA_IN_ENDSTATE)-1:0] data_in_state = DATA_IN_WAIT;

    localparam DATA_OUT_WAIT = 0;
    localparam DATA_OUT_TX = 1;
    localparam DATA_OUT_ENDSTATE = 2;
    reg [$clog2(DATA_OUT_ENDSTATE)-1:0] data_out_state = DATA_OUT_WAIT;

    always @(posedge i_clock) begin
        if(i_reset) begin
            data_in_state <= DATA_IN_WAIT;
            data_out_state <= DATA_OUT_WAIT;
            o_data_in_start <= 0;
            o_data_out_ready <= 0;
            start_status <= 0;
        end
        else begin

            case(data_in_state)
                DATA_IN_WAIT: begin
                    start_status <= first_byte;
                    o_data_in_valid <= 0;
                    if(in_bit == 1)
                        data_in_state <= DATA_IN_RX;
                end
                DATA_IN_RX: begin
                    if(in_bit == 0)
                        data_in_state <= DATA_IN_READY;
                end 
                DATA_IN_READY: begin
                    o_data_in_valid <= 1;
                    o_data_in_start <= start_status;
                    o_data_in_data <= data_in;
                    data_in_state <= DATA_IN_WAIT;
                end
            endcase

            case(data_out_state)
                DATA_OUT_WAIT: begin
                    if(out_bit == 0)
                        if(i_data_out_valid) begin
                            data_out <= i_data_out_data;
                            o_data_out_ready <= 1;
                            data_out_state <= DATA_OUT_TX;
                        end
                end
                DATA_OUT_TX: begin
                    o_data_out_ready <= 0;
                    if(out_bit == 7)
                        data_out_state <= DATA_OUT_WAIT;
                end

            endcase
        end
    end

`ifdef FORMAL
    reg [3:0] f_clk_counter;
    initial f_clk_counter = 0;

    initial restrict(i_reset);
    initial restrict(i_spi_cs);
    
    // past valid signal
    reg f_past_valid = 0;
    always @($global_clock)
        f_past_valid <= 1'b1;

    // stop reset from happening after start
    always @($global_clock)
        if(f_past_valid)
            assume(i_reset == 0);

    // clock pairing
    always @($global_clock)
    begin
        f_clk_counter <= f_clk_counter + 1'b1;
        assume(i_clock == f_clk_counter[0]);
        assume(i_spi_clk == f_clk_counter[1]);
    end

    // check everything is zeroed on the reset signal
    always @($global_clock)
        if (f_past_valid)
            if ($past(i_reset) && $rose(i_clock)) begin
                assert(data_out_state == DATA_OUT_WAIT);
                assert(data_in_state == DATA_IN_WAIT);
                assert(o_data_in_start == 0);
            end

    // spi counters are reset on cs 
    always @($global_clock)
        if (f_past_valid)
            if ($past(i_spi_cs) && $stable(i_spi_clk)) begin
                assert(in_bit == 0);
                assert(out_bit == 0);
                assert(first_byte == 1);
            end

    // counters increase
    always @($global_clock) begin
        if (f_past_valid) begin
            if(!i_spi_cs && $rose(i_spi_clk))
                assert(in_bit != $past(in_bit));
            if(!i_spi_cs && $fell(i_spi_clk))
                assert(out_bit != $past(out_bit));
        end
    end
    
    // state machines: so simple just make sure they stay bounded
    always @($global_clock) begin
        assert(data_out_state < DATA_OUT_ENDSTATE);
        assert(data_in_state < DATA_IN_ENDSTATE);
    end

    // start bit - should be low, go high on first valid byte received, then
    // go low as second received byte is registered
    always @(posedge i_clock) begin
        if(bit_counter > 7 && bit_counter < 16)
            assert(o_data_in_start);
    end

    // count bits received
    reg [7:0] bit_counter = 0;
    always @($global_clock) begin
        assume(bit_counter < 128);
        if(i_reset)
            bit_counter <= 0;
        if($rose(i_spi_clk))
            bit_counter <= bit_counter + 1;
        if($rose(i_spi_cs))
            bit_counter <= 0;
    end

         
`endif
endmodule
