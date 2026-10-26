module dds_axi_config_regs #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer PHASE_WIDTH        = 26,
    parameter integer CONFIG_WIDTH       = 32,

    parameter [31:0] DEFAULT_PINC0 = 32'd0,
    parameter [31:0] DEFAULT_PINC1 = 32'd0,
    parameter [31:0] DEFAULT_PINC2 = 32'd0,
    parameter [31:0] DEFAULT_PINC3 = 32'd0,
    parameter [31:0] DEFAULT_PINC4 = 32'd0,
    parameter [31:0] DEFAULT_PINC5 = 32'd0,
    parameter [32:0] DEFAULT_POWER_THRESHOLD = 33'd5000,
    parameter        DEFAULT_DMA_CAPTURE_ENABLE = 1'b0,
    parameter        DEFAULT_DMA_CAPTURE_SUMMARY_ENABLE = 1'b1,
    parameter        DEFAULT_DMA_CAPTURE_CIC_ENABLE = 1'b0,
    parameter        DEFAULT_DMA_CAPTURE_PSD_INPUT_ENABLE = 1'b0,
    parameter [15:0] DEFAULT_DMA_PACKET_RECORD_COUNT = 16'd1,
    parameter [15:0] DEFAULT_DMA_CIC_SAMPLE_INTERVAL = 16'd1,
    parameter [15:0] DEFAULT_DMA_PSD_INPUT_SAMPLE_INTERVAL = 16'd1
)(
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                        s_axi_arprot,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    output wire [CONFIG_WIDTH-1:0]           dds0_s_axis_config_tdata,
    output wire                              dds0_s_axis_config_tvalid,
    output wire                              dds0_s_axis_config_tlast,
    input  wire                              dds0_s_axis_config_tready,

    output wire [CONFIG_WIDTH-1:0]           dds1_s_axis_config_tdata,
    output wire                              dds1_s_axis_config_tvalid,
    output wire                              dds1_s_axis_config_tlast,
    input  wire                              dds1_s_axis_config_tready,

    output wire [CONFIG_WIDTH-1:0]           dds2_s_axis_config_tdata,
    output wire                              dds2_s_axis_config_tvalid,
    output wire                              dds2_s_axis_config_tlast,
    input  wire                              dds2_s_axis_config_tready,

    output wire [CONFIG_WIDTH-1:0]           dds3_s_axis_config_tdata,
    output wire                              dds3_s_axis_config_tvalid,
    output wire                              dds3_s_axis_config_tlast,
    input  wire                              dds3_s_axis_config_tready,

    output wire [CONFIG_WIDTH-1:0]           dds4_s_axis_config_tdata,
    output wire                              dds4_s_axis_config_tvalid,
    output wire                              dds4_s_axis_config_tlast,
    input  wire                              dds4_s_axis_config_tready,

    output wire [CONFIG_WIDTH-1:0]           dds5_s_axis_config_tdata,
    output wire                              dds5_s_axis_config_tvalid,
    output wire                              dds5_s_axis_config_tlast,
    input  wire                              dds5_s_axis_config_tready,

    output wire [32:0]                       cfg_power_threshold,
    output wire                              cfg_dma_capture_enable,
    output wire                              cfg_dma_capture_summary_enable,
    output wire                              cfg_dma_capture_cic_enable,
    output wire                              cfg_dma_capture_psd_input_enable,
    output wire [15:0]                       cfg_dma_packet_record_count,
    output wire [15:0]                       cfg_dma_cic_sample_interval,
    output wire [15:0]                       cfg_dma_psd_input_sample_interval,
    output reg [31:0]                        cfg_burst_control,
    output reg [15:0]                        cfg_burst_sample_count,
    output reg                              capture_flush,
    output wire                             capture_resetn,
    input wire [31:0]                        burst_status,
    input wire [31:0]                        burst_capture_id,
    input wire [31:0]                        records_emitted,
    input wire [31:0]                        records_dropped
);

    localparam [5:0] APPLY_NONE = 6'b000000;
    localparam [5:0] APPLY_ALL  = 6'b111111;

    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_CONTROL = 8'h00;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_STATUS  = 8'h04;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_INFO    = 8'h08;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_PINC0   = 8'h10;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_PINC1   = 8'h14;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_PINC2   = 8'h18;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_PINC3   = 8'h1c;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_PINC4   = 8'h20;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_PINC5   = 8'h24;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_THRESHOLD_LO = 8'h30;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_THRESHOLD_HI = 8'h34;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_DMA_CONTROL = 8'h38;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_DMA_PACKET_RECORD_COUNT = 8'h3c;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_DMA_CIC_SAMPLE_INTERVAL = 8'h40;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_DMA_PSD_INPUT_SAMPLE_INTERVAL = 8'h44;
    localparam [7:0] INFO_NUM_DDS       = 8'd6;
    localparam [7:0] INFO_CONFIG_WIDTH  = CONFIG_WIDTH;
    localparam [7:0] INFO_PHASE_WIDTH   = PHASE_WIDTH;
    localparam [7:0] INFO_VERSION       = 8'h02;

    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg [C_S_AXI_DATA_WIDTH-1:0] wdata_hold;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_hold;
    reg aw_valid_hold;
    reg w_valid_hold;

    reg [31:0] pinc0;
    reg [31:0] pinc1;
    reg [31:0] pinc2;
    reg [31:0] pinc3;
    reg [31:0] pinc4;
    reg [31:0] pinc5;
    reg [5:0]  config_pending;
    // PINC registers are software shadows. Once TVALID is asserted the
    // accepted payload must remain stable, even if software edits a shadow.
    reg [31:0] config_pinc [0:5];
    wire [5:0] apply_mask = ((write_strb[1] && write_data[8]) ? APPLY_ALL :
                              (write_strb[0] ? write_data[5:0] : APPLY_NONE));
    wire [5:0] accept_apply = apply_mask & (~config_pending | dds_ready);
    reg [32:0] power_threshold;
    reg        dma_capture_enable;
    reg        dma_capture_summary_enable;
    reg        dma_capture_cic_enable;
    reg        dma_capture_psd_input_enable;
    reg [15:0] dma_packet_record_count;
    reg [15:0] dma_cic_sample_interval;
    reg [15:0] dma_psd_input_sample_interval;

    wire aw_fire;
    wire w_fire;
    wire write_fire;
    wire [C_S_AXI_ADDR_WIDTH-1:0] write_addr;
    wire [C_S_AXI_DATA_WIDTH-1:0] write_data;
    wire [(C_S_AXI_DATA_WIDTH/8)-1:0] write_strb;
    wire ar_fire;
    wire [5:0] dds_ready;
    wire [5:0] config_done;

    assign aw_fire    = s_axi_awready && s_axi_awvalid;
    assign w_fire     = s_axi_wready && s_axi_wvalid;
    assign write_fire = (aw_valid_hold || aw_fire) && (w_valid_hold || w_fire) && !s_axi_bvalid;
    assign write_addr = aw_valid_hold ? axi_awaddr : s_axi_awaddr;
    assign write_data = w_valid_hold ? wdata_hold : s_axi_wdata;
    assign write_strb = w_valid_hold ? wstrb_hold : s_axi_wstrb;
    assign ar_fire    = s_axi_arready && s_axi_arvalid;

    assign dds_ready = {
        dds5_s_axis_config_tready,
        dds4_s_axis_config_tready,
        dds3_s_axis_config_tready,
        dds2_s_axis_config_tready,
        dds1_s_axis_config_tready,
        dds0_s_axis_config_tready
    };

    assign config_done = config_pending & dds_ready;

    assign dds0_s_axis_config_tvalid = config_pending[0];
    assign dds1_s_axis_config_tvalid = config_pending[1];
    assign dds2_s_axis_config_tvalid = config_pending[2];
    assign dds3_s_axis_config_tvalid = config_pending[3];
    assign dds4_s_axis_config_tvalid = config_pending[4];
    assign dds5_s_axis_config_tvalid = config_pending[5];

    assign dds0_s_axis_config_tlast = config_pending[0];
    assign dds1_s_axis_config_tlast = config_pending[1];
    assign dds2_s_axis_config_tlast = config_pending[2];
    assign dds3_s_axis_config_tlast = config_pending[3];
    assign dds4_s_axis_config_tlast = config_pending[4];
    assign dds5_s_axis_config_tlast = config_pending[5];

    assign dds0_s_axis_config_tdata = {{(CONFIG_WIDTH-PHASE_WIDTH){1'b0}}, config_pinc[0][PHASE_WIDTH-1:0]};
    assign dds1_s_axis_config_tdata = {{(CONFIG_WIDTH-PHASE_WIDTH){1'b0}}, config_pinc[1][PHASE_WIDTH-1:0]};
    assign dds2_s_axis_config_tdata = {{(CONFIG_WIDTH-PHASE_WIDTH){1'b0}}, config_pinc[2][PHASE_WIDTH-1:0]};
    assign dds3_s_axis_config_tdata = {{(CONFIG_WIDTH-PHASE_WIDTH){1'b0}}, config_pinc[3][PHASE_WIDTH-1:0]};
    assign dds4_s_axis_config_tdata = {{(CONFIG_WIDTH-PHASE_WIDTH){1'b0}}, config_pinc[4][PHASE_WIDTH-1:0]};
    assign dds5_s_axis_config_tdata = {{(CONFIG_WIDTH-PHASE_WIDTH){1'b0}}, config_pinc[5][PHASE_WIDTH-1:0]};
    assign cfg_power_threshold = power_threshold;
    assign cfg_dma_capture_enable = dma_capture_enable;
    assign cfg_dma_capture_summary_enable = dma_capture_summary_enable;
    assign cfg_dma_capture_cic_enable = dma_capture_cic_enable;
    assign cfg_dma_capture_psd_input_enable = dma_capture_psd_input_enable;
    assign cfg_dma_packet_record_count = dma_packet_record_count;
    assign cfg_dma_cic_sample_interval = dma_cic_sample_interval;
    assign cfg_dma_psd_input_sample_interval = dma_psd_input_sample_interval;
    assign capture_resetn = s_axi_aresetn && !capture_flush;

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [(C_S_AXI_DATA_WIDTH/8)-1:0] byte_strobe;
        integer byte_index;
        begin
            apply_wstrb = old_value;
            for (byte_index = 0; byte_index < (C_S_AXI_DATA_WIDTH/8); byte_index = byte_index + 1) begin
                if (byte_strobe[byte_index]) begin
                    apply_wstrb[(byte_index*8) +: 8] = new_value[(byte_index*8) +: 8];
                end
            end
        end
    endfunction

    function [31:0] read_register;
        input [C_S_AXI_ADDR_WIDTH-1:0] read_addr;
        begin
            case (read_addr)
                ADDR_CONTROL: read_register = 32'd0;
                ADDR_STATUS:  read_register = {15'd0, |config_pending, 2'd0, dds_ready, 2'd0, config_pending};
                ADDR_INFO:    read_register = {INFO_NUM_DDS, INFO_CONFIG_WIDTH, INFO_PHASE_WIDTH, INFO_VERSION};
                8'h0c: read_register = 32'h26091301;
                8'h48: read_register = cfg_burst_control;
                8'h4c: read_register = {16'd0,cfg_burst_sample_count};
                8'h50: read_register = burst_status;
                8'h54: read_register = records_emitted;
                8'h58: read_register = records_dropped;
                8'h5c: read_register = burst_capture_id;
                ADDR_PINC0:   read_register = pinc0;
                ADDR_PINC1:   read_register = pinc1;
                ADDR_PINC2:   read_register = pinc2;
                ADDR_PINC3:   read_register = pinc3;
                ADDR_PINC4:   read_register = pinc4;
                ADDR_PINC5:   read_register = pinc5;
                ADDR_THRESHOLD_LO: read_register = power_threshold[31:0];
                ADDR_THRESHOLD_HI: read_register = {31'd0, power_threshold[32]};
                ADDR_DMA_CONTROL: read_register = {
                    27'd0, capture_flush,
                    dma_capture_psd_input_enable,
                    dma_capture_cic_enable,
                    dma_capture_summary_enable,
                    dma_capture_enable
                };
                ADDR_DMA_PACKET_RECORD_COUNT: read_register = {16'd0, dma_packet_record_count};
                ADDR_DMA_CIC_SAMPLE_INTERVAL: read_register = {16'd0, dma_cic_sample_interval};
                ADDR_DMA_PSD_INPUT_SAMPLE_INTERVAL: read_register = {16'd0, dma_psd_input_sample_interval};
                default:      read_register = 32'd0;
            endcase
        end
    endfunction

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            axi_awaddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            wdata_hold    <= {C_S_AXI_DATA_WIDTH{1'b0}};
            wstrb_hold    <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
            aw_valid_hold <= 1'b0;
            w_valid_hold  <= 1'b0;
            pinc0          <= DEFAULT_PINC0;
            pinc1          <= DEFAULT_PINC1;
            pinc2          <= DEFAULT_PINC2;
            pinc3          <= DEFAULT_PINC3;
            pinc4          <= DEFAULT_PINC4;
            pinc5          <= DEFAULT_PINC5;
            config_pending <= APPLY_NONE;
            config_pinc[0] <= DEFAULT_PINC0;
            config_pinc[1] <= DEFAULT_PINC1;
            config_pinc[2] <= DEFAULT_PINC2;
            config_pinc[3] <= DEFAULT_PINC3;
            config_pinc[4] <= DEFAULT_PINC4;
            config_pinc[5] <= DEFAULT_PINC5;
            power_threshold <= DEFAULT_POWER_THRESHOLD;
            dma_capture_enable <= DEFAULT_DMA_CAPTURE_ENABLE;
            dma_capture_summary_enable <= DEFAULT_DMA_CAPTURE_SUMMARY_ENABLE;
            dma_capture_cic_enable <= DEFAULT_DMA_CAPTURE_CIC_ENABLE;
            dma_capture_psd_input_enable <= DEFAULT_DMA_CAPTURE_PSD_INPUT_ENABLE;
            dma_packet_record_count <= DEFAULT_DMA_PACKET_RECORD_COUNT;
            dma_cic_sample_interval <= DEFAULT_DMA_CIC_SAMPLE_INTERVAL;
            dma_psd_input_sample_interval <= DEFAULT_DMA_PSD_INPUT_SAMPLE_INTERVAL;
            cfg_burst_control <= 0;
            cfg_burst_sample_count <= 4096;
            capture_flush <= 0;
        end else begin
            if (aw_fire || write_fire || s_axi_bvalid) begin
                s_axi_awready <= 1'b0;
            end else if (!aw_valid_hold) begin
                s_axi_awready <= 1'b1;
            end

            if (w_fire || write_fire || s_axi_bvalid) begin
                s_axi_wready <= 1'b0;
            end else if (!w_valid_hold) begin
                s_axi_wready <= 1'b1;
            end

            if (write_fire) begin
                aw_valid_hold <= 1'b0;
                w_valid_hold  <= 1'b0;
            end else begin
                if (aw_fire) begin
                    aw_valid_hold <= 1'b1;
                    axi_awaddr    <= s_axi_awaddr;
                end

                if (w_fire) begin
                    w_valid_hold <= 1'b1;
                    wdata_hold   <= s_axi_wdata;
                    wstrb_hold   <= s_axi_wstrb;
                end
            end

            if (write_fire) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            config_pending <= config_pending & ~config_done;

            if (write_fire) begin
                case (write_addr)
                    8'h48: cfg_burst_control <= apply_wstrb(cfg_burst_control,write_data,write_strb);
                    8'h4c: cfg_burst_sample_count <= apply_wstrb({16'd0,cfg_burst_sample_count},write_data,write_strb);
                    ADDR_CONTROL: begin
                        config_pending <= (config_pending & ~config_done) |
                                          accept_apply;
                        // A still-pending channel is busy: repeat APPLY leaves
                        // its in-flight word untouched. Firmware polls STATUS.
                        if (accept_apply[0]) config_pinc[0] <= pinc0;
                        if (accept_apply[1]) config_pinc[1] <= pinc1;
                        if (accept_apply[2]) config_pinc[2] <= pinc2;
                        if (accept_apply[3]) config_pinc[3] <= pinc3;
                        if (accept_apply[4]) config_pinc[4] <= pinc4;
                        if (accept_apply[5]) config_pinc[5] <= pinc5;
                    end
                    ADDR_PINC0: pinc0 <= apply_wstrb(pinc0, write_data, write_strb);
                    ADDR_PINC1: pinc1 <= apply_wstrb(pinc1, write_data, write_strb);
                    ADDR_PINC2: pinc2 <= apply_wstrb(pinc2, write_data, write_strb);
                    ADDR_PINC3: pinc3 <= apply_wstrb(pinc3, write_data, write_strb);
                    ADDR_PINC4: pinc4 <= apply_wstrb(pinc4, write_data, write_strb);
                    ADDR_PINC5: pinc5 <= apply_wstrb(pinc5, write_data, write_strb);
                    ADDR_THRESHOLD_LO: begin
                        power_threshold[31:0] <= apply_wstrb(power_threshold[31:0], write_data, write_strb);
                    end
                    ADDR_THRESHOLD_HI: begin
                        if (write_strb[0]) begin
                            power_threshold[32] <= write_data[0];
                        end
                    end
                    ADDR_DMA_CONTROL: begin
                        if (write_strb[0]) begin
                            dma_capture_enable <= write_data[0];
                            dma_capture_summary_enable <= write_data[1];
                            dma_capture_cic_enable <= write_data[2];
                            dma_capture_psd_input_enable <= write_data[3];
                            capture_flush <= write_data[4];
                        end
                    end
                    ADDR_DMA_PACKET_RECORD_COUNT: begin
                        if (write_strb[0]) begin
                            dma_packet_record_count[7:0] <= write_data[7:0];
                        end
                        if (write_strb[1]) begin
                            dma_packet_record_count[15:8] <= write_data[15:8];
                        end
                    end
                    ADDR_DMA_CIC_SAMPLE_INTERVAL: begin
                        if (write_strb[0]) begin
                            dma_cic_sample_interval[7:0] <= write_data[7:0];
                        end
                        if (write_strb[1]) begin
                            dma_cic_sample_interval[15:8] <= write_data[15:8];
                        end
                    end
                    ADDR_DMA_PSD_INPUT_SAMPLE_INTERVAL: begin
                        if (write_strb[0]) begin
                            dma_psd_input_sample_interval[7:0] <= write_data[7:0];
                        end
                        if (write_strb[1]) begin
                            dma_psd_input_sample_interval[15:8] <= write_data[15:8];
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            axi_araddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            s_axi_rdata   <= {C_S_AXI_DATA_WIDTH{1'b0}};
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
        end else begin
            if (ar_fire) begin
                s_axi_arready <= 1'b0;
                axi_araddr    <= s_axi_araddr;
                s_axi_rdata   <= read_register(s_axi_araddr);
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                s_axi_arready <= 1'b1;
            end else if (!s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

endmodule
