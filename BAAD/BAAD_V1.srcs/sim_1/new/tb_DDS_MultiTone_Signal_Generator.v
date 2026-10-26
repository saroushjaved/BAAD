`timescale 1ns / 1ps

module tb_DDS_MultiTone_Signal_Generator();

    localparam integer NFFT = 2048;
    localparam integer ESTIMATE_FRAME_LIMIT = 4;
    localparam integer MAX_SIM_CYCLES = 90000;
    localparam integer GUARD_NUM = 4;
    localparam integer GUARD_DEN = 5;
    localparam integer SAFE_M = 1;
    localparam integer MAX_DECIMATION = 16;
    localparam [15:0] SAFE_M_VALUE = SAFE_M;
    localparam [15:0] MAX_DECIMATION_VALUE = MAX_DECIMATION;
    localparam real SAMPLE_RATE_HZ = 62000000.0;
    localparam real CLK_PERIOD_NS = 1.0e9 / SAMPLE_RATE_HZ;

    reg clock;

    wire [15:0] dout;
    wire [15:0] I_out;

    wire [11:0] active_bin_count_0;
    wire [15:0] active_decimation_factor_0;
    wire        active_found_0;
    wire [7:0]  active_gain_shift_0;
    wire [44:0] active_power_0;
    wire [11:0] bw_edge_bins_0;
    wire [11:0] bw_span_bins_0;
    wire [15:0] candidate_factor_m_0;
    wire        cfg_error_0;
    wire [15:0] decimation_factor_m_0;
    wire [11:0] decision_edge_bins_0;
    wire        decision_error_0;
    wire [31:0] decision_frame_id_0;
    wire        decision_valid_0;
    wire        estimate_valid;
    wire [11:0] frame_bin_count_0;
    wire        frame_error_0;
    wire [31:0] frame_id_0;
    wire [10:0] high_bin_0;
    wire [12:0] high_signed_bin_0;
    wire [10:0] low_bin_0;
    wire [12:0] low_signed_bin_0;
    wire        m_changed_0;
    wire [15:0] m_i_0;
    wire [15:0] m_q_0;
    wire        m_valid_0;
    wire [32:0] min_power_0;
    wire        no_active_0;
    wire        overflow_0;
    wire [11:0] overflow_count_0;
    wire        overflow_seen_0;
    wire [10:0] peak_bin_0;
    wire [32:0] peak_power_0;
    wire [12:0] peak_signed_bin_0;
    wire        rate_changed_0;
    wire        settling_0;
    wire        signal_generator_valid_out;
    wire [15:0] stable_count_0;
    wire [44:0] total_power_0;

    // The new wrapper exposes estimator-frame results, not the PSD stream.
    // These BD-internal wires are logged so the estimator input can still be checked.
    wire [15:0] q_out_internal;
    wire [10:0] psd_bin_internal;
    wire        psd_last_internal;
    wire        psd_overflow_internal;
    wire [32:0] psd_power_internal;
    wire        psd_valid_internal;
    wire        cic_input_valid_internal;
    wire        rst_n_internal;
    wire [32:0] cfg_power_threshold_internal;

    integer trace_file;
    integer psd_file;
    integer bw_file;
    integer decision_file;
    integer cic_input_file;
    integer cic_output_file;
    integer summary_file;

    integer cycle_count;
    integer psd_valid_count;
    integer psd_frame_count;
    integer psd_last_count;
    integer psd_overflow_count;
    integer psd_bins_in_frame;
    integer bin_order_warning_count;
    integer last_timing_warning_count;

    integer estimate_count;
    integer estimate_frame_error_count;
    integer estimate_overflow_seen_count;
    integer estimate_active_missing_count;
    integer estimate_frame_bin_warning_count;
    integer estimate_frame_id_warning_count;

    integer decision_count;
    integer decision_error_count;
    integer decision_no_active_count;
    integer decision_m_changed_count;
    integer decision_frame_id_warning_count;
    integer decision_candidate_warning_count;

    integer cic_input_sample_count;
    integer cic_output_sample_count;
    integer cic_rate_changed_count;
    integer cic_cfg_error_count;
    integer cic_overflow_count;
    integer cic_settling_cycle_count;

    integer done;
    real bin_hz;

    BAAD_BD_wrapper DUT (
        .clock(clock),
        .I_out(I_out),
        .active_bin_count_0(active_bin_count_0),
        .active_decimation_factor_0(active_decimation_factor_0),
        .active_found_0(active_found_0),
        .active_gain_shift_0(active_gain_shift_0),
        .active_power_0(active_power_0),
        .bw_edge_bins_0(bw_edge_bins_0),
        .bw_span_bins_0(bw_span_bins_0),
        .candidate_factor_m_0(candidate_factor_m_0),
        .cfg_error_0(cfg_error_0),
        .decimation_factor_m_0(decimation_factor_m_0),
        .decision_edge_bins_0(decision_edge_bins_0),
        .decision_error_0(decision_error_0),
        .decision_frame_id_0(decision_frame_id_0),
        .decision_valid_0(decision_valid_0),
        .dout(dout),
        .frame_bin_count_0(frame_bin_count_0),
        .frame_error_0(frame_error_0),
        .frame_id_0(frame_id_0),
        .high_bin_0(high_bin_0),
        .high_signed_bin_0(high_signed_bin_0),
        .low_bin_0(low_bin_0),
        .low_signed_bin_0(low_signed_bin_0),
        .m_changed_0(m_changed_0),
        .m_i_0(m_i_0),
        .m_q_0(m_q_0),
        .m_valid_0(m_valid_0),
        .min_power_0(min_power_0),
        .no_active_0(no_active_0),
        .overflow_0(overflow_0),
        .overflow_count_0(overflow_count_0),
        .overflow_seen_0(overflow_seen_0),
        .peak_bin_0(peak_bin_0),
        .peak_power_0(peak_power_0),
        .peak_signed_bin_0(peak_signed_bin_0),
        .rate_changed_0(rate_changed_0),
        .settling_0(settling_0),
        .signal_generator_valid_out(signal_generator_valid_out),
        .stable_count_0(stable_count_0),
        .total_power_0(total_power_0),
        .valid_out(estimate_valid)
    );

    assign q_out_internal = DUT.BAAD_BD_i.IQ_Mixing_P_1;
    assign psd_bin_internal = DUT.BAAD_BD_i.Power_Spectral_Density_psd_bin_0;
    assign psd_last_internal = DUT.BAAD_BD_i.Power_Spectral_Density_psd_last_0;
    assign psd_overflow_internal = DUT.BAAD_BD_i.Power_Spectral_Density_psd_overflow_0;
    assign psd_power_internal = DUT.BAAD_BD_i.Power_Spectral_Density_psd_power_0;
    assign psd_valid_internal = DUT.BAAD_BD_i.and_2_to_1_0_valid_out;
    assign cic_input_valid_internal = DUT.BAAD_BD_i.and_2_to_1_0_valid_out1;
    assign rst_n_internal = DUT.BAAD_BD_i.proc_sys_reset_0_peripheral_aresetn;
    assign cfg_power_threshold_internal = DUT.BAAD_BD_i.xlconstant_0_dout;

    initial begin
        clock = 1'b0;
        forever #(CLK_PERIOD_NS / 2.0) clock = ~clock;
    end

    initial begin
        cycle_count = 0;
        psd_valid_count = 0;
        psd_frame_count = 0;
        psd_last_count = 0;
        psd_overflow_count = 0;
        psd_bins_in_frame = 0;
        bin_order_warning_count = 0;
        last_timing_warning_count = 0;

        estimate_count = 0;
        estimate_frame_error_count = 0;
        estimate_overflow_seen_count = 0;
        estimate_active_missing_count = 0;
        estimate_frame_bin_warning_count = 0;
        estimate_frame_id_warning_count = 0;

        decision_count = 0;
        decision_error_count = 0;
        decision_no_active_count = 0;
        decision_m_changed_count = 0;
        decision_frame_id_warning_count = 0;
        decision_candidate_warning_count = 0;

        cic_input_sample_count = 0;
        cic_output_sample_count = 0;
        cic_rate_changed_count = 0;
        cic_cfg_error_count = 0;
        cic_overflow_count = 0;
        cic_settling_cycle_count = 0;

        done = 0;
        bin_hz = SAMPLE_RATE_HZ / NFFT;

        trace_file = $fopen("baad_complete_trace.csv", "w");
        psd_file = $fopen("baad_psd_valid_bins.csv", "w");
        bw_file = $fopen("baad_bandwidth_estimates.csv", "w");
        decision_file = $fopen("baad_decimation_decisions.csv", "w");
        cic_input_file = $fopen("baad_cic_input_samples.csv", "w");
        cic_output_file = $fopen("baad_cic_output_samples.csv", "w");
        summary_file = $fopen("baad_sim_summary.csv", "w");

        if (trace_file == 0 || psd_file == 0 || bw_file == 0 ||
            decision_file == 0 || cic_input_file == 0 ||
            cic_output_file == 0 || summary_file == 0) begin
            $display("ERROR: Could not open one or more CSV files.");
            $stop;
        end

        $fdisplay(trace_file,
            "cycle,time_ns,dout,I_out,Q_out_internal,signal_generator_valid_out,rst_n,cfg_power_threshold,psd_valid,psd_bin,psd_power,psd_last,psd_overflow,estimate_valid,frame_id,active_found,frame_error,overflow_seen,frame_bin_count,active_bin_count,overflow_count,low_bin,low_signed_bin,high_bin,high_signed_bin,bw_span_bins,bw_edge_bins,peak_bin,peak_signed_bin,peak_power,min_power,total_power,active_power,decision_valid,decision_frame_id,candidate_factor_m,decimation_factor_m,m_changed,decision_error,no_active,decision_edge_bins,stable_count,cic_m_valid,cic_i,cic_q,cic_active_m,cic_gain_shift,cic_rate_changed,cic_settling,cic_cfg_error,cic_overflow,cic_input_sample_count,cic_output_sample_count");

        $fdisplay(psd_file,
            "frame,bin_position,time_ns,psd_bin,signed_bin,psd_power,psd_last,psd_overflow");

        $fdisplay(bw_file,
            "estimate_index,time_ns,frame_id,active_found,frame_error,overflow_seen,frame_bin_count,active_bin_count,overflow_count,low_bin,low_signed_bin,high_bin,high_signed_bin,bw_span_bins,bw_edge_bins,peak_bin,peak_signed_bin,peak_power,min_power,total_power,active_power,bw_span_hz,bw_edge_hz,cfg_power_threshold");

        $fdisplay(decision_file,
            "decision_index,time_ns,decision_frame_id,source_estimator_frame_id,candidate_factor_m,decimation_factor_m,expected_candidate_factor_m,m_changed,decision_error,no_active,decision_edge_bins,bw_edge_bins,stable_count,decision_edge_hz,decision_edge_mhz");

        $fdisplay(cic_input_file,
            "input_sample_index,cycle,time_ns,I_in,Q_in,iq_valid,requested_m,active_m,active_gain_shift,rate_changed,settling,cfg_error,overflow");

        $fdisplay(cic_output_file,
            "output_sample_index,input_sample_index_at_output,cycle,time_ns,I_out,Q_out,m_valid,requested_m,active_m,active_gain_shift,rate_changed,settling,cfg_error,overflow");

        $fdisplay(summary_file,
            "metric,value");
    end

    always @(posedge clock) begin
        if (done == 0) begin
            cycle_count = cycle_count + 1;

            $fdisplay(trace_file,
                "%0d,%0.3f,%0d,%0d,%0d,%0b,%0b,%0d,%0b,%0d,%0d,%0b,%0b,%0b,%0d,%0b,%0b,%0b,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0b,%0d,%0d,%0d,%0b,%0b,%0b,%0d,%0d,%0b,%0d,%0d,%0d,%0d,%0b,%0b,%0b,%0b,%0d,%0d",
                cycle_count,
                $realtime,
                $signed(dout),
                $signed(I_out),
                $signed(q_out_internal),
                signal_generator_valid_out,
                rst_n_internal,
                cfg_power_threshold_internal,
                psd_valid_internal,
                psd_bin_internal,
                psd_power_internal,
                psd_last_internal,
                psd_overflow_internal,
                estimate_valid,
                frame_id_0,
                active_found_0,
                frame_error_0,
                overflow_seen_0,
                frame_bin_count_0,
                active_bin_count_0,
                overflow_count_0,
                low_bin_0,
                $signed(low_signed_bin_0),
                high_bin_0,
                $signed(high_signed_bin_0),
                bw_span_bins_0,
                bw_edge_bins_0,
                peak_bin_0,
                $signed(peak_signed_bin_0),
                peak_power_0,
                min_power_0,
                total_power_0,
                active_power_0,
                decision_valid_0,
                decision_frame_id_0,
                candidate_factor_m_0,
                decimation_factor_m_0,
                m_changed_0,
                decision_error_0,
                no_active_0,
                decision_edge_bins_0,
                stable_count_0,
                m_valid_0,
                $signed(m_i_0),
                $signed(m_q_0),
                active_decimation_factor_0,
                active_gain_shift_0,
                rate_changed_0,
                settling_0,
                cfg_error_0,
                overflow_0,
                cic_input_sample_count,
                cic_output_sample_count);

            if (cic_input_valid_internal === 1'b1) begin
                $fdisplay(cic_input_file,
                    "%0d,%0d,%0.3f,%0d,%0d,%0b,%0d,%0d,%0d,%0b,%0b,%0b,%0b",
                    cic_input_sample_count,
                    cycle_count,
                    $realtime,
                    $signed(I_out),
                    $signed(q_out_internal),
                    cic_input_valid_internal,
                    decimation_factor_m_0,
                    active_decimation_factor_0,
                    active_gain_shift_0,
                    rate_changed_0,
                    settling_0,
                    cfg_error_0,
                    overflow_0);

                cic_input_sample_count = cic_input_sample_count + 1;
            end

            if (m_valid_0 === 1'b1) begin
                $fdisplay(cic_output_file,
                    "%0d,%0d,%0d,%0.3f,%0d,%0d,%0b,%0d,%0d,%0d,%0b,%0b,%0b,%0b",
                    cic_output_sample_count,
                    cic_input_sample_count,
                    cycle_count,
                    $realtime,
                    $signed(m_i_0),
                    $signed(m_q_0),
                    m_valid_0,
                    decimation_factor_m_0,
                    active_decimation_factor_0,
                    active_gain_shift_0,
                    rate_changed_0,
                    settling_0,
                    cfg_error_0,
                    overflow_0);

                cic_output_sample_count = cic_output_sample_count + 1;
            end

            if (rate_changed_0 === 1'b1) begin
                cic_rate_changed_count = cic_rate_changed_count + 1;
            end

            if (cfg_error_0 === 1'b1) begin
                cic_cfg_error_count = cic_cfg_error_count + 1;
            end

            if (overflow_0 === 1'b1) begin
                cic_overflow_count = cic_overflow_count + 1;
            end

            if (settling_0 === 1'b1) begin
                cic_settling_cycle_count = cic_settling_cycle_count + 1;
            end

            if (psd_valid_internal === 1'b1) begin
                $fdisplay(psd_file,
                    "%0d,%0d,%0.3f,%0d,%0d,%0d,%0b,%0b",
                    psd_frame_count,
                    psd_bins_in_frame,
                    $realtime,
                    psd_bin_internal,
                    signed_fft_bin(psd_bin_internal),
                    psd_power_internal,
                    psd_last_internal,
                    psd_overflow_internal);

                psd_valid_count = psd_valid_count + 1;

                if (psd_overflow_internal === 1'b1) begin
                    psd_overflow_count = psd_overflow_count + 1;
                end

                if (psd_bin_internal !== psd_bins_in_frame[10:0]) begin
                    bin_order_warning_count = bin_order_warning_count + 1;
                    if (bin_order_warning_count <= 8) begin
                        $display("WARNING: PSD bin order mismatch at time %0.3f ns. Expected %0d, got %0d.",
                                 $realtime, psd_bins_in_frame, psd_bin_internal);
                    end
                end

                if (psd_last_internal === 1'b1) begin
                    psd_last_count = psd_last_count + 1;

                    if (psd_bins_in_frame != (NFFT - 1)) begin
                        last_timing_warning_count = last_timing_warning_count + 1;
                        $display("WARNING: psd_last asserted after %0d valid bins instead of %0d at time %0.3f ns.",
                                 psd_bins_in_frame + 1, NFFT, $realtime);
                    end

                    psd_frame_count = psd_frame_count + 1;
                    psd_bins_in_frame = 0;
                end else begin
                    if (psd_bins_in_frame == (NFFT - 1)) begin
                        last_timing_warning_count = last_timing_warning_count + 1;
                        $display("WARNING: Missing psd_last at end of %0d-bin frame at time %0.3f ns.",
                                 NFFT, $realtime);
                    end

                    psd_bins_in_frame = psd_bins_in_frame + 1;
                end
            end

            if (estimate_valid === 1'b1) begin
                $fdisplay(bw_file,
                    "%0d,%0.3f,%0d,%0b,%0b,%0b,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.3f,%0.3f,%0d",
                    estimate_count,
                    $realtime,
                    frame_id_0,
                    active_found_0,
                    frame_error_0,
                    overflow_seen_0,
                    frame_bin_count_0,
                    active_bin_count_0,
                    overflow_count_0,
                    low_bin_0,
                    $signed(low_signed_bin_0),
                    high_bin_0,
                    $signed(high_signed_bin_0),
                    bw_span_bins_0,
                    bw_edge_bins_0,
                    peak_bin_0,
                    $signed(peak_signed_bin_0),
                    peak_power_0,
                    min_power_0,
                    total_power_0,
                    active_power_0,
                    bw_span_bins_0 * bin_hz,
                    bw_edge_bins_0 * bin_hz,
                    cfg_power_threshold_internal);

                if (frame_id_0 !== estimate_count) begin
                    estimate_frame_id_warning_count = estimate_frame_id_warning_count + 1;
                    $display("WARNING: Estimator frame_id mismatch at time %0.3f ns. Expected %0d, got %0d.",
                             $realtime, estimate_count, frame_id_0);
                end

                if (frame_error_0 === 1'b1) begin
                    estimate_frame_error_count = estimate_frame_error_count + 1;
                    $display("WARNING: Estimator frame_error asserted for frame_id %0d at time %0.3f ns.",
                             frame_id_0, $realtime);
                end

                if (overflow_seen_0 === 1'b1) begin
                    estimate_overflow_seen_count = estimate_overflow_seen_count + 1;
                    $display("WARNING: Estimator saw PSD overflow for frame_id %0d at time %0.3f ns.",
                             frame_id_0, $realtime);
                end

                if (active_found_0 !== 1'b1) begin
                    estimate_active_missing_count = estimate_active_missing_count + 1;
                    $display("WARNING: Estimator did not find active bins for frame_id %0d at time %0.3f ns.",
                             frame_id_0, $realtime);
                end

                if (frame_bin_count_0 != NFFT) begin
                    estimate_frame_bin_warning_count = estimate_frame_bin_warning_count + 1;
                    $display("WARNING: Estimator counted %0d PSD bins instead of %0d for frame_id %0d.",
                             frame_bin_count_0, NFFT, frame_id_0);
                end

                estimate_count = estimate_count + 1;
            end

            if (decision_valid_0 === 1'b1) begin
                $fdisplay(decision_file,
                    "%0d,%0.3f,%0d,%0d,%0d,%0d,%0d,%0b,%0b,%0b,%0d,%0d,%0d,%0.3f,%0.6f",
                    decision_count,
                    $realtime,
                    decision_frame_id_0,
                    frame_id_0,
                    candidate_factor_m_0,
                    decimation_factor_m_0,
                    expected_decimation_factor(decision_edge_bins_0, !no_active_0, decision_error_0),
                    m_changed_0,
                    decision_error_0,
                    no_active_0,
                    decision_edge_bins_0,
                    bw_edge_bins_0,
                    stable_count_0,
                    decision_edge_bins_0 * bin_hz,
                    decision_edge_bins_0 * bin_hz / 1000000.0);

                if (decision_frame_id_0 !== decision_count) begin
                    decision_frame_id_warning_count = decision_frame_id_warning_count + 1;
                    $display("WARNING: Decision frame_id mismatch at time %0.3f ns. Expected %0d, got %0d.",
                             $realtime, decision_count, decision_frame_id_0);
                end

                if (decision_error_0 === 1'b1) begin
                    decision_error_count = decision_error_count + 1;
                    $display("WARNING: Decision control reported decision_error for frame_id %0d at time %0.3f ns.",
                             decision_frame_id_0, $realtime);
                end

                if (no_active_0 === 1'b1) begin
                    decision_no_active_count = decision_no_active_count + 1;
                    $display("WARNING: Decision control reported no_active for frame_id %0d at time %0.3f ns.",
                             decision_frame_id_0, $realtime);
                end

                if (m_changed_0 === 1'b1) begin
                    decision_m_changed_count = decision_m_changed_count + 1;
                end

                if (candidate_factor_m_0 !== expected_decimation_factor(decision_edge_bins_0, !no_active_0, decision_error_0)) begin
                    decision_candidate_warning_count = decision_candidate_warning_count + 1;
                    $display("WARNING: Decision candidate M mismatch at time %0.3f ns. Expected %0d, got %0d.",
                             $realtime,
                             expected_decimation_factor(decision_edge_bins_0, !no_active_0, decision_error_0),
                             candidate_factor_m_0);
                end

                decision_count = decision_count + 1;

                if (decision_count >= ESTIMATE_FRAME_LIMIT) begin
                    finish_simulation;
                end
            end

            if (cycle_count >= MAX_SIM_CYCLES) begin
                $display("WARNING: Simulation timeout before collecting %0d decimation decisions.",
                         ESTIMATE_FRAME_LIMIT);
                finish_simulation;
            end
        end
    end

    function integer signed_fft_bin;
        input [10:0] bin;
        begin
            if (bin >= (NFFT / 2)) begin
                signed_fft_bin = bin - NFFT;
            end else begin
                signed_fft_bin = bin;
            end
        end
    endfunction

    function factor_fits_tb;
        input [11:0] edge_bins;
        input integer factor_m;
        reg [63:0] lhs;
        reg [63:0] rhs;
        begin
            lhs = edge_bins;
            lhs = lhs * 2 * factor_m * GUARD_DEN;

            rhs = NFFT;
            rhs = rhs * GUARD_NUM;

            factor_fits_tb = (lhs <= rhs);
        end
    endfunction

    function [15:0] expected_decimation_factor;
        input [11:0] edge_bins;
        input active_found;
        input decision_error;
        integer bit_idx;
        reg [15:0] trial_factor_m;
        reg found_factor;
        begin
            if (decision_error || !active_found) begin
                expected_decimation_factor = SAFE_M;
            end else begin
                expected_decimation_factor = SAFE_M;
                found_factor = 1'b0;

                for (bit_idx = 15; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                    trial_factor_m = 16'd1 << bit_idx;

                    if (!found_factor &&
                        (trial_factor_m <= MAX_DECIMATION_VALUE) &&
                        (trial_factor_m >= SAFE_M_VALUE) &&
                        factor_fits_tb(edge_bins, trial_factor_m)) begin
                        expected_decimation_factor = trial_factor_m;
                        found_factor = 1'b1;
                    end
                end
            end
        end
    endfunction

    task finish_simulation;
    begin
        if (done == 0) begin
            done = 1;

            $fdisplay(summary_file, "total_cycles,%0d", cycle_count);
            $fdisplay(summary_file, "psd_valid_count,%0d", psd_valid_count);
            $fdisplay(summary_file, "psd_frame_count,%0d", psd_frame_count);
            $fdisplay(summary_file, "psd_last_count,%0d", psd_last_count);
            $fdisplay(summary_file, "psd_overflow_count,%0d", psd_overflow_count);
            $fdisplay(summary_file, "bin_order_warning_count,%0d", bin_order_warning_count);
            $fdisplay(summary_file, "last_timing_warning_count,%0d", last_timing_warning_count);
            $fdisplay(summary_file, "remaining_bins_in_partial_frame,%0d", psd_bins_in_frame);
            $fdisplay(summary_file, "estimate_count,%0d", estimate_count);
            $fdisplay(summary_file, "estimate_frame_error_count,%0d", estimate_frame_error_count);
            $fdisplay(summary_file, "estimate_overflow_seen_count,%0d", estimate_overflow_seen_count);
            $fdisplay(summary_file, "estimate_active_missing_count,%0d", estimate_active_missing_count);
            $fdisplay(summary_file, "estimate_frame_bin_warning_count,%0d", estimate_frame_bin_warning_count);
            $fdisplay(summary_file, "estimate_frame_id_warning_count,%0d", estimate_frame_id_warning_count);
            $fdisplay(summary_file, "decision_count,%0d", decision_count);
            $fdisplay(summary_file, "decision_error_count,%0d", decision_error_count);
            $fdisplay(summary_file, "decision_no_active_count,%0d", decision_no_active_count);
            $fdisplay(summary_file, "decision_m_changed_count,%0d", decision_m_changed_count);
            $fdisplay(summary_file, "decision_frame_id_warning_count,%0d", decision_frame_id_warning_count);
            $fdisplay(summary_file, "decision_candidate_warning_count,%0d", decision_candidate_warning_count);
            $fdisplay(summary_file, "cic_input_sample_count,%0d", cic_input_sample_count);
            $fdisplay(summary_file, "cic_output_sample_count,%0d", cic_output_sample_count);
            $fdisplay(summary_file, "cic_rate_changed_count,%0d", cic_rate_changed_count);
            $fdisplay(summary_file, "cic_cfg_error_count,%0d", cic_cfg_error_count);
            $fdisplay(summary_file, "cic_overflow_count,%0d", cic_overflow_count);
            $fdisplay(summary_file, "cic_settling_cycle_count,%0d", cic_settling_cycle_count);
            $fdisplay(summary_file, "final_cic_active_decimation_factor,%0d", active_decimation_factor_0);
            $fdisplay(summary_file, "final_cic_active_gain_shift,%0d", active_gain_shift_0);
            $fdisplay(summary_file, "final_decimation_factor_m,%0d", decimation_factor_m_0);
            $fdisplay(summary_file, "final_candidate_factor_m,%0d", candidate_factor_m_0);
            $fdisplay(summary_file, "final_stable_count,%0d", stable_count_0);
            $fdisplay(summary_file, "sample_rate_hz,%0.6f", SAMPLE_RATE_HZ);
            $fdisplay(summary_file, "bin_hz,%0.6f", bin_hz);

            $display("Simulation complete.");
            $display("  PSD frames observed          : %0d", psd_frame_count);
            $display("  PSD valid bins observed      : %0d", psd_valid_count);
            $display("  Bandwidth estimates captured : %0d", estimate_count);
            $display("  Decisions captured           : %0d", decision_count);
            $display("  Final decimation factor M    : %0d", decimation_factor_m_0);
            $display("  CIC input samples dumped     : %0d", cic_input_sample_count);
            $display("  CIC output samples dumped    : %0d", cic_output_sample_count);
            $display("  CIC rate changes             : %0d", cic_rate_changed_count);
            $display("  CIC cfg errors               : %0d", cic_cfg_error_count);
            $display("  CIC overflows                : %0d", cic_overflow_count);
            $display("  Estimator frame errors       : %0d", estimate_frame_error_count);
            $display("  Estimator overflow frames    : %0d", estimate_overflow_seen_count);
            $display("  Estimator missing-active     : %0d", estimate_active_missing_count);
            $display("  Decision errors              : %0d", decision_error_count);
            $display("  Decision candidate warnings  : %0d", decision_candidate_warning_count);
            $display("  CSV: baad_complete_trace.csv");
            $display("  CSV: baad_psd_valid_bins.csv");
            $display("  CSV: baad_bandwidth_estimates.csv");
            $display("  CSV: baad_decimation_decisions.csv");
            $display("  CSV: baad_cic_input_samples.csv");
            $display("  CSV: baad_cic_output_samples.csv");
            $display("  CSV: baad_sim_summary.csv");

            $fclose(trace_file);
            $fclose(psd_file);
            $fclose(bw_file);
            $fclose(decision_file);
            $fclose(cic_input_file);
            $fclose(cic_output_file);
            $fclose(summary_file);

            $finish;
        end
    end
    endtask

endmodule
