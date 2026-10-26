`timescale 1ns / 1ps


module FFT_Frame_Counter#(
    parameter integer NFFT = 2048,
    parameter integer INDEX_WIDTH = 11
)(
    input  wire               clk,
    input  wire               rst_n,

    input  wire signed [15:0] I_in,
    input  wire signed [15:0] Q_in,
    input  wire               valid_in,

    output reg  signed [15:0] I_out,
    output reg  signed [15:0] Q_out,
    output reg                valid_out,
    output reg                last_out,
    output reg  [INDEX_WIDTH-1:0] sample_index
);

    localparam integer LAST_INDEX = NFFT - 1;
    reg [INDEX_WIDTH-1:0] next_sample_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            I_out             <= 16'sd0;
            Q_out             <= 16'sd0;
            valid_out         <= 1'b0;
            last_out          <= 1'b0;
            sample_index      <= {INDEX_WIDTH{1'b0}};
            next_sample_index <= {INDEX_WIDTH{1'b0}};
        end else begin
            valid_out <= valid_in;
            last_out  <= 1'b0;

            if (valid_in) begin
                I_out        <= I_in;
                Q_out        <= Q_in;
                sample_index <= next_sample_index;

                if (next_sample_index == LAST_INDEX[INDEX_WIDTH-1:0]) begin
                    last_out          <= 1'b1;
                    next_sample_index <= {INDEX_WIDTH{1'b0}};
                end else begin
                    next_sample_index <= next_sample_index + 1'b1;
                end
            end
        end
    end

endmodule
