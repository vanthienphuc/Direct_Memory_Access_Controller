module dma_top (
    input  wire        clk,
    input  wire        rst_n,

    // APB Interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,

    // AXI4-Lite Write Address Channel (AW)
    output wire        axi_awvalid,
    output wire [31:0] axi_awaddr,
    input  wire        axi_awready,

    // AXI4-Lite Write Data Channel (W)
    output wire        axi_wvalid,
    output wire [31:0] axi_wdata,
    output wire [3:0]  axi_wstrb,
    input  wire        axi_wready,

    // AXI4-Lite Write Response Channel (B)
    input  wire [1:0]  axi_bresp,
    input  wire        axi_bvalid,
    output wire        axi_bready,

    // AXI4-Lite Read Address Channel (AR)
    output wire        axi_arvalid,
    output wire [31:0] axi_araddr,
    input  wire        axi_arready,

    // AXI4-Lite Read Data Channel (R)
    input  wire [31:0] axi_rdata,
    input  wire [1:0]  axi_rresp,
    input  wire        axi_rvalid,
    output wire        axi_rready
);

    // APB CSR -> DMA Main Engine
    wire        start_req;
    wire [31:0] src_addr_csr;
    wire [31:0] dst_addr_csr;
    wire [15:0] transfer_size_csr;

    // DMA Main Engine -> APB CSR
    wire        dma_busy;
    wire        dma_done;

    // DMA Main Engine -> AXI Masters
    // Read Master control
    wire        start_read;
    wire [31:0] src_addr_read;
    wire [15:0] total_bytes_read;
    wire        read_done;

    // Write Master control
    wire        start_write;
    wire [31:0] dst_addr_write;
    wire [15:0] total_bytes_write;
    wire        write_done;

    // Read Master -> FIFO
    wire                  fifo_full;
    wire                  fifo_wr_en;
    wire [31:0]           fifo_wr_data;

    // FIFO -> Write Master
    wire                  fifo_empty;
    wire                  fifo_rd_en;
    wire [31:0]           fifo_rd_data;

    // -------------------------------------------------
    // APB Slave CSR
    // -------------------------------------------------

    dma_apb_slave_csr u_apb_slave_csr (
        .clk(clk),
        .rst_n(rst_n),

        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),

        .dma_busy(dma_busy),
        .dma_done(dma_done),

        .start_req(start_req),
        .src_addr_csr(src_addr_csr),
        .dst_addr_csr(dst_addr_csr),
        .transfer_size_csr(transfer_size_csr)
    );

    // -------------------------------------------------
    // DMA Main Engine
    // -------------------------------------------------

    dma_main_engine u_main_engine (
        .clk(clk),
        .rst_n(rst_n),

        // APB CSR interface
        .start_req(start_req),
        .src_addr_csr(src_addr_csr),
        .dst_addr_csr(dst_addr_csr),
        .transfer_size_csr(transfer_size_csr),

        .dma_busy(dma_busy),
        .dma_done(dma_done),

        // AXI Read Master control
        .start_read(start_read),
        .src_addr_read(src_addr_read),
        .total_bytes_read(total_bytes_read),
        .read_done(read_done),

        // AXI Write Master control
        .start_write(start_write),
        .dst_addr_write(dst_addr_write),
        .total_bytes_write(total_bytes_write),
        .write_done(write_done)
    );

    // -------------------------------------------------
    // AXI4-Lite Read Master
    // -------------------------------------------------

    dma_axi_read_master u_axi_read_master (
        .clk(clk),
        .rst_n(rst_n),

        // Main Engine interface
        .start_read(start_read),
        .src_addr(src_addr_read),
        .total_bytes(total_bytes_read),
        .read_done(read_done),

        // FIFO interface
        .fifo_full(fifo_full),
        .fifo_wr_en(fifo_wr_en),
        .fifo_wr_data(fifo_wr_data),

        // AXI AR
        .axi_araddr(axi_araddr),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),

        // AXI R
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready)
    );

    // -------------------------------------------------
    // AXI4-Lite Write Master
    // -------------------------------------------------

    dma_axi_write_master u_axi_write_master (
        .clk(clk),
        .rst_n(rst_n),

        // Main Engine interface
        .start_write(start_write),
        .dst_addr(dst_addr_write),
        .total_bytes(total_bytes_write),
        .write_done(write_done),

        // FIFO interface
        .fifo_empty(fifo_empty),
        .fifo_rd_en(fifo_rd_en),
        .fifo_rd_data(fifo_rd_data),

        // AXI AW
        .axi_awaddr(axi_awaddr),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),

        // AXI W
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),

        // AXI B
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready)
    );

    // -------------------------------------------------
    // DMA AXI FIFO
    // -------------------------------------------------

    dma_axi_fifo #(
        .DATA_WIDTH(32),
        .DEPTH_LOG2(2)
    ) u_dma_axi_fifo (
        .clk(clk),
        .rst_n(rst_n),

        // Write interface: AXI Read Master
        .wr_en(fifo_wr_en),
        .wr_data(fifo_wr_data),
        .full(fifo_full),

        // Read interface: AXI Write Master
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        .empty(fifo_empty)
    );

endmodule

