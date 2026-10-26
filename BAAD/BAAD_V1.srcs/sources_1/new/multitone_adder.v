module multitone_adder #(
    parameter IN_WIDTH  = 16,
    parameter OUT_WIDTH = 16
)(
    input  wire                      clk,

    input  wire signed [IN_WIDTH-1:0] dds1,
    input  wire signed [IN_WIDTH-1:0] dds2,
    input  wire signed [IN_WIDTH-1:0] dds3,
    input  wire signed [IN_WIDTH-1:0] dds4,
    input  wire signed [IN_WIDTH-1:0] dds5,
    input  wire signed [IN_WIDTH-1:0] dds6,

    output reg  signed [OUT_WIDTH-1:0] dout
);

    // ---- Sign extend to prevent overflow ----
    wire signed [19:0] s1 = {{4{dds1[15]}}, dds1};
    wire signed [19:0] s2 = {{4{dds2[15]}}, dds2};
    wire signed [19:0] s3 = {{4{dds3[15]}}, dds3};
    wire signed [19:0] s4 = {{4{dds4[15]}}, dds4};
    wire signed [19:0] s5 = {{4{dds5[15]}}, dds5};
    wire signed [19:0] s6 = {{4{dds6[15]}}, dds6};

    // ---- Adder tree (balanced) ----
    wire signed [20:0] sum1 = s1 + s2;
    wire signed [20:0] sum2 = s3 + s4;
    wire signed [20:0] sum3 = s5 + s6;

    wire signed [21:0] sum4 = sum1 + sum2;
    wire signed [22:0] sum  = sum4 + sum3;

    // ---- Scaling (divide by 8 to avoid overflow) ----
    wire signed [22:0] scaled = sum >>> 3;

    // ---- Output register ----
    always @(posedge clk) begin
        dout <= scaled[15:0]; // back to Q1.15
    end

endmodule