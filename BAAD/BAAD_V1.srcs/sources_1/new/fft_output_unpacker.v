module fft_output_unpacker (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [31:0] m_axis_data_tdata,
    input  wire [23:0] m_axis_data_tuser,
    input  wire        m_axis_data_tvalid,
    input  wire        m_axis_data_tlast,

    output reg  signed [15:0] fft_re,
    output reg  signed [15:0] fft_im,
    output reg  [10:0]        fft_bin,
    output reg                fft_overflow,
    output reg                fft_valid,
    output reg                fft_last
);

    reg drop_first_frame;

    always @(posedge clk) begin
        if (!rst_n) begin
            fft_re       <= 16'sd0;
            fft_im       <= 16'sd0;
            fft_bin      <= 11'd0;
            fft_overflow <= 1'b0;
            fft_valid    <= 1'b0;
            fft_last     <= 1'b0;
            drop_first_frame <= 1'b1;
        end else begin
            if (drop_first_frame) begin
                fft_re       <= 16'sd0;
                fft_im       <= 16'sd0;
                fft_bin      <= 11'd0;
                fft_overflow <= 1'b0;
                fft_valid    <= 1'b0;
                fft_last     <= 1'b0;

                if (m_axis_data_tvalid && m_axis_data_tlast) begin
                    drop_first_frame <= 1'b0;
                end
            end else begin
                fft_valid <= m_axis_data_tvalid;
                fft_last  <= m_axis_data_tvalid & m_axis_data_tlast;

                if (m_axis_data_tvalid) begin
                    fft_re       <= m_axis_data_tdata[15:0];
                    fft_im       <= m_axis_data_tdata[31:16];
                    fft_bin      <= m_axis_data_tuser[10:0];
                    fft_overflow <= m_axis_data_tuser[16];
                end
            end
        end
    end

endmodule
