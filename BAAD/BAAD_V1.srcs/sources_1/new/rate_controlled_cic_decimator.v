`timescale 1ns / 1ps

module rate_controlled_cic_decimator #(
    parameter integer IN_WIDTH         = 16,
    parameter integer OUT_WIDTH        = 16,
    parameter integer ACC_WIDTH        = 32,
    parameter integer STAGES           = 3,
    parameter integer DIFF_DELAY       = 1,
    parameter integer RATE_WIDTH       = 16,
    parameter integer SHIFT_WIDTH      = 8,
    parameter integer MAX_DECIMATION   = 16,
    parameter integer REQUIRE_POWER_OF_TWO_RATE = 1,
    parameter integer SETTLING_OUTPUTS = STAGES * DIFF_DELAY
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire signed [IN_WIDTH-1:0]    s_i,
    input  wire signed [IN_WIDTH-1:0]    s_q,
    input  wire                          s_valid,

    input  wire [RATE_WIDTH-1:0]         cfg_decimation_factor,
    input  wire                          cfg_valid,

    output reg  signed [OUT_WIDTH-1:0]   m_i,
    output reg  signed [OUT_WIDTH-1:0]   m_q,
    output reg                           m_valid,

    output reg  [RATE_WIDTH-1:0]         active_decimation_factor,
    output reg  [SHIFT_WIDTH-1:0]        active_gain_shift,
    output reg                           rate_changed,
    output reg                           settling,
    output reg                           cfg_error,
    output reg                           overflow,
    output reg                           pending_rate_change,
    output reg                           settling_started,
    output reg                           switch_boundary_clean,
    output reg                           switch_boundary_error,
    output reg                           invalid_active_rate
);

    localparam integer COMB_DELAY_WORDS = STAGES * DIFF_DELAY;
    localparam [RATE_WIDTH-1:0] RATE_ZERO = {RATE_WIDTH{1'b0}};
    localparam [RATE_WIDTH-1:0] RATE_ONE  = {{(RATE_WIDTH-1){1'b0}}, 1'b1};
    localparam [RATE_WIDTH-1:0] MAX_DECIMATION_VALUE = MAX_DECIMATION;
    localparam [SHIFT_WIDTH-1:0] ACC_WIDTH_VALUE = ACC_WIDTH;
    localparam [SHIFT_WIDTH-1:0] STAGES_VALUE = STAGES;
    localparam [15:0] SETTLING_OUTPUT_COUNT = SETTLING_OUTPUTS;
    localparam signed [ACC_WIDTH-1:0] OUT_MAX_EXT =
        {{(ACC_WIDTH-OUT_WIDTH){1'b0}}, 1'b0, {(OUT_WIDTH-1){1'b1}}};
    localparam signed [ACC_WIDTH-1:0] OUT_MIN_EXT =
        {{(ACC_WIDTH-OUT_WIDTH){1'b1}}, 1'b1, {(OUT_WIDTH-1){1'b0}}};

    reg signed [ACC_WIDTH-1:0] integrator_i [0:STAGES-1];
    reg signed [ACC_WIDTH-1:0] integrator_q [0:STAGES-1];
    reg signed [ACC_WIDTH-1:0] comb_delay_i [0:COMB_DELAY_WORDS-1];
    reg signed [ACC_WIDTH-1:0] comb_delay_q [0:COMB_DELAY_WORDS-1];

    reg [RATE_WIDTH-1:0] pending_decimation_factor;
    reg [SHIFT_WIDTH-1:0] pending_gain_shift;
    reg pending_update;

    reg [RATE_WIDTH-1:0] decim_count;
    reg [15:0] settling_count;

    reg signed [ACC_WIDTH-1:0] input_ext_i;
    reg signed [ACC_WIDTH-1:0] input_ext_q;
    reg signed [ACC_WIDTH-1:0] int_work_i;
    reg signed [ACC_WIDTH-1:0] int_work_q;
    reg signed [ACC_WIDTH-1:0] comb_work_i;
    reg signed [ACC_WIDTH-1:0] comb_work_q;
    reg signed [ACC_WIDTH-1:0] comb_diff_i;
    reg signed [ACC_WIDTH-1:0] comb_diff_q;
    reg signed [ACC_WIDTH-1:0] shifted_i;
    reg signed [ACC_WIDTH-1:0] shifted_q;

    integer stage_idx;
    integer delay_idx;
    integer flat_idx;

    function is_power_of_two;
        input [RATE_WIDTH-1:0] value;
        begin
            is_power_of_two = (value != RATE_ZERO) &&
                              ((value & (value - 1'b1)) == RATE_ZERO);
        end
    endfunction

    function cfg_rate_is_valid;
        input [RATE_WIDTH-1:0] value;
        begin
            cfg_rate_is_valid = (value >= RATE_ONE) &&
                                (value <= MAX_DECIMATION_VALUE) &&
                                (!REQUIRE_POWER_OF_TWO_RATE || is_power_of_two(value));
        end
    endfunction

    function [SHIFT_WIDTH-1:0] power_of_two_gain_shift;
        input [RATE_WIDTH-1:0] value;
        integer bit_idx;
        reg [SHIFT_WIDTH-1:0] log2_value;
        begin
            log2_value = {SHIFT_WIDTH{1'b0}};

            for (bit_idx = 0; bit_idx < RATE_WIDTH; bit_idx = bit_idx + 1) begin
                if (value[bit_idx]) begin
                    log2_value = bit_idx;
                end
            end

            power_of_two_gain_shift = log2_value * STAGES_VALUE;
        end
    endfunction

    function signed [ACC_WIDTH-1:0] rounded_arith_shift;
        input signed [ACC_WIDTH-1:0] value;
        input [SHIFT_WIDTH-1:0] shift;
        reg signed [ACC_WIDTH-1:0] offset;
        begin
            if (shift == {SHIFT_WIDTH{1'b0}}) begin
                rounded_arith_shift = value;
            end else if (shift >= ACC_WIDTH_VALUE) begin
                rounded_arith_shift = value[ACC_WIDTH-1] ?
                                      {ACC_WIDTH{1'b1}} :
                                      {ACC_WIDTH{1'b0}};
            end else begin
                offset = {{(ACC_WIDTH-1){1'b0}}, 1'b1} <<< (shift - 1'b1);
                rounded_arith_shift = (value + offset) >>> shift;
            end
        end
    endfunction

    function signed [OUT_WIDTH-1:0] saturate_to_output;
        input signed [ACC_WIDTH-1:0] value;
        begin
            if (value > OUT_MAX_EXT) begin
                saturate_to_output = {1'b0, {(OUT_WIDTH-1){1'b1}}};
            end else if (value < OUT_MIN_EXT) begin
                saturate_to_output = {1'b1, {(OUT_WIDTH-1){1'b0}}};
            end else begin
                saturate_to_output = value[OUT_WIDTH-1:0];
            end
        end
    endfunction

    function output_saturates;
        input signed [ACC_WIDTH-1:0] value;
        begin
            output_saturates = (value > OUT_MAX_EXT) || (value < OUT_MIN_EXT);
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_i                       <= {OUT_WIDTH{1'b0}};
            m_q                       <= {OUT_WIDTH{1'b0}};
            m_valid                   <= 1'b0;
            active_decimation_factor  <= RATE_ONE;
            active_gain_shift         <= {SHIFT_WIDTH{1'b0}};
            rate_changed              <= 1'b0;
            settling                  <= 1'b0;
            cfg_error                 <= 1'b0;
            overflow                  <= 1'b0;
            pending_rate_change       <= 1'b0;
            settling_started          <= 1'b0;
            switch_boundary_clean     <= 1'b0;
            switch_boundary_error     <= 1'b0;
            invalid_active_rate       <= 1'b0;
            pending_decimation_factor <= RATE_ONE;
            pending_gain_shift        <= {SHIFT_WIDTH{1'b0}};
            pending_update            <= 1'b0;
            decim_count               <= RATE_ZERO;
            settling_count            <= 16'd0;

            for (stage_idx = 0; stage_idx < STAGES; stage_idx = stage_idx + 1) begin
                integrator_i[stage_idx] <= {ACC_WIDTH{1'b0}};
                integrator_q[stage_idx] <= {ACC_WIDTH{1'b0}};
            end

            for (flat_idx = 0; flat_idx < COMB_DELAY_WORDS; flat_idx = flat_idx + 1) begin
                comb_delay_i[flat_idx] <= {ACC_WIDTH{1'b0}};
                comb_delay_q[flat_idx] <= {ACC_WIDTH{1'b0}};
            end
        end else begin
            m_valid      <= 1'b0;
            rate_changed <= 1'b0;
            cfg_error    <= 1'b0;
            overflow     <= 1'b0;
            settling     <= (settling_count != 16'd0);
            pending_rate_change   <= pending_update;
            settling_started      <= 1'b0;
            switch_boundary_clean <= 1'b0;
            switch_boundary_error <= 1'b0;
            invalid_active_rate   <= !cfg_rate_is_valid(active_decimation_factor);

            if (!cfg_rate_is_valid(active_decimation_factor)) begin
                active_decimation_factor <= RATE_ONE;
                active_gain_shift        <= {SHIFT_WIDTH{1'b0}};
                pending_decimation_factor <= RATE_ONE;
                pending_gain_shift        <= {SHIFT_WIDTH{1'b0}};
                pending_update            <= 1'b0;
                pending_rate_change       <= 1'b0;
                decim_count               <= RATE_ZERO;
                settling_count            <= 16'd0;
                rate_changed              <= 1'b1;
                cfg_error                 <= 1'b1;
                invalid_active_rate       <= 1'b1;

                for (flat_idx = 0; flat_idx < COMB_DELAY_WORDS; flat_idx = flat_idx + 1) begin
                    comb_delay_i[flat_idx] <= {ACC_WIDTH{1'b0}};
                    comb_delay_q[flat_idx] <= {ACC_WIDTH{1'b0}};
                end

                for (stage_idx = 0; stage_idx < STAGES; stage_idx = stage_idx + 1) begin
                    integrator_i[stage_idx] <= {ACC_WIDTH{1'b0}};
                    integrator_q[stage_idx] <= {ACC_WIDTH{1'b0}};
                end
            end else begin
                if (cfg_valid) begin
                    if (cfg_rate_is_valid(cfg_decimation_factor)) begin
                        pending_decimation_factor <= cfg_decimation_factor;
                        pending_gain_shift <= power_of_two_gain_shift(cfg_decimation_factor);
                        pending_update <= 1'b1;
                        pending_rate_change <= 1'b1;
                    end else begin
                        cfg_error <= 1'b1;
                        pending_decimation_factor <= RATE_ONE;
                        pending_gain_shift <= 0;
                        pending_update <= 1'b1;
                        pending_rate_change <= 1'b1;
                    end
                end

                if (s_valid) begin
                    input_ext_i = {{(ACC_WIDTH-IN_WIDTH){s_i[IN_WIDTH-1]}}, s_i};
                    input_ext_q = {{(ACC_WIDTH-IN_WIDTH){s_q[IN_WIDTH-1]}}, s_q};

                    int_work_i = input_ext_i;
                    int_work_q = input_ext_q;

                    for (stage_idx = 0; stage_idx < STAGES; stage_idx = stage_idx + 1) begin
                        int_work_i = integrator_i[stage_idx] + int_work_i;
                        int_work_q = integrator_q[stage_idx] + int_work_q;
                        integrator_i[stage_idx] <= int_work_i;
                        integrator_q[stage_idx] <= int_work_q;
                    end

                    // A command arriving at the boundary replaces the pending
                    // command; never clear that newly queued command here.
                    if (pending_update && (decim_count == RATE_ZERO) && !cfg_valid) begin
                        if (!cfg_rate_is_valid(pending_decimation_factor)) begin
                            active_decimation_factor <= RATE_ONE;
                            active_gain_shift <= {SHIFT_WIDTH{1'b0}};
                            cfg_error <= 1'b1;
                            invalid_active_rate <= 1'b1;
                        end else begin
                            active_decimation_factor <= pending_decimation_factor;
                            active_gain_shift <= pending_gain_shift;
                        end

                        pending_update <= 1'b0;
                        pending_rate_change <= 1'b0;
                        rate_changed <= 1'b1;
                        switch_boundary_clean <= 1'b1;
                        switch_boundary_error <= (decim_count != RATE_ZERO);

                        for (flat_idx = 0; flat_idx < COMB_DELAY_WORDS; flat_idx = flat_idx + 1) begin
                            comb_delay_i[flat_idx] <= {ACC_WIDTH{1'b0}};
                            comb_delay_q[flat_idx] <= {ACC_WIDTH{1'b0}};
                        end

                        for (stage_idx = 0; stage_idx < STAGES; stage_idx = stage_idx + 1) begin
                            integrator_i[stage_idx] <= {ACC_WIDTH{1'b0}};
                            integrator_q[stage_idx] <= {ACC_WIDTH{1'b0}};
                        end

                        if (!cfg_rate_is_valid(pending_decimation_factor) ||
                            (pending_decimation_factor <= RATE_ONE)) begin
                            decim_count <= RATE_ZERO;
                            settling_count <= 16'd0;
                        end else begin
                            decim_count <= RATE_ONE;
                            settling_count <= SETTLING_OUTPUT_COUNT;
                            settling_started <= (SETTLING_OUTPUT_COUNT != 16'd0);
                        end
                    end else begin
                        if (decim_count == RATE_ZERO) begin
                            if (active_decimation_factor <= RATE_ONE) begin
                                shifted_i = input_ext_i;
                                shifted_q = input_ext_q;
                                m_i <= saturate_to_output(shifted_i);
                                m_q <= saturate_to_output(shifted_q);
                                m_valid <= 1'b1;
                                overflow <= output_saturates(shifted_i) ||
                                            output_saturates(shifted_q);
                            end else begin
                                comb_work_i = int_work_i;
                                comb_work_q = int_work_q;

                                for (stage_idx = 0; stage_idx < STAGES; stage_idx = stage_idx + 1) begin
                                    flat_idx = stage_idx * DIFF_DELAY + DIFF_DELAY - 1;
                                    comb_diff_i = comb_work_i - comb_delay_i[flat_idx];
                                    comb_diff_q = comb_work_q - comb_delay_q[flat_idx];

                                    for (delay_idx = DIFF_DELAY - 1; delay_idx > 0; delay_idx = delay_idx - 1) begin
                                        comb_delay_i[stage_idx * DIFF_DELAY + delay_idx] <=
                                            comb_delay_i[stage_idx * DIFF_DELAY + delay_idx - 1];
                                        comb_delay_q[stage_idx * DIFF_DELAY + delay_idx] <=
                                            comb_delay_q[stage_idx * DIFF_DELAY + delay_idx - 1];
                                    end

                                    comb_delay_i[stage_idx * DIFF_DELAY] <= comb_work_i;
                                    comb_delay_q[stage_idx * DIFF_DELAY] <= comb_work_q;
                                    comb_work_i = comb_diff_i;
                                    comb_work_q = comb_diff_q;
                                end

                                if (settling_count != 16'd0) begin
                                    settling_count <= settling_count - 1'b1;
                                end else begin
                                    shifted_i = rounded_arith_shift(comb_work_i, active_gain_shift);
                                    shifted_q = rounded_arith_shift(comb_work_q, active_gain_shift);
                                    m_i <= saturate_to_output(shifted_i);
                                    m_q <= saturate_to_output(shifted_q);
                                    m_valid <= 1'b1;
                                    overflow <= output_saturates(shifted_i) ||
                                                output_saturates(shifted_q);
                                end
                            end
                        end

                        if (active_decimation_factor <= RATE_ONE) begin
                            decim_count <= RATE_ZERO;
                        end else if (decim_count == (active_decimation_factor - 1'b1)) begin
                            decim_count <= RATE_ZERO;
                        end else begin
                            decim_count <= decim_count + 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
