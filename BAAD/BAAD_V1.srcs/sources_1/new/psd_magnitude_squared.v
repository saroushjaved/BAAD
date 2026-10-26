module psd_magnitude_squared(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire signed [15:0]   fft_re,
    input  wire signed [15:0]   fft_im,
    input  wire [10:0]          fft_bin,
    input  wire                 fft_valid,
    input  wire                 fft_last,
    input  wire                 fft_overflow,

    output reg  [32:0]          psd_power,
    output reg  [10:0]          psd_bin,
    output reg                  psd_valid,
    output reg                  psd_last,
    output reg                  psd_overflow
);

    reg [31:0] re_sq;
    reg [31:0] im_sq;

    reg [10:0] bin_d1;
    reg        valid_d1;
    reg        last_d1;
    reg        overflow_d1;

    always @(posedge clk) begin
        if (!rst_n) begin
            re_sq        <= 32'd0;
            im_sq        <= 32'd0;
            bin_d1       <= 11'd0;
            valid_d1     <= 1'b0;
            last_d1      <= 1'b0;
            overflow_d1  <= 1'b0;

            psd_power    <= 33'd0;
            psd_bin      <= 11'd0;
            psd_valid    <= 1'b0;
            psd_last     <= 1'b0;
            psd_overflow <= 1'b0;
        end else begin
            // Stage 1: square real and imaginary parts
            re_sq       <= fft_re * fft_re;
            im_sq       <= fft_im * fft_im;
            bin_d1      <= fft_bin;
            valid_d1    <= fft_valid;
            last_d1     <= fft_last;
            overflow_d1 <= fft_overflow;

            // Stage 2: sum squares
            psd_power    <= {1'b0, re_sq} + {1'b0, im_sq};
            psd_bin      <= bin_d1;
            psd_valid    <= valid_d1;
            psd_last     <= last_d1;
            psd_overflow <= overflow_d1;
        end
    end

endmodule
