`timescale 1ns / 1ps

module decimation_decision_control #(
    parameter integer NFFT               = 2048,
    parameter integer BIN_WIDTH          = 11,
    parameter integer M_WIDTH            = 16,
    parameter integer GUARD_NUM          = 4,
    parameter integer GUARD_DEN          = 5,
    parameter integer STABLE_FRAME_COUNT = 2,
    parameter integer HYSTERESIS_BINS    = 10,
    parameter integer SAFE_M             = 1,
    parameter integer NO_ACTIVE_M        = 1,
    parameter integer MAX_DECIMATION     = 16,
    parameter integer ESTIMATE_TIMEOUT_CYCLES = 8 * NFFT
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     estimate_valid,
    input  wire [31:0]              frame_id,
    input  wire                     active_found,
    input  wire                     frame_error,
    input  wire                     overflow_seen,
    input  wire [BIN_WIDTH:0]       bw_edge_bins,
    input  wire [BIN_WIDTH:0]       bw_span_bins,

    output reg                      decision_valid,
    output reg  [31:0]              decision_frame_id,
    output reg  [M_WIDTH-1:0]       decimation_factor_m,
    output reg  [M_WIDTH-1:0]       candidate_factor_m,
    output reg                      m_changed,
    output reg                      decision_error,
    output reg                      no_active,
    output reg  [BIN_WIDTH:0]       decision_edge_bins,
    output reg  [15:0]              stable_count,
    output reg                      invalid_m,
    output reg                      safety_fallback
);

    localparam integer STABLE_REQUIRED =
        (STABLE_FRAME_COUNT < 1) ? 1 : STABLE_FRAME_COUNT;
    localparam [M_WIDTH-1:0] SAFE_M_VALUE = {{(M_WIDTH-1){1'b0}}, 1'b1};
    localparam [M_WIDTH-1:0] MAX_DECIMATION_VALUE = MAX_DECIMATION;

    reg [M_WIDTH-1:0] pending_factor_m;
    reg [31:0] estimate_age;

    wire [M_WIDTH-1:0] selected_factor_raw;
    wire [M_WIDTH-1:0] selected_factor_m;
    wire               selected_factor_invalid;
    wire               current_factor_invalid;
    wire               pending_factor_invalid;
    wire               force_safe_m;

    assign current_factor_invalid = !factor_is_valid(decimation_factor_m);
    assign pending_factor_invalid = !factor_is_valid(pending_factor_m);
    assign force_safe_m = frame_error ||
                          overflow_seen ||
                          !active_found ||
                          current_factor_invalid ||
                          pending_factor_invalid;
    assign selected_factor_raw =
        force_safe_m ? SAFE_M_VALUE :
                       choose_factor_hysteretic(bw_edge_bins,
                                                decimation_factor_m);
    assign selected_factor_invalid = !factor_is_valid(selected_factor_raw);
    assign selected_factor_m =
        selected_factor_invalid ? SAFE_M_VALUE : selected_factor_raw;

    function factor_fits;
        input [BIN_WIDTH:0] edge_bins;
        input [M_WIDTH-1:0] factor_m;
        reg [63:0] lhs;
        reg [63:0] rhs;
        reg [63:0] factor_ext;
        begin
            factor_ext = factor_m;
            lhs = edge_bins;
            lhs = lhs * 2 * factor_ext * GUARD_DEN;

            rhs = NFFT;
            rhs = rhs * GUARD_NUM;

            factor_fits = (lhs <= rhs);
        end
    endfunction

    function factor_fits_upper_margin;
        input [BIN_WIDTH:0] edge_bins;
        input [M_WIDTH-1:0] factor_m;
        reg [63:0] lhs;
        reg [63:0] rhs;
        reg [63:0] margin;
        reg [63:0] factor_ext;
        begin
            factor_ext = factor_m;
            lhs = edge_bins;
            lhs = lhs * 2 * factor_ext * GUARD_DEN;

            rhs = NFFT;
            rhs = rhs * GUARD_NUM;

            margin = HYSTERESIS_BINS;
            margin = margin * 2 * factor_ext * GUARD_DEN;

            factor_fits_upper_margin = (lhs <= (rhs + margin));
        end
    endfunction

    function factor_fits_lower_margin;
        input [BIN_WIDTH:0] edge_bins;
        input [M_WIDTH-1:0] factor_m;
        reg [63:0] lhs;
        reg [63:0] rhs;
        reg [63:0] factor_ext;
        begin
            factor_ext = factor_m;
            lhs = edge_bins + HYSTERESIS_BINS;
            lhs = lhs * 2 * factor_ext * GUARD_DEN;

            rhs = NFFT;
            rhs = rhs * GUARD_NUM;

            factor_fits_lower_margin = (lhs <= rhs);
        end
    endfunction

    function factor_is_valid;
        input [M_WIDTH-1:0] factor_m;
        begin
            factor_is_valid = (factor_m >= SAFE_M_VALUE) &&
                              (factor_m <= MAX_DECIMATION_VALUE) &&
                              (factor_m != {M_WIDTH{1'b0}}) &&
                              ((factor_m & (factor_m - 1'b1)) == {M_WIDTH{1'b0}});
        end
    endfunction

    function [M_WIDTH-1:0] choose_factor;
        input [BIN_WIDTH:0] edge_bins;
        reg [M_WIDTH-1:0] trial_factor_m;
        reg found_factor;
        integer bit_idx;
        begin
            choose_factor = SAFE_M_VALUE;
            found_factor = 1'b0;

            for (bit_idx = M_WIDTH - 1; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                trial_factor_m = {{(M_WIDTH-1){1'b0}}, 1'b1} << bit_idx;

                if (!found_factor &&
                    (trial_factor_m <= MAX_DECIMATION_VALUE) &&
                    (trial_factor_m >= SAFE_M_VALUE) &&
                    factor_fits(edge_bins, trial_factor_m)) begin
                    choose_factor = trial_factor_m;
                    found_factor = 1'b1;
                end
            end
        end
    endfunction

    function [M_WIDTH-1:0] choose_factor_lower_margin;
        input [BIN_WIDTH:0] edge_bins;
        reg [M_WIDTH-1:0] trial_factor_m;
        reg found_factor;
        integer bit_idx;
        begin
            choose_factor_lower_margin = SAFE_M_VALUE;
            found_factor = 1'b0;

            for (bit_idx = M_WIDTH - 1; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                trial_factor_m = {{(M_WIDTH-1){1'b0}}, 1'b1} << bit_idx;

                if (!found_factor &&
                    (trial_factor_m <= MAX_DECIMATION_VALUE) &&
                    (trial_factor_m >= SAFE_M_VALUE) &&
                    factor_fits_lower_margin(edge_bins, trial_factor_m)) begin
                    choose_factor_lower_margin = trial_factor_m;
                    found_factor = 1'b1;
                end
            end
        end
    endfunction

    function [M_WIDTH-1:0] choose_factor_hysteretic;
        input [BIN_WIDTH:0] edge_bins;
        input [M_WIDTH-1:0] current_factor_m;
        reg [M_WIDTH-1:0] nominal_factor_m;
        reg [M_WIDTH-1:0] aggressive_factor_m;
        begin
            nominal_factor_m = choose_factor(edge_bins);
            aggressive_factor_m = choose_factor_lower_margin(edge_bins);

            if (!factor_is_valid(current_factor_m)) begin
                choose_factor_hysteretic = nominal_factor_m;
            end else if (!factor_fits(edge_bins, current_factor_m)) begin
                choose_factor_hysteretic = nominal_factor_m;
            end else if (aggressive_factor_m > current_factor_m) begin
                choose_factor_hysteretic = aggressive_factor_m;
            end else begin
                choose_factor_hysteretic = current_factor_m;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decision_valid      <= 1'b0;
            decision_frame_id   <= 32'd0;
            decimation_factor_m <= SAFE_M_VALUE;
            candidate_factor_m  <= SAFE_M_VALUE;
            pending_factor_m    <= SAFE_M_VALUE;
            m_changed           <= 1'b0;
            decision_error      <= 1'b0;
            no_active           <= 1'b0;
            decision_edge_bins  <= {1'b0, {BIN_WIDTH{1'b0}}};
            stable_count        <= 16'd0;
            invalid_m           <= 1'b0;
            safety_fallback     <= 1'b0;
            estimate_age        <= 32'd0;
        end else begin
            decision_valid  <= 1'b0;
            m_changed       <= 1'b0;
            invalid_m       <= 1'b0;
            safety_fallback <= 1'b0;
            if (estimate_valid) begin
                estimate_age <= 32'd0;
            end else if (estimate_age < ESTIMATE_TIMEOUT_CYCLES) begin
                estimate_age <= estimate_age + 1'b1;
            end

            // A stopped/malformed estimator must not leave a stale high rate.
            // Emit one explicit error decision per outage, rearmed by an estimate.
            if (!estimate_valid && estimate_age == ESTIMATE_TIMEOUT_CYCLES - 1) begin
                decision_valid <= 1'b1;
                decision_error <= 1'b1;
                safety_fallback <= 1'b1;
                candidate_factor_m <= SAFE_M_VALUE;
                decimation_factor_m <= SAFE_M_VALUE;
                pending_factor_m <= SAFE_M_VALUE;
                stable_count <= 16'd0;
                m_changed <= (decimation_factor_m != SAFE_M_VALUE);
            end else if (estimate_valid) begin
                decision_valid     <= 1'b1;
                decision_frame_id  <= frame_id;
                candidate_factor_m <= selected_factor_m;
                decision_error     <= frame_error |
                                      overflow_seen |
                                      selected_factor_invalid |
                                      current_factor_invalid |
                                      pending_factor_invalid;
                no_active          <= ~active_found;
                decision_edge_bins <= bw_edge_bins;
                invalid_m          <= selected_factor_invalid |
                                      current_factor_invalid |
                                      pending_factor_invalid;
                safety_fallback    <= force_safe_m |
                                      selected_factor_invalid;

                if (force_safe_m || selected_factor_invalid) begin
                    pending_factor_m <= selected_factor_m;
                    stable_count     <= STABLE_REQUIRED;

                    if (selected_factor_m != decimation_factor_m) begin
                        decimation_factor_m <= selected_factor_m;
                        m_changed           <= 1'b1;
                    end
                end else if (selected_factor_m < decimation_factor_m) begin
                    pending_factor_m <= selected_factor_m;
                    stable_count     <= STABLE_REQUIRED;

                    decimation_factor_m <= selected_factor_m;
                    m_changed           <= 1'b1;
                end else if (selected_factor_m == pending_factor_m) begin
                    if (stable_count < STABLE_REQUIRED) begin
                        stable_count <= stable_count + 1'b1;
                    end

                    if ((selected_factor_m != decimation_factor_m) &&
                        ((stable_count + 1'b1) >= STABLE_REQUIRED)) begin
                        decimation_factor_m <= selected_factor_m;
                        m_changed           <= 1'b1;
                    end
                end else begin
                    pending_factor_m <= selected_factor_m;
                    stable_count     <= 16'd1;

                    if ((STABLE_REQUIRED <= 1) &&
                        (selected_factor_m != decimation_factor_m)) begin
                        decimation_factor_m <= selected_factor_m;
                        m_changed           <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
