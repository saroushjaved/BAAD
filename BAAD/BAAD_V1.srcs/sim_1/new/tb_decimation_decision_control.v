`timescale 1ns / 1ps

module tb_decimation_decision_control;

    localparam integer NFFT = 2048;
    localparam integer BIN_WIDTH = 11;
    localparam integer M_WIDTH = 16;
    localparam integer GUARD_NUM = 4;
    localparam integer GUARD_DEN = 5;
    localparam integer SAFE_M = 1;

    reg clk;
    reg rst_n;
    reg estimate_valid;
    reg [31:0] frame_id;
    reg active_found;
    reg frame_error;
    reg overflow_seen;
    reg [BIN_WIDTH:0] bw_edge_bins;

    wire decision_valid_16;
    wire [M_WIDTH-1:0] decimation_factor_m_16;
    wire [M_WIDTH-1:0] candidate_factor_m_16;
    wire m_changed_16;

    wire decision_valid_32;
    wire [M_WIDTH-1:0] decimation_factor_m_32;
    wire [M_WIDTH-1:0] candidate_factor_m_32;
    wire m_changed_32;

    integer error_count;

    decimation_decision_control #(
        .NFFT(NFFT),
        .BIN_WIDTH(BIN_WIDTH),
        .M_WIDTH(M_WIDTH),
        .GUARD_NUM(GUARD_NUM),
        .GUARD_DEN(GUARD_DEN),
        .STABLE_FRAME_COUNT(1),
        .SAFE_M(SAFE_M),
        .NO_ACTIVE_M(SAFE_M),
        .MAX_DECIMATION(16)
    ) dut_max16 (
        .clk(clk),
        .rst_n(rst_n),
        .estimate_valid(estimate_valid),
        .frame_id(frame_id),
        .active_found(active_found),
        .frame_error(frame_error),
        .overflow_seen(overflow_seen),
        .bw_edge_bins(bw_edge_bins),
        .decision_valid(decision_valid_16),
        .decision_frame_id(),
        .decimation_factor_m(decimation_factor_m_16),
        .candidate_factor_m(candidate_factor_m_16),
        .m_changed(m_changed_16),
        .decision_error(),
        .no_active(),
        .decision_edge_bins(),
        .stable_count()
    );

    decimation_decision_control #(
        .NFFT(NFFT),
        .BIN_WIDTH(BIN_WIDTH),
        .M_WIDTH(M_WIDTH),
        .GUARD_NUM(GUARD_NUM),
        .GUARD_DEN(GUARD_DEN),
        .STABLE_FRAME_COUNT(1),
        .SAFE_M(SAFE_M),
        .NO_ACTIVE_M(SAFE_M),
        .MAX_DECIMATION(32)
    ) dut_max32 (
        .clk(clk),
        .rst_n(rst_n),
        .estimate_valid(estimate_valid),
        .frame_id(frame_id),
        .active_found(active_found),
        .frame_error(frame_error),
        .overflow_seen(overflow_seen),
        .bw_edge_bins(bw_edge_bins),
        .decision_valid(decision_valid_32),
        .decision_frame_id(),
        .decimation_factor_m(decimation_factor_m_32),
        .candidate_factor_m(candidate_factor_m_32),
        .m_changed(m_changed_32),
        .decision_error(),
        .no_active(),
        .decision_edge_bins(),
        .stable_count()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        error_count = 0;
        rst_n = 1'b0;
        estimate_valid = 1'b0;
        frame_id = 32'd0;
        active_found = 1'b0;
        frame_error = 1'b0;
        overflow_seen = 1'b0;
        bw_edge_bins = {1'b0, {BIN_WIDTH{1'b0}}};

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        check_max16(12'd500, 1'b1, 1'b0, 1'b0, 16'd1,  "wide bandwidth forces M=1");
        check_max16(12'd331, 1'b1, 1'b0, 1'b0, 16'd2,  "current edge selects M=2");
        check_max16(12'd180, 1'b1, 1'b0, 1'b0, 16'd4,  "smaller edge selects M=4");
        check_max16(12'd90,  1'b1, 1'b0, 1'b0, 16'd8,  "smaller edge selects M=8");
        check_max16(12'd40,  1'b1, 1'b0, 1'b0, 16'd16, "small edge selects M=16");
        check_max32(12'd15,  1'b1, 1'b0, 1'b0, 16'd32, "MAX_DECIMATION=32 with inward margin");
        check_max16(12'd40,  1'b0, 1'b0, 1'b0, 16'd1,  "no active bins fallback");
        check_max16(12'd40,  1'b1, 1'b1, 1'b0, 16'd1,  "frame error fallback");
        check_max16(12'd40,  1'b1, 1'b0, 1'b1, 16'd1,  "overflow fallback");

        if (error_count == 0) begin
            $display("PASS: decimation_decision_control generic M selection");
        end else begin
            $display("FAIL: %0d decimation_decision_control checks failed", error_count);
        end

        $finish;
    end

    task drive_estimate;
        input [BIN_WIDTH:0] edge_bins;
        input active;
        input error_flag;
        input overflow_flag;
    begin
        @(negedge clk);
        bw_edge_bins = edge_bins;
        active_found = active;
        frame_error = error_flag;
        overflow_seen = overflow_flag;
        estimate_valid = 1'b1;

        @(posedge clk);
        #1;
        @(negedge clk);
        estimate_valid = 1'b0;
        frame_id = frame_id + 1'b1;
    end
    endtask

    task check_max16;
        input [BIN_WIDTH:0] edge_bins;
        input active;
        input error_flag;
        input overflow_flag;
        input [M_WIDTH-1:0] expected_m;
        input [8*48-1:0] label;
    begin
        drive_estimate(edge_bins, active, error_flag, overflow_flag);
        if ((candidate_factor_m_16 !== expected_m) ||
            (decimation_factor_m_16 !== expected_m) ||
            (decision_valid_16 !== 1'b1)) begin
            error_count = error_count + 1;
            $display("ERROR max16 %0s: edge=%0d expected M=%0d candidate=%0d active=%0d decision_valid=%b",
                     label, edge_bins, expected_m, candidate_factor_m_16,
                     decimation_factor_m_16, decision_valid_16);
        end
    end
    endtask

    task check_max32;
        input [BIN_WIDTH:0] edge_bins;
        input active;
        input error_flag;
        input overflow_flag;
        input [M_WIDTH-1:0] expected_m;
        input [8*48-1:0] label;
    begin
        drive_estimate(edge_bins, active, error_flag, overflow_flag);
        if ((candidate_factor_m_32 !== expected_m) ||
            (decimation_factor_m_32 !== expected_m) ||
            (decision_valid_32 !== 1'b1)) begin
            error_count = error_count + 1;
            $display("ERROR max32 %0s: edge=%0d expected M=%0d candidate=%0d active=%0d decision_valid=%b",
                     label, edge_bins, expected_m, candidate_factor_m_32,
                     decimation_factor_m_32, decision_valid_32);
        end
    end
    endtask

endmodule
