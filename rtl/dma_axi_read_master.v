
module dma_axi_read_master (
    input  wire        clk,
    input  wire        rst_n,

    // Control Interface
    input  wire        start_read,
    input  wire [31:0] src_addr,
    input  wire [15:0] total_bytes,
    output reg         read_done,

    // FIFO Interface
    input  wire        fifo_full,
    output reg         fifo_wr_en,
    output reg  [31:0] fifo_wr_data,

    // AXI4-Lite Read Interface
    // Read Address Channel (AR)
    output reg  [31:0] axi_araddr,
    output reg         axi_arvalid,
    input  wire        axi_arready,

    // Read Data Channel (R)
    input  wire [31:0] axi_rdata,
    input  wire [1:0]  axi_rresp,    // Error response (00 means OK)
    input  wire        axi_rvalid,
    output wire        axi_rready    
);

    localparam IDLE      = 2'b00,
               AR_PHASE  = 2'b01,  // Send read address
               R_PHASE   = 2'b10,  // Wait for read data
               DONE      = 2'b11;  // Operation completed

    reg [1:0] state;

    // Internal registers to track progress
    reg [31:0] current_addr;
    reg [15:0] bytes_read;

    // The master is ready to receive data only when it is in the R_PHASE
    // state AND the FIFO is not full
    assign axi_rready = (state == R_PHASE) && (!fifo_full);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_araddr   <= 32'd0;
            axi_arvalid  <= 1'b0;
            fifo_wr_en   <= 1'b0;
            fifo_wr_data <= 32'd0;
            read_done    <= 1'b0;

            current_addr <= 32'd0;
            bytes_read   <= 16'd0;
            state        <= IDLE;
        end
        else begin
            // Clear the FIFO write enable by default so data is written
            // for only one cycle when a valid transfer occurs
            fifo_wr_en <= 1'b0;
            read_done  <= 1'b0;

            case (state)
                // -------------------------------------------------
                // IDLE
                // -------------------------------------------------
                IDLE: begin
                    if (start_read && (total_bytes > 0)) begin
                        current_addr <= src_addr;
                        bytes_read   <= 16'd0;

                        // Schedule the AR phase
                        axi_araddr   <= src_addr;
                        axi_arvalid  <= 1'b1;
                        state        <= AR_PHASE;
                    end
                end

                // -------------------------------------------------
                // Read Address
                // -------------------------------------------------
                AR_PHASE: begin
                    // Wait for RAM to assert ARREADY to complete the handshake
                    if (axi_arvalid && axi_arready) begin
                        axi_arvalid <= 1'b0; // Deassert the Valid signal
                        state       <= R_PHASE;
                    end
                end

                // -------------------------------------------------
                // Read Data
                // -------------------------------------------------
                R_PHASE: begin
                    // A successful handshake occurs when both RVALID and RREADY are 1
                    if (axi_rvalid && axi_rready) begin
                        // Write the received data to the FIFO
                        fifo_wr_data <= axi_rdata;
                        fifo_wr_en   <= 1'b1;

                        // Update progress (each 32-bit transfer equals 4 bytes)
                        bytes_read   <= bytes_read + 16'd4;
                        current_addr <= current_addr + 32'd4;

                        // Check whether all requested bytes have been read
                        if ((bytes_read + 16'd4) >= total_bytes) begin
                            state <= DONE;
                        end else begin
                            // More data remains: return to the AR phase
                            // to read from the next address
                            axi_araddr  <= current_addr + 32'd4;
                            axi_arvalid <= 1'b1;
                            state       <= AR_PHASE;
                        end
                    end
                end

                // -------------------------------------------------
                // Done
                // -------------------------------------------------
                DONE: begin
                    read_done <= 1'b1; 
                    state     <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

