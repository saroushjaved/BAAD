`timescale 1ns / 1ps

module bandwidth_estimator #(
    parameter integer NFFT             = 2048,
    parameter integer BIN_WIDTH        = 11,
    parameter integer SIGNED_BIN_WIDTH = BIN_WIDTH + 2,
    parameter integer POWER_WIDTH      = 33,
    parameter integer SUM_WIDTH        = POWER_WIDTH + BIN_WIDTH + 1,
    parameter integer FRAME_IDLE_TIMEOUT_CYCLES = 4 * NFFT
)(
    input  wire                               clk,
    input  wire                               rst_n,

    input  wire [BIN_WIDTH-1:0]               psd_bin,
    input  wire [POWER_WIDTH-1:0]             psd_power,
    input  wire                               psd_valid,
    input  wire                               psd_last,
    input  wire                               psd_overflow,

    input  wire [POWER_WIDTH-1:0]             cfg_power_threshold,

    output reg                                estimate_valid,
    output reg  [31:0]                        frame_id,
    output reg                                frame_error,
    output reg                                active_found,
    output reg                                overflow_seen,

    output reg  [BIN_WIDTH:0]                 frame_bin_count,
    output reg  [BIN_WIDTH:0]                 active_bin_count,
    output reg  [BIN_WIDTH:0]                 overflow_count,

    output reg  [BIN_WIDTH-1:0]               low_bin,
    output reg  [BIN_WIDTH-1:0]               high_bin,
    output reg  signed [SIGNED_BIN_WIDTH-1:0] low_signed_bin,
    output reg  signed [SIGNED_BIN_WIDTH-1:0] high_signed_bin,
    output reg  [BIN_WIDTH:0]                 bw_span_bins,
    output reg  [BIN_WIDTH:0]                 bw_edge_bins,

    output reg  [BIN_WIDTH-1:0]               peak_bin,
    output reg  signed [SIGNED_BIN_WIDTH-1:0] peak_signed_bin,
    output reg  [POWER_WIDTH-1:0]             peak_power,
    output reg  [POWER_WIDTH-1:0]             min_power,

    output reg  [SUM_WIDTH-1:0]               total_power,
    output reg  [SUM_WIDTH-1:0]               active_power
);

    localparam [BIN_WIDTH-1:0] HALF_NFFT_BIN = NFFT / 2;
    localparam signed [SIGNED_BIN_WIDTH-1:0] NFFT_SIGNED = NFFT;
    localparam [BIN_WIDTH:0] NFFT_COUNT = NFFT;

    wire signed [SIGNED_BIN_WIDTH-1:0] unsigned_bin_ext;
    wire signed [SIGNED_BIN_WIDTH-1:0] signed_bin;
    wire [SIGNED_BIN_WIDTH-1:0] signed_bin_abs_full;
    wire [BIN_WIDTH:0] abs_signed_bin;
    wire active_bin;

    assign unsigned_bin_ext = $signed({{(SIGNED_BIN_WIDTH-BIN_WIDTH){1'b0}}, psd_bin});
    assign signed_bin = (psd_bin >= HALF_NFFT_BIN) ?
                        (unsigned_bin_ext - NFFT_SIGNED) :
                        unsigned_bin_ext;
    assign signed_bin_abs_full = signed_bin[SIGNED_BIN_WIDTH-1] ? -signed_bin : signed_bin;
    assign abs_signed_bin = signed_bin_abs_full[BIN_WIDTH:0];
    assign active_bin = psd_valid && (psd_power > cfg_power_threshold);

    reg [31:0] frame_counter;
    reg [31:0] idle_cycles;

    reg cur_active_found;
    reg cur_overflow_seen;
    reg cur_frame_error;

    reg [BIN_WIDTH:0] cur_bin_count;
    reg [BIN_WIDTH:0] cur_active_count;
    reg [BIN_WIDTH:0] cur_overflow_count;

    reg [BIN_WIDTH-1:0] cur_low_bin;
    reg [BIN_WIDTH-1:0] cur_high_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] cur_low_signed_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] cur_high_signed_bin;
    reg [BIN_WIDTH:0] cur_edge_bins;

    reg [BIN_WIDTH-1:0] cur_peak_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] cur_peak_signed_bin;
    reg [POWER_WIDTH-1:0] cur_peak_power;
    reg [POWER_WIDTH-1:0] cur_min_power;

    reg [SUM_WIDTH-1:0] cur_total_power;
    reg [SUM_WIDTH-1:0] cur_active_power;

    reg next_active_found;
    reg next_overflow_seen;
    reg next_frame_error;

    reg [BIN_WIDTH:0] next_bin_count;
    reg [BIN_WIDTH:0] next_active_count;
    reg [BIN_WIDTH:0] next_overflow_count;

    reg [BIN_WIDTH-1:0] next_low_bin;
    reg [BIN_WIDTH-1:0] next_high_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] next_low_signed_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] next_high_signed_bin;
    reg [BIN_WIDTH:0] next_edge_bins;
    reg [BIN_WIDTH:0] next_span_bins;

    reg [BIN_WIDTH-1:0] next_peak_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] next_peak_signed_bin;
    reg [POWER_WIDTH-1:0] next_peak_power;
    reg [POWER_WIDTH-1:0] next_min_power;

    reg [SUM_WIDTH-1:0] next_total_power;
    reg [SUM_WIDTH-1:0] next_active_power;

    always @* begin
        next_active_found    = cur_active_found;
        next_overflow_seen   = cur_overflow_seen;
        next_frame_error     = cur_frame_error;
        next_bin_count       = cur_bin_count;
        next_active_count    = cur_active_count;
        next_overflow_count  = cur_overflow_count;
        next_low_bin         = cur_low_bin;
        next_high_bin        = cur_high_bin;
        next_low_signed_bin  = cur_low_signed_bin;
        next_high_signed_bin = cur_high_signed_bin;
        next_edge_bins       = cur_edge_bins;
        next_peak_bin        = cur_peak_bin;
        next_peak_signed_bin = cur_peak_signed_bin;
        next_peak_power      = cur_peak_power;
        next_min_power       = cur_min_power;
        next_total_power     = cur_total_power;
        next_active_power    = cur_active_power;

        if (psd_valid) begin
            next_bin_count   = cur_bin_count + 1'b1;
            next_total_power = cur_total_power + {{(SUM_WIDTH-POWER_WIDTH){1'b0}}, psd_power};

            if (psd_bin != cur_bin_count[BIN_WIDTH-1:0]) begin
                next_frame_error = 1'b1;
            end

            if (psd_overflow) begin
                next_overflow_seen  = 1'b1;
                next_overflow_count = cur_overflow_count + 1'b1;
            end

            if ((cur_bin_count == {1'b0, {BIN_WIDTH{1'b0}}}) || (psd_power < cur_min_power)) begin
                next_min_power = psd_power;
            end

            if ((cur_bin_count == {1'b0, {BIN_WIDTH{1'b0}}}) || (psd_power > cur_peak_power)) begin
                next_peak_power      = psd_power;
                next_peak_bin        = psd_bin;
                next_peak_signed_bin = signed_bin;
            end

            if (active_bin) begin
                next_active_count = cur_active_count + 1'b1;
                next_active_power = cur_active_power + {{(SUM_WIDTH-POWER_WIDTH){1'b0}}, psd_power};

                if (!cur_active_found) begin
                    next_active_found    = 1'b1;
                    next_low_bin         = psd_bin;
                    next_high_bin        = psd_bin;
                    next_low_signed_bin  = signed_bin;
                    next_high_signed_bin = signed_bin;
                    next_edge_bins       = abs_signed_bin;
                end else begin
                    if (signed_bin < cur_low_signed_bin) begin
                        next_low_bin        = psd_bin;
                        next_low_signed_bin = signed_bin;
                    end

                    if (signed_bin > cur_high_signed_bin) begin
                        next_high_bin        = psd_bin;
                        next_high_signed_bin = signed_bin;
                    end

                    if (abs_signed_bin > cur_edge_bins) begin
                        next_edge_bins = abs_signed_bin;
                    end
                end
            end
        end

        if (next_active_found) begin
            next_span_bins = next_high_signed_bin - next_low_signed_bin;
        end else begin
            next_span_bins = {1'b0, {BIN_WIDTH{1'b0}}};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            estimate_valid      <= 1'b0;
            frame_id            <= 32'd0;
            frame_error         <= 1'b0;
            active_found        <= 1'b0;
            overflow_seen       <= 1'b0;
            frame_bin_count     <= {1'b0, {BIN_WIDTH{1'b0}}};
            active_bin_count    <= {1'b0, {BIN_WIDTH{1'b0}}};
            overflow_count      <= {1'b0, {BIN_WIDTH{1'b0}}};
            low_bin             <= {BIN_WIDTH{1'b0}};
            high_bin            <= {BIN_WIDTH{1'b0}};
            low_signed_bin      <= {SIGNED_BIN_WIDTH{1'b0}};
            high_signed_bin     <= {SIGNED_BIN_WIDTH{1'b0}};
            bw_span_bins        <= {1'b0, {BIN_WIDTH{1'b0}}};
            bw_edge_bins        <= {1'b0, {BIN_WIDTH{1'b0}}};
            peak_bin            <= {BIN_WIDTH{1'b0}};
            peak_signed_bin     <= {SIGNED_BIN_WIDTH{1'b0}};
            peak_power          <= {POWER_WIDTH{1'b0}};
            min_power           <= {POWER_WIDTH{1'b0}};
            total_power         <= {SUM_WIDTH{1'b0}};
            active_power        <= {SUM_WIDTH{1'b0}};

            frame_counter       <= 32'd0;
            idle_cycles         <= 32'd0;
            cur_active_found    <= 1'b0;
            cur_overflow_seen   <= 1'b0;
            cur_frame_error     <= 1'b0;
            cur_bin_count       <= {1'b0, {BIN_WIDTH{1'b0}}};
            cur_active_count    <= {1'b0, {BIN_WIDTH{1'b0}}};
            cur_overflow_count  <= {1'b0, {BIN_WIDTH{1'b0}}};
            cur_low_bin         <= {BIN_WIDTH{1'b0}};
            cur_high_bin        <= {BIN_WIDTH{1'b0}};
            cur_low_signed_bin  <= {SIGNED_BIN_WIDTH{1'b0}};
            cur_high_signed_bin <= {SIGNED_BIN_WIDTH{1'b0}};
            cur_edge_bins       <= {1'b0, {BIN_WIDTH{1'b0}}};
            cur_peak_bin        <= {BIN_WIDTH{1'b0}};
            cur_peak_signed_bin <= {SIGNED_BIN_WIDTH{1'b0}};
            cur_peak_power      <= {POWER_WIDTH{1'b0}};
            cur_min_power       <= {POWER_WIDTH{1'b1}};
            cur_total_power     <= {SUM_WIDTH{1'b0}};
            cur_active_power    <= {SUM_WIDTH{1'b0}};
        end else begin
            estimate_valid <= 1'b0;
            if (psd_valid || cur_bin_count == 0)
                idle_cycles <= 0;
            else if (idle_cycles < FRAME_IDLE_TIMEOUT_CYCLES)
                idle_cycles <= idle_cycles + 1'b1;

            // Bound a frame by its sample count even if TLAST is lost. Also
            // close partial frames after a bounded stall so the controller sees
            // the error and the next naturally ordered frame can recover.
            if ((psd_valid && (psd_last || next_bin_count >= NFFT_COUNT)) ||
                (cur_bin_count != 0 && idle_cycles == FRAME_IDLE_TIMEOUT_CYCLES - 1)) begin
                idle_cycles      <= 0;
                estimate_valid   <= 1'b1;
                frame_id         <= frame_counter;
                frame_error      <= next_frame_error | (next_bin_count != NFFT_COUNT) | !psd_valid | !psd_last;
                active_found     <= next_active_found;
                overflow_seen    <= next_overflow_seen;
                frame_bin_count  <= next_bin_count;
                active_bin_count <= next_active_count;
                overflow_count   <= next_overflow_count;

                low_bin          <= next_active_found ? next_low_bin : {BIN_WIDTH{1'b0}};
                high_bin         <= next_active_found ? next_high_bin : {BIN_WIDTH{1'b0}};
                low_signed_bin   <= next_active_found ? next_low_signed_bin : {SIGNED_BIN_WIDTH{1'b0}};
                high_signed_bin  <= next_active_found ? next_high_signed_bin : {SIGNED_BIN_WIDTH{1'b0}};
                bw_span_bins     <= next_active_found ? next_span_bins : {1'b0, {BIN_WIDTH{1'b0}}};
                bw_edge_bins     <= next_active_found ? next_edge_bins : {1'b0, {BIN_WIDTH{1'b0}}};

                peak_bin         <= next_peak_bin;
                peak_signed_bin  <= next_peak_signed_bin;
                peak_power       <= next_peak_power;
                min_power        <= next_min_power;
                total_power      <= next_total_power;
                active_power     <= next_active_power;

                frame_counter       <= frame_counter + 1'b1;
                cur_active_found    <= 1'b0;
                cur_overflow_seen   <= 1'b0;
                cur_frame_error     <= 1'b0;
                cur_bin_count       <= {1'b0, {BIN_WIDTH{1'b0}}};
                cur_active_count    <= {1'b0, {BIN_WIDTH{1'b0}}};
                cur_overflow_count  <= {1'b0, {BIN_WIDTH{1'b0}}};
                cur_low_bin         <= {BIN_WIDTH{1'b0}};
                cur_high_bin        <= {BIN_WIDTH{1'b0}};
                cur_low_signed_bin  <= {SIGNED_BIN_WIDTH{1'b0}};
                cur_high_signed_bin <= {SIGNED_BIN_WIDTH{1'b0}};
                cur_edge_bins       <= {1'b0, {BIN_WIDTH{1'b0}}};
                cur_peak_bin        <= {BIN_WIDTH{1'b0}};
                cur_peak_signed_bin <= {SIGNED_BIN_WIDTH{1'b0}};
                cur_peak_power      <= {POWER_WIDTH{1'b0}};
                cur_min_power       <= {POWER_WIDTH{1'b1}};
                cur_total_power     <= {SUM_WIDTH{1'b0}};
                cur_active_power    <= {SUM_WIDTH{1'b0}};
            end else if (psd_valid) begin
                cur_active_found    <= next_active_found;
                cur_overflow_seen   <= next_overflow_seen;
                cur_frame_error     <= next_frame_error;
                cur_bin_count       <= next_bin_count;
                cur_active_count    <= next_active_count;
                cur_overflow_count  <= next_overflow_count;
                cur_low_bin         <= next_low_bin;
                cur_high_bin        <= next_high_bin;
                cur_low_signed_bin  <= next_low_signed_bin;
                cur_high_signed_bin <= next_high_signed_bin;
                cur_edge_bins       <= next_edge_bins;
                cur_peak_bin        <= next_peak_bin;
                cur_peak_signed_bin <= next_peak_signed_bin;
                cur_peak_power      <= next_peak_power;
                cur_min_power       <= next_min_power;
                cur_total_power     <= next_total_power;
                cur_active_power    <= next_active_power;
            end
        end
    end

endmodule
