`timescale 1ns / 1ps

module hann_rom_q15 #(
    parameter integer NFFT = 2048,
    parameter integer ADDR_WIDTH = 11,
    parameter MEM_FILE = "hann_2048_q15.mem"
)(
    input  wire                    clk,
    input  wire                    rst_n,

    input  wire [ADDR_WIDTH-1:0]   addr,
    input  wire                    valid_in,

    output reg  signed [15:0]      coeff_out,
    output reg  [ADDR_WIDTH-1:0]   addr_out,
    output reg                     valid_out
);

    (* rom_style = "block" *)
    reg signed [15:0] rom [0:NFFT-1];

    initial begin
        $readmemh(MEM_FILE, rom);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coeff_out <= 16'sd0;
            addr_out  <= {ADDR_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else begin
            coeff_out <= rom[addr];
            addr_out  <= addr;
            valid_out <= valid_in;
        end
    end

endmodule
