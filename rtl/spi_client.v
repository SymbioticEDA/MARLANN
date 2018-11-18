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
            data_in[7-in_bit] <= i_mosi;
            in_bit <= in_bit + 1;
            if(in_bit == 7)
                first_byte <= 0;
        end
    end

    always @(negedge i_spi_clk, posedge i_spi_cs) begin
        if(i_spi_cs) begin                  // reset state
            out_bit <= 0;
        end else begin
            o_miso <= data_out[7-out_bit];
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
            data_in_state = DATA_IN_WAIT;
            data_out_state = DATA_OUT_WAIT;
            o_data_in_start <= 0;
            o_data_out_ready <= 0;
            start_status <= 0;
        end

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
endmodule
