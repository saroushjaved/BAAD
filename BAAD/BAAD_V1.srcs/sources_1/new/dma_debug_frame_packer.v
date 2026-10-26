`timescale 1ns / 1ps

module dma_debug_frame_packer #(
    parameter integer BIN_WIDTH        = 11,
    parameter integer SIGNED_BIN_WIDTH = BIN_WIDTH + 2,
    parameter integer POWER_WIDTH      = 33,
    parameter integer SUM_WIDTH        = POWER_WIDTH + BIN_WIDTH + 1,
    parameter integer M_WIDTH          = 16,
    parameter integer SHIFT_WIDTH      = 8
)(
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              capture_flush,

    input  wire                              capture_enable,
    input  wire                              capture_summary_enable,
    input  wire                              capture_cic_enable,
    input  wire                              capture_psd_input_enable,
    input  wire [15:0]                       packet_record_count,
    input  wire [15:0]                       cic_sample_interval,
    input  wire [15:0]                       psd_input_sample_interval,

    input  wire                              estimate_valid,
    input  wire [31:0]                       frame_id,
    input  wire                              frame_error,
    input  wire                              active_found,
    input  wire                              overflow_seen,
    input  wire [BIN_WIDTH:0]                frame_bin_count,
    input  wire [BIN_WIDTH:0]                active_bin_count,
    input  wire [BIN_WIDTH:0]                overflow_count,
    input  wire [BIN_WIDTH-1:0]              low_bin,
    input  wire [BIN_WIDTH-1:0]              high_bin,
    input  wire signed [SIGNED_BIN_WIDTH-1:0] low_signed_bin,
    input  wire signed [SIGNED_BIN_WIDTH-1:0] high_signed_bin,
    input  wire [BIN_WIDTH:0]                bw_span_bins,
    input  wire [BIN_WIDTH:0]                bw_edge_bins,
    input  wire [BIN_WIDTH-1:0]              peak_bin,
    input  wire signed [SIGNED_BIN_WIDTH-1:0] peak_signed_bin,
    input  wire [POWER_WIDTH-1:0]            peak_power,
    input  wire [POWER_WIDTH-1:0]            min_power,
    input  wire [SUM_WIDTH-1:0]              total_power,
    input  wire [SUM_WIDTH-1:0]              active_power,

    input  wire                              decision_valid,
    input  wire [31:0]                       decision_frame_id,
    input  wire [M_WIDTH-1:0]                decimation_factor_m,
    input  wire [M_WIDTH-1:0]                candidate_factor_m,
    input  wire                              m_changed,
    input  wire                              decision_error,
    input  wire                              no_active,
    input  wire [BIN_WIDTH:0]                decision_edge_bins,
    input  wire [15:0]                       stable_count,

    input  wire signed [15:0]                m_i,
    input  wire signed [15:0]                m_q,
    input  wire                              m_valid,
    input  wire [M_WIDTH-1:0]                active_decimation_factor,
    input  wire [SHIFT_WIDTH-1:0]            active_gain_shift,
    input  wire                              rate_changed,
    input  wire                              settling,
    input  wire                              cfg_error,
    input  wire                              cic_overflow,

    input  wire signed [15:0]                psd_input_i,
    input  wire signed [15:0]                psd_input_q,
    input  wire                              psd_input_valid,

    output reg  [63:0]                       m_axis_tdata,
    output reg  [7:0]                        m_axis_tkeep,
    output reg                               m_axis_tvalid,
    input  wire                              m_axis_tready,
    output reg                               m_axis_tlast,

    output wire                              busy,
    output reg                               emitted_record_pulse,
    output reg                               dropped_record_pulse,
    output reg  [31:0]                       records_emitted,
    output reg  [31:0]                       records_dropped
);

    localparam [15:0] FRAME_MAGIC       = 16'hBAAD;
    localparam [7:0]  FRAME_VERSION     = 8'h01;
    localparam [7:0]  TYPE_SUMMARY      = 8'h01;
    localparam [7:0]  TYPE_PSD_INPUT    = 8'h02;
    localparam [7:0]  TYPE_CIC_SAMPLE   = 8'h03;
    localparam [15:0] SUMMARY_WORDS     = 16'd12;
    localparam [15:0] PSD_INPUT_WORDS   = 16'd4;
    localparam [15:0] CIC_SAMPLE_WORDS  = 16'd4;

    localparam [1:0] RECORD_NONE        = 2'd0;
    localparam [1:0] RECORD_SUMMARY     = 2'd1;
    localparam [1:0] RECORD_CIC_SAMPLE  = 2'd2;
    localparam [1:0] RECORD_PSD_INPUT   = 2'd3;

    localparam integer COUNT_WIDTH      = BIN_WIDTH + 1;
    localparam integer COUNT_PAD        = 64 - (5 * COUNT_WIDTH);
    localparam integer SIGNED_BIN_PAD   = 64 - (3 * SIGNED_BIN_WIDTH);
    localparam integer RAW_BIN_PAD      = 64 - (3 * BIN_WIDTH);
    localparam integer POWER_PAD        = 64 - POWER_WIDTH;
    localparam integer SUM_PAD          = 64 - SUM_WIDTH;

    reg [31:0] cycle_counter;
    reg [1:0]  active_record_type;
    reg [3:0]  word_index;
    reg        record_tlast;
    reg [15:0] packet_record_index;
    reg packet_complete;
    reg [15:0] cic_interval_count;
    reg [15:0] psd_input_interval_count;

    reg [31:0] cap_cycle_count;
    reg [15:0] cap_flags;
    reg [31:0] cap_frame_id;
    reg [31:0] cap_decision_frame_id;

    reg [BIN_WIDTH:0] cap_frame_bin_count;
    reg [BIN_WIDTH:0] cap_active_bin_count;
    reg [BIN_WIDTH:0] cap_overflow_count;
    reg [BIN_WIDTH:0] cap_bw_span_bins;
    reg [BIN_WIDTH:0] cap_bw_edge_bins;
    reg [BIN_WIDTH-1:0] cap_low_bin;
    reg [BIN_WIDTH-1:0] cap_high_bin;
    reg [BIN_WIDTH-1:0] cap_peak_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] cap_low_signed_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] cap_high_signed_bin;
    reg signed [SIGNED_BIN_WIDTH-1:0] cap_peak_signed_bin;
    reg [POWER_WIDTH-1:0] cap_peak_power;
    reg [POWER_WIDTH-1:0] cap_min_power;
    reg [SUM_WIDTH-1:0] cap_total_power;
    reg [SUM_WIDTH-1:0] cap_active_power;

    reg [M_WIDTH-1:0] cap_decimation_factor_m;
    reg [M_WIDTH-1:0] cap_candidate_factor_m;
    reg [BIN_WIDTH:0] cap_decision_edge_bins;
    reg [15:0] cap_stable_count;

    reg signed [15:0] cap_m_i;
    reg signed [15:0] cap_m_q;
    reg signed [15:0] cap_psd_input_i;
    reg signed [15:0] cap_psd_input_q;
    reg [M_WIDTH-1:0] cap_active_decimation_factor;
    reg [SHIFT_WIDTH-1:0] cap_active_gain_shift;

    wire [15:0] live_flags;
    wire summary_request;
    wire cic_sample_take;
    wire psd_input_sample_take;
    wire packet_end_for_next_record;
    wire [15:0] active_record_words;

    assign busy = m_axis_tvalid;

    assign live_flags = {
        2'b00,
        psd_input_valid,
        m_valid,
        cic_overflow,
        cfg_error,
        settling,
        rate_changed,
        no_active,
        decision_error,
        m_changed,
        overflow_seen,
        active_found,
        frame_error,
        decision_valid,
        estimate_valid
    };

    assign summary_request = capture_enable && !packet_complete &&
                             capture_summary_enable &&
                             decision_valid;

    assign cic_sample_take = capture_enable && !packet_complete &&
                             capture_cic_enable &&
                             m_valid &&
                             (cic_interval_count == 16'd0);

    assign psd_input_sample_take = capture_enable && !packet_complete &&
                                   capture_psd_input_enable &&
                                   psd_input_valid &&
                                   (psd_input_interval_count == 16'd0);

    assign packet_end_for_next_record =
        (packet_record_count != 16'd0) &&
        ((packet_record_index + 16'd1) >= packet_record_count);

    assign active_record_words =
        (active_record_type == RECORD_SUMMARY)    ? SUMMARY_WORDS :
        (active_record_type == RECORD_CIC_SAMPLE) ? CIC_SAMPLE_WORDS :
        (active_record_type == RECORD_PSD_INPUT)  ? PSD_INPUT_WORDS :
                                                    16'd0;

    always @(*) begin
        m_axis_tkeep = 8'hff;
        m_axis_tlast = m_axis_tvalid &&
                       (word_index == (active_record_words[3:0] - 4'd1)) &&
                       record_tlast;

        case (active_record_type)
            RECORD_SUMMARY: begin
                case (word_index)
                    4'd0: m_axis_tdata = {FRAME_MAGIC, FRAME_VERSION, TYPE_SUMMARY, SUMMARY_WORDS, cap_flags};
                    4'd1: m_axis_tdata = {cap_cycle_count, cap_frame_id};
                    4'd2: m_axis_tdata = {cap_decision_frame_id, records_emitted};
                    4'd3: m_axis_tdata = {
                        {COUNT_PAD{1'b0}},
                        cap_frame_bin_count,
                        cap_active_bin_count,
                        cap_overflow_count,
                        cap_bw_span_bins,
                        cap_bw_edge_bins
                    };
                    4'd4: m_axis_tdata = {
                        {SIGNED_BIN_PAD{1'b0}},
                        cap_low_signed_bin,
                        cap_high_signed_bin,
                        cap_peak_signed_bin
                    };
                    4'd5: m_axis_tdata = {
                        {RAW_BIN_PAD{1'b0}},
                        cap_low_bin,
                        cap_high_bin,
                        cap_peak_bin
                    };
                    4'd6: m_axis_tdata = {{POWER_PAD{1'b0}}, cap_peak_power};
                    4'd7: m_axis_tdata = {{POWER_PAD{1'b0}}, cap_min_power};
                    4'd8: m_axis_tdata = {{SUM_PAD{1'b0}}, cap_total_power};
                    4'd9: m_axis_tdata = {{SUM_PAD{1'b0}}, cap_active_power};
                    4'd10: m_axis_tdata = {
                        cap_decimation_factor_m,
                        cap_candidate_factor_m,
                        cap_stable_count,
                        cap_decision_edge_bins,
                        decision_valid,
                        m_changed,
                        decision_error,
                        no_active
                    };
                    4'd11: m_axis_tdata = {
                        cap_active_decimation_factor,
                        cap_active_gain_shift,
                        cap_m_i,
                        cap_m_q,
                        3'b000,
                        m_valid,
                        cic_overflow,
                        cfg_error,
                        settling,
                        rate_changed
                    };
                    default: m_axis_tdata = 64'd0;
                endcase
            end

            RECORD_CIC_SAMPLE: begin
                case (word_index)
                    4'd0: m_axis_tdata = {FRAME_MAGIC, FRAME_VERSION, TYPE_CIC_SAMPLE, CIC_SAMPLE_WORDS, cap_flags};
                    4'd1: m_axis_tdata = {cap_cycle_count, cap_frame_id};
                    4'd2: m_axis_tdata = {
                        cap_m_i,
                        cap_m_q,
                        cap_active_decimation_factor,
                        cap_active_gain_shift,
                        3'b000,
                        m_valid,
                        cic_overflow,
                        cfg_error,
                        settling,
                        rate_changed
                    };
                    4'd3: m_axis_tdata = {
                        cap_decimation_factor_m,
                        cap_candidate_factor_m,
                        cap_stable_count,
                        records_emitted[15:0]
                    };
                    default: m_axis_tdata = 64'd0;
                endcase
            end

            RECORD_PSD_INPUT: begin
                case (word_index)
                    4'd0: m_axis_tdata = {FRAME_MAGIC, FRAME_VERSION, TYPE_PSD_INPUT, PSD_INPUT_WORDS, cap_flags};
                    4'd1: m_axis_tdata = {cap_cycle_count, cap_frame_id};
                    4'd2: m_axis_tdata = {
                        cap_psd_input_i,
                        cap_psd_input_q,
                        cap_decimation_factor_m,
                        cap_candidate_factor_m
                    };
                    4'd3: m_axis_tdata = {
                        cap_active_decimation_factor,
                        cap_active_gain_shift,
                        cap_stable_count,
                        records_emitted[15:0],
                        8'd0
                    };
                    default: m_axis_tdata = 64'd0;
                endcase
            end

            default: begin
                m_axis_tdata = 64'd0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter        <= 32'd0;
            active_record_type   <= RECORD_NONE;
            word_index           <= 4'd0;
            record_tlast         <= 1'b0;
            packet_record_index  <= 16'd0;
            packet_complete <= 1'b0;
            cic_interval_count   <= 16'd0;
            psd_input_interval_count <= 16'd0;
            m_axis_tvalid        <= 1'b0;
            emitted_record_pulse <= 1'b0;
            dropped_record_pulse <= 1'b0;
            records_emitted      <= 32'd0;
            records_dropped      <= 32'd0;

            cap_cycle_count      <= 32'd0;
            cap_flags            <= 16'd0;
            cap_frame_id         <= 32'd0;
            cap_decision_frame_id <= 32'd0;

            cap_frame_bin_count  <= {COUNT_WIDTH{1'b0}};
            cap_active_bin_count <= {COUNT_WIDTH{1'b0}};
            cap_overflow_count   <= {COUNT_WIDTH{1'b0}};
            cap_bw_span_bins     <= {COUNT_WIDTH{1'b0}};
            cap_bw_edge_bins     <= {COUNT_WIDTH{1'b0}};
            cap_low_bin          <= {BIN_WIDTH{1'b0}};
            cap_high_bin         <= {BIN_WIDTH{1'b0}};
            cap_peak_bin         <= {BIN_WIDTH{1'b0}};
            cap_low_signed_bin   <= {SIGNED_BIN_WIDTH{1'b0}};
            cap_high_signed_bin  <= {SIGNED_BIN_WIDTH{1'b0}};
            cap_peak_signed_bin  <= {SIGNED_BIN_WIDTH{1'b0}};
            cap_peak_power       <= {POWER_WIDTH{1'b0}};
            cap_min_power        <= {POWER_WIDTH{1'b0}};
            cap_total_power      <= {SUM_WIDTH{1'b0}};
            cap_active_power     <= {SUM_WIDTH{1'b0}};

            cap_decimation_factor_m <= {M_WIDTH{1'b0}};
            cap_candidate_factor_m  <= {M_WIDTH{1'b0}};
            cap_decision_edge_bins  <= {COUNT_WIDTH{1'b0}};
            cap_stable_count        <= 16'd0;

            cap_m_i <= 16'sd0;
            cap_m_q <= 16'sd0;
            cap_psd_input_i <= 16'sd0;
            cap_psd_input_q <= 16'sd0;
            cap_active_decimation_factor <= {M_WIDTH{1'b0}};
            cap_active_gain_shift <= {SHIFT_WIDTH{1'b0}};
        end else if (capture_flush) begin
            // Flush discards pending output, not elapsed processing-clock time.
            cycle_counter <= cycle_counter + 1'b1;
            packet_record_index <= 0;
            packet_complete <= 0;
            m_axis_tvalid <= 0;
            active_record_type <= RECORD_NONE;
            word_index <= 0;
            emitted_record_pulse <= 0;
            dropped_record_pulse <= 0;
        end else begin
            if (!capture_enable) packet_complete <= 0;
            cycle_counter        <= cycle_counter + 1'b1;
            emitted_record_pulse <= 1'b0;
            dropped_record_pulse <= 1'b0;

            if (!capture_cic_enable) begin
                cic_interval_count <= 16'd0;
            end else if (m_valid) begin
                if (cic_interval_count == 16'd0) begin
                    cic_interval_count <= (cic_sample_interval <= 16'd1) ?
                                          16'd0 :
                                          (cic_sample_interval - 16'd1);
                end else begin
                    cic_interval_count <= cic_interval_count - 1'b1;
                end
            end

            if (!capture_psd_input_enable) begin
                psd_input_interval_count <= 16'd0;
            end else if (psd_input_valid) begin
                if (psd_input_interval_count == 16'd0) begin
                    psd_input_interval_count <= (psd_input_sample_interval <= 16'd1) ?
                                                16'd0 :
                                                (psd_input_sample_interval - 16'd1);
                end else begin
                    psd_input_interval_count <= psd_input_interval_count - 1'b1;
                end
            end

            if (m_axis_tvalid && m_axis_tready) begin
                if (word_index == (active_record_words[3:0] - 4'd1)) begin
                    m_axis_tvalid        <= 1'b0;
                    active_record_type   <= RECORD_NONE;
                    word_index           <= 4'd0;
                    emitted_record_pulse <= 1'b1;
                    records_emitted      <= records_emitted + 1'b1;

                    if (packet_record_count != 16'd0) begin
                        if (record_tlast) begin
                            packet_record_index <= 16'd0;
                            packet_complete <= 1'b1;
                        end else begin
                            packet_record_index <= packet_record_index + 1'b1;
                        end
                    end
                end else begin
                    word_index <= word_index + 1'b1;
                end
            end else if (!m_axis_tvalid) begin
                if (summary_request) begin
                    active_record_type  <= RECORD_SUMMARY;
                    word_index          <= 4'd0;
                    record_tlast        <= packet_end_for_next_record;
                    m_axis_tvalid       <= 1'b1;

                    cap_cycle_count      <= cycle_counter;
                    cap_flags            <= live_flags;
                    cap_frame_id         <= frame_id;
                    cap_decision_frame_id <= decision_frame_id;

                    cap_frame_bin_count  <= frame_bin_count;
                    cap_active_bin_count <= active_bin_count;
                    cap_overflow_count   <= overflow_count;
                    cap_bw_span_bins     <= bw_span_bins;
                    cap_bw_edge_bins     <= bw_edge_bins;
                    cap_low_bin          <= low_bin;
                    cap_high_bin         <= high_bin;
                    cap_peak_bin         <= peak_bin;
                    cap_low_signed_bin   <= low_signed_bin;
                    cap_high_signed_bin  <= high_signed_bin;
                    cap_peak_signed_bin  <= peak_signed_bin;
                    cap_peak_power       <= peak_power;
                    cap_min_power        <= min_power;
                    cap_total_power      <= total_power;
                    cap_active_power     <= active_power;

                    cap_decimation_factor_m <= decimation_factor_m;
                    cap_candidate_factor_m  <= candidate_factor_m;
                    cap_decision_edge_bins  <= decision_edge_bins;
                    cap_stable_count        <= stable_count;

                    cap_m_i <= m_i;
                    cap_m_q <= m_q;
                    cap_psd_input_i <= psd_input_i;
                    cap_psd_input_q <= psd_input_q;
                    cap_active_decimation_factor <= active_decimation_factor;
                    cap_active_gain_shift <= active_gain_shift;
                end else if (cic_sample_take) begin
                    active_record_type  <= RECORD_CIC_SAMPLE;
                    word_index          <= 4'd0;
                    record_tlast        <= packet_end_for_next_record;
                    m_axis_tvalid       <= 1'b1;

                    cap_cycle_count      <= cycle_counter;
                    cap_flags            <= live_flags;
                    cap_frame_id         <= frame_id;
                    cap_decision_frame_id <= decision_frame_id;
                    cap_decimation_factor_m <= decimation_factor_m;
                    cap_candidate_factor_m  <= candidate_factor_m;
                    cap_stable_count        <= stable_count;
                    cap_m_i <= m_i;
                    cap_m_q <= m_q;
                    cap_psd_input_i <= psd_input_i;
                    cap_psd_input_q <= psd_input_q;
                    cap_active_decimation_factor <= active_decimation_factor;
                    cap_active_gain_shift <= active_gain_shift;
                end else if (psd_input_sample_take) begin
                    active_record_type  <= RECORD_PSD_INPUT;
                    word_index          <= 4'd0;
                    record_tlast        <= packet_end_for_next_record;
                    m_axis_tvalid       <= 1'b1;

                    cap_cycle_count      <= cycle_counter;
                    cap_flags            <= live_flags;
                    cap_frame_id         <= frame_id;
                    cap_decision_frame_id <= decision_frame_id;
                    cap_decimation_factor_m <= decimation_factor_m;
                    cap_candidate_factor_m  <= candidate_factor_m;
                    cap_stable_count        <= stable_count;
                    cap_m_i <= m_i;
                    cap_m_q <= m_q;
                    cap_psd_input_i <= psd_input_i;
                    cap_psd_input_q <= psd_input_q;
                    cap_active_decimation_factor <= active_decimation_factor;
                    cap_active_gain_shift <= active_gain_shift;
                end
            end else if (summary_request || cic_sample_take || psd_input_sample_take) begin
                dropped_record_pulse <= 1'b1;
                records_dropped      <= records_dropped + 1'b1;
            end
        end
    end

endmodule
