`timescale 1ns / 1ps

module psd_hann_multiply (
    input  wire               clk,
    input  wire               rst_n,

    input  wire signed [15:0] I_in,
    input  wire signed [15:0] Q_in,
    input  wire               valid_in,
    input  wire               last_in,

    input  wire signed [15:0] coeff_in,
    input  wire               coeff_valid,

    output reg  signed [15:0] I_win,
    output reg  signed [15:0] Q_win,
    output reg                valid_out,
    output reg                last_out
);

    reg signed [15:0] I_d1;
    reg signed [15:0] Q_d1;
    reg               last_d1;
    reg               valid_d1;

    wire signed [31:0] I_product;
    wire signed [31:0] Q_product;

    assign I_product = $signed({{16{I_d1[15]}}, I_d1}) *
                       $signed({{16{coeff_in[15]}}, coeff_in});
    assign Q_product = $signed({{16{Q_d1[15]}}, Q_d1}) *
                       $signed({{16{coeff_in[15]}}, coeff_in});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            I_d1      <= 16'sd0;
            Q_d1      <= 16'sd0;
            last_d1   <= 1'b0;
            valid_d1  <= 1'b0;

            I_win     <= 16'sd0;
            Q_win     <= 16'sd0;
            valid_out <= 1'b0;
            last_out  <= 1'b0;
        end else begin
            // Delay data to match 1-cycle ROM latency
            I_d1     <= I_in;
            Q_d1     <= Q_in;
            last_d1  <= last_in;
            valid_d1 <= valid_in;

            // ROM coefficient and delayed sample are aligned here.
            I_win <= I_product >>> 15;
            Q_win <= Q_product >>> 15;
            valid_out <= valid_d1 & coeff_valid;
            last_out  <= last_d1 & valid_d1 & coeff_valid;
        end
    end

endmodule
