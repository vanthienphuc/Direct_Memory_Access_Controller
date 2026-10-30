
module dma_apb_slave_csr (
    input  wire        clk,
    input  wire        rst_n,

    // APB interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,

    // DMA status from Main Engine
    input  wire        dma_busy,
    input  wire        dma_done,

    output reg         start_req,
    output reg  [31:0] src_addr_csr,
    output reg  [31:0] dst_addr_csr,
    output reg  [15:0] transfer_size_csr
);

    // CSR addresses
    localparam ADDR_CTRL   = 8'h00;
    localparam ADDR_STATUS = 8'h04;
    localparam ADDR_SRC    = 8'h08;
    localparam ADDR_DST    = 8'h0C;

    // APB transfer completes in the ACCESS phase
    assign pready = 1'b1;

    wire apb_write;
    wire apb_read;

    assign apb_write = psel && penable && pwrite;
    assign apb_read  = psel && penable && !pwrite;

    // ---------------------------------------------------------
    // Write configuration registers
    // ---------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_req        <= 1'b0;
            src_addr_csr     <= 32'd0;
            dst_addr_csr     <= 32'd0;
            transfer_size_csr <= 16'd0;
        end
        else begin
            // Start request is a one-cycle pulse
            start_req <= 1'b0;

            if (apb_write) begin
                case (paddr)
                    ADDR_CTRL: begin
                        transfer_size_csr <= pwdata[31:16];

                        if (pwdata[0]) begin
                            start_req <= 1'b1;
                        end
                    end

                    ADDR_SRC: begin
                        src_addr_csr <= pwdata;
                    end

                    ADDR_DST: begin
                        dst_addr_csr <= pwdata;
                    end

                    default: begin
                        // Reserved or unmapped address
                    end
                endcase
            end
        end
    end

    // ---------------------------------------------------------
    // Read configuration and status registers
    // ---------------------------------------------------------
    always @(*) begin
        prdata = 32'd0;

        if (apb_read) begin
            case (paddr)
                ADDR_CTRL: begin
                    // Transfer size in bits [31:16]
                    // Start is a write-triggered pulse
                    prdata = {transfer_size_csr, 15'd0, 1'b0};
                end

                ADDR_STATUS: begin
                    prdata = {
                        30'd0,
                        dma_done,
                        dma_busy
                    };
                end

                ADDR_SRC: begin
                    prdata = src_addr_csr;
                end

                ADDR_DST: begin
                    prdata = dst_addr_csr;
                end

                default: begin
                    prdata = 32'd0;
                end
            endcase
        end
    end

endmodule


