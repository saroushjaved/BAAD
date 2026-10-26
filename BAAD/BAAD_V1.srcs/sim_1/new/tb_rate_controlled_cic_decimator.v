`timescale 1ns / 1ps

module tb_rate_controlled_cic_decimator;

    localparam integer IN_WIDTH = 16;
    localparam integer OUT_WIDTH = 16;
    localparam integer ACC_WIDTH = 32;
    localparam integer STAGES = 3;
    localparam integer RATE_WIDTH = 16;
    localparam integer SHIFT_WIDTH = 8;

    reg clk;
    reg rst_n;
    reg signed [IN_WIDTH-1:0] s_i;
    reg signed [IN_WIDTH-1:0] s_q;
    reg s_valid;
    reg [RATE_WIDTH-1:0] cfg_decimation_factor;
    reg cfg_valid;

    wire signed [OUT_WIDTH-1:0] m_i;
    wire signed [OUT_WIDTH-1:0] m_q;
    wire m_valid;
    wire [RATE_WIDTH-1:0] active_decimation_factor;
    wire [SHIFT_WIDTH-1:0] active_gain_shift;
    wire rate_changed;
    wire settling;
    wire cfg_error;
    wire overflow;

    integer cycle_count;
    integer sample_count;
    integer out_count;
    integer errors;
    integer valid_seen_after_settle;

    rate_controlled_cic_decimator #(
        .IN_WIDTH(IN_WIDTH),
        .OUT_WIDTH(OUT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .STAGES(STAGES),
        .DIFF_DELAY(1),
        .RATE_WIDTH(RATE_WIDTH),
        .SHIFT_WIDTH(SHIFT_WIDTH),
        .MAX_DECIMATION(16),
        .REQUIRE_POWER_OF_TWO_RATE(1),
        .SETTLING_OUTPUTS(STAGES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_i(s_i),
        .s_q(s_q),
        .s_valid(s_valid),
        .cfg_decimation_factor(cfg_decimation_factor),
        .cfg_valid(cfg_valid),
        .m_i(m_i),
        .m_q(m_q),
        .m_valid(m_valid),
        .active_decimation_factor(active_decimation_factor),
        .active_gain_shift(active_gain_shift),
        .rate_changed(rate_changed),
        .settling(settling),
        .cfg_error(cfg_error),
        .overflow(overflow)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task apply_rate;
        input [RATE_WIDTH-1:0] rate_value;
        begin
            @(posedge clk);
            cfg_decimation_factor <= rate_value;
            cfg_valid <= 1'b1;
            @(posedge clk);
            cfg_valid <= 1'b0;
        end
    endtask

    task run_samples;
        input integer count;
        integer n;
        begin
            for (n = 0; n < count; n = n + 1) begin
                @(posedge clk);
                s_valid <= 1'b1;
                s_i <= 16'sd1000;
                s_q <= -16'sd500;
            end
        end
    endtask

    task expect_rate_state;
        input [RATE_WIDTH-1:0] expected_rate;
        input [SHIFT_WIDTH-1:0] expected_shift;
        begin
            if (active_decimation_factor !== expected_rate) begin
                $display("ERROR: active rate %0d, expected %0d at cycle %0d",
                         active_decimation_factor, expected_rate, cycle_count);
                errors = errors + 1;
            end

            if (active_gain_shift !== expected_shift) begin
                $display("ERROR: active gain shift %0d, expected %0d at cycle %0d",
                         active_gain_shift, expected_shift, cycle_count);
                errors = errors + 1;
            end
        end
    endtask

    task check_dc_outputs;
        input integer min_outputs;
        begin
            valid_seen_after_settle = 0;

            while (valid_seen_after_settle < min_outputs) begin
                @(posedge clk);
                s_valid <= 1'b1;

                if (m_valid && !settling) begin
                    valid_seen_after_settle = valid_seen_after_settle + 1;

                    if ((m_i !== 16'sd1000) || (m_q !== -16'sd500)) begin
                        $display("ERROR: normalized DC output I=%0d Q=%0d at cycle %0d",
                                 m_i, m_q, cycle_count);
                        errors = errors + 1;
                    end
                end
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
            sample_count <= 0;
            out_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (s_valid) begin
                sample_count <= sample_count + 1;
            end

            if (m_valid) begin
                out_count <= out_count + 1;
            end
        end
    end

    initial begin
        rst_n = 1'b0;
        s_i = 16'sd0;
        s_q = 16'sd0;
        s_valid = 1'b0;
        cfg_decimation_factor = 16'd1;
        cfg_valid = 1'b0;
        errors = 0;
        valid_seen_after_settle = 0;

        repeat (6) @(posedge clk);
        rst_n = 1'b1;

        run_samples(32);
        expect_rate_state(16'd1, 8'd0);

        apply_rate(16'd2);
        run_samples(8);
        expect_rate_state(16'd2, 8'd3);
        check_dc_outputs(6);

        apply_rate(16'd4);
        run_samples(16);
        expect_rate_state(16'd4, 8'd6);
        check_dc_outputs(6);

        apply_rate(16'd8);
        run_samples(32);
        expect_rate_state(16'd8, 8'd9);
        check_dc_outputs(6);

        apply_rate(16'd16);
        run_samples(64);
        expect_rate_state(16'd16, 8'd12);
        check_dc_outputs(6);

        apply_rate(16'd3);
        @(posedge clk);
        if (!cfg_error) begin
            $display("ERROR: cfg_error did not assert for invalid non-power-of-two rate");
            errors = errors + 1;
        end

        // The safe fallback commits at the next M16 sample boundary, not
        // necessarily within eight samples. Allow a full boundary plus margin.
        run_samples(32);
        expect_rate_state(16'd1, 8'd0);

        apply_rate(16'd0);
        @(posedge clk);
        if (!cfg_error) begin
            $display("ERROR: cfg_error did not assert for zero rate");
            errors = errors + 1;
        end

        run_samples(16);

        if (overflow) begin
            $display("ERROR: unexpected overflow");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: rate_controlled_cic_decimator test completed.");
        end else begin
            $display("FAIL: rate_controlled_cic_decimator test completed with %0d errors.", errors);
            $stop;
        end

        $finish;
    end

endmodule
