
module dma_axi_write_master (
    input  wire        clk,
    input  wire        rst_n,

    // Control Interface
    input  wire        start_write,
    input  wire [31:0] dst_addr,
    input  wire [15:0] total_bytes,
    output reg         write_done,

    // FIFO Interface
    input  wire        fifo_empty,
    output reg         fifo_rd_en,
    input  wire [31:0] fifo_rd_data,

    // AXI4 Write Interface
    // Write Address Channel (AW)
    output reg  [31:0] axi_awaddr,
    output reg         axi_awvalid,
    input  wire        axi_awready,

    // Write Data Channel (W)
    output reg  [31:0] axi_wdata,
    output wire [3:0]  axi_wstrb,
    output reg         axi_wvalid,
    input  wire        axi_wready,

    // Write Response Channel (B)
    input  wire [1:0]  axi_bresp,    // Write response status (00 means OK)
    input  wire        axi_bvalid,
    output wire        axi_bready
);

    // Enable all byte lanes (full 32-bit write = 4 bytes per transfer)
    assign axi_wstrb = 4'b1111;

    // The master is always ready to receive a response from RAM
    assign axi_bready = 1'b1;

    localparam IDLE         = 3'd0,
               WAIT_FIFO    = 3'd1, // Wait for data in the FIFO
               WRITE_PHASE  = 3'd2, // Issue AW and W simultaneously
               RESP_PHASE   = 3'd3, // Wait for BVALID
               DONE         = 3'd4; // Operation completed

    reg [2:0] state;

    reg [31:0] current_addr;
    reg [15:0] bytes_written;

    // Independent handshake tracking flags
    reg aw_accepted;
    reg w_accepted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_awaddr    <= 32'd0;
            axi_awvalid   <= 1'b0;
            axi_wdata     <= 32'd0;
            axi_wvalid    <= 1'b0;
            write_done    <= 1'b0;
            fifo_rd_en    <= 1'b0;

            current_addr  <= 32'd0;
            bytes_written <= 16'd0;
            aw_accepted   <= 1'b0;
            w_accepted    <= 1'b0;
            state         <= IDLE;
        end
        else begin
            // Deassert pulse signals by default
            fifo_rd_en <= 1'b0;
            write_done <= 1'b0;

            case (state)
                // -------------------------------------------------
                // Wait for a command from the Main Engine
                // -------------------------------------------------
                IDLE: begin
                    if (start_write && (total_bytes > 0)) begin
                        current_addr  <= dst_addr;
                        bytes_written <= 16'd0;
                        state         <= WAIT_FIFO;
                    end
                end

                // -------------------------------------------------
                // Wait for data in the FIFO
                // -------------------------------------------------
                WAIT_FIFO: begin
                    // If the FIFO is not empty, data is already available
                    // on fifo_rd_data (FWFT)
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1'b1; // Enable reading data from the FIFO

                        // Load the address and data onto the AXI buses
                        axi_awaddr  <= current_addr;
                        axi_awvalid <= 1'b1;

                        axi_wdata   <= fifo_rd_data;
                        axi_wvalid  <= 1'b1;

                        // Clear the handshake acknowledgment flags
                        aw_accepted <= 1'b0;
                        w_accepted  <= 1'b0;

                        state <= WRITE_PHASE;
                    end
                end

                // -------------------------------------------------
                // Write Phase (Issue AW and W simultaneously)
                // -------------------------------------------------
                WRITE_PHASE: begin
                    // Track the AW channel handshake
                    if (axi_awvalid && axi_awready) begin
                        axi_awvalid <= 1'b0; // RAM has accepted the address, deassert VALID
                        aw_accepted <= 1'b1;
                    end

                    // Track the W channel handshake
                    if (axi_wvalid && axi_wready) begin
                        axi_wvalid <= 1'b0; // RAM has accepted the data; deassert VALID
                        w_accepted <= 1'b1;
                    end

                    // Check whether Both channels have completed their handshakes
                    if ((aw_accepted || (axi_awvalid && axi_awready)) &&
                        (w_accepted  || (axi_wvalid  && axi_wready))) begin
                        state <= RESP_PHASE;
                    end
                end

                // -------------------------------------------------
                // Wait for Write Response
                // -------------------------------------------------
                RESP_PHASE: begin
                    // Wait for RAM to assert BVALID
                    if (axi_bvalid && axi_bready) begin
                        // Update progress
                        bytes_written <= bytes_written + 16'd4;
                        current_addr  <= current_addr + 32'd4;

                        // Check the total transfer progress
                        if ((bytes_written + 16'd4) >= total_bytes) begin
                            state <= DONE; // All data has been written
                        end else begin
                            state <= WAIT_FIFO; // Wait for the next data word
                        end
                    end
                end

                // -------------------------------------------------
                // Completion
                // -------------------------------------------------
                DONE: begin
                    write_done <= 1'b1; // Generate a one cycle pulse to notify the Main Engine
                    state      <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

