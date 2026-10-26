`timescale 1ns / 1ps

module fft_input_packer (
    input  wire               clk,
    input  wire               rst_n,

    input  wire signed [15:0] I_in,
    input  wire signed [15:0] Q_in,
    input  wire               valid_in,
    input  wire               last_in,

    input  wire               s_axis_data_tready,

    output reg  [31:0]        s_axis_data_tdata,
    output reg                s_axis_data_tvalid,
    output reg                s_axis_data_tlast
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axis_data_tdata  <= 32'd0;
            s_axis_data_tvalid <= 1'b0;
            s_axis_data_tlast  <= 1'b0;
        end else begin
            if (s_axis_data_tready || !s_axis_data_tvalid) begin
                s_axis_data_tdata  <= {Q_in, I_in};  // check FFT IP summary: usually imag, real
                s_axis_data_tvalid <= valid_in;
                s_axis_data_tlast  <= valid_in & last_in;
            end
        end
    end

endmodule
