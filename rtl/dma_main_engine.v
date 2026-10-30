module dma_main_engine (
    input  wire        clk,
    input  wire        rst_n,

    // APB CSR Interface (Receive Commands and Report Status)
    input  wire        start_req,
    input  wire [31:0] src_addr_csr,      // Register 0x08
    input  wire [31:0] dst_addr_csr,      // Register 0x0C
    input  wire [15:0] transfer_size_csr, // Register 0x00 (Bits 31:16)

    output reg         dma_busy,          // Status register 0x04 (Bit 0)
    output reg         dma_done,          // Status register 0x04 (Bit 1)

    // AXI4-Lite Read Master Interface
    output reg         start_read,
    output reg  [31:0] src_addr_read,
    output reg  [15:0] total_bytes_read,
    input  wire        read_done,

    // AXI4-Lite Write Master Interface
    output reg         start_write,
    output reg  [31:0] dst_addr_write,
    output reg  [15:0] total_bytes_write,
    input  wire        write_done
);

    localparam IDLE      = 2'b00,
               RUNNING   = 2'b01,
               COMPLETED = 2'b10;

    reg [1:0] state;

    // Internal flags
    reg read_completed;
    reg write_completed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= IDLE;
            dma_busy          <= 1'b0;
            dma_done          <= 1'b0;

            start_read        <= 1'b0;
            start_write       <= 1'b0;
            src_addr_read     <= 32'd0;
            dst_addr_write    <= 32'd0;
            total_bytes_read  <= 16'd0;
            total_bytes_write <= 16'd0;

            read_completed    <= 1'b0;
            write_completed   <= 1'b0;
        end
        else begin
            // Clear the start pulses after one cycle to prevent the AXI
            // modules from getting stuck.
            start_read  <= 1'b0;
            start_write <= 1'b0;

            case (state)
                // -------------------------------------------------
                // Idle and Wait for a New Command
                // -------------------------------------------------
                IDLE, COMPLETED: begin
                    // Wait for the start_req pulse from the APB Slave
                    if (start_req) begin
                        // Update the status register according to the specification
                        dma_busy <= 1'b1; // Indicate that the DMA is running
                        dma_done <= 1'b0; // Clear the done flag when a new command starts

                        // Distribute configuration parameters to the AXI modules
                        src_addr_read     <= src_addr_csr;
                        total_bytes_read  <= transfer_size_csr;

                        dst_addr_write    <= dst_addr_csr;
                        total_bytes_write <= transfer_size_csr;

                        // Start both channels simultaneously
                        start_read        <= 1'b1;
                        start_write       <= 1'b1;

                        // Clear the progress tracking flags
                        read_completed    <= 1'b0;
                        write_completed   <= 1'b0;

                        state <= RUNNING;
                    end
                end

                // -------------------------------------------------
                // Running State (Overlapping Read and Write Operations)
                // -------------------------------------------------
                RUNNING: begin
                    // Capture the done flags from the AXI modules
                    if (read_done)  read_completed  <= 1'b1;
                    if (write_done) write_completed <= 1'b1;

                    // Wait until both the read and write channels are complete
                    if ((read_completed || read_done) && (write_completed || write_done)) begin
                        // Update the status register
                        dma_busy <= 1'b0; // Clear the busy flag when the transfer completes
                        dma_done <= 1'b1; // Set the done flag to notify the CPU
                        state    <= COMPLETED;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
