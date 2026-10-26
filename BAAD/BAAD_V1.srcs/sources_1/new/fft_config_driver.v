module fft_config_driver #(
    parameter [11:0] SCALE_SCH = 12'b01_10_10_10_10_11, // conservative
    parameter        FWD_INV   = 1'b1                   // 1 = FFT, 0 = IFFT
)(
    input  wire        aclk,
    input  wire        aresetn,

    output reg  [15:0] s_axis_config_tdata,
    output reg         s_axis_config_tvalid,
    input  wire        s_axis_config_tready,

    output reg         config_done
);

    wire [15:0] config_word;

    // FFT summary:
    // bit 0    = FWD_INV
    // bits 12:1 = SCALE_SCH
    // bits 15:13 = padding
    assign config_word = {3'b000, SCALE_SCH, FWD_INV};

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axis_config_tdata  <= config_word;
            s_axis_config_tvalid <= 1'b0;
            config_done          <= 1'b0;
        end else begin
            s_axis_config_tdata <= config_word;

            if (!config_done) begin
                s_axis_config_tvalid <= 1'b1;

                if (s_axis_config_tvalid && s_axis_config_tready) begin
                    s_axis_config_tvalid <= 1'b0;
                    config_done          <= 1'b1;
                end
            end else begin
                s_axis_config_tvalid <= 1'b0;
            end
        end
    end

endmodule
