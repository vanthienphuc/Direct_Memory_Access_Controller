
module dma_axi_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH_LOG2 = 2
) (
    input  wire                  clk,
    input  wire                  rst_n,

    // Write interface: AXI Read Master
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,

    // Read interface: AXI Write Master
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    localparam DEPTH = 1 << DEPTH_LOG2;

    // FIFO memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Read and write pointers
    reg [DEPTH_LOG2-1:0] wr_ptr;
    reg [DEPTH_LOG2-1:0] rd_ptr;

    // Number of stored words
    reg [DEPTH_LOG2:0] count;

    // Accepted read/write operations
    wire do_write;
    wire do_read;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    // Write data into FIFO memory
    always @(posedge clk) begin
        if (do_write) begin
            mem[wr_ptr] <= wr_data;
        end
    end

    // Update pointers and occupancy counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {DEPTH_LOG2{1'b0}};
            rd_ptr <= {DEPTH_LOG2{1'b0}};
            count  <= {(DEPTH_LOG2+1){1'b0}};
        end
        else begin
            if (do_write) begin
                wr_ptr <= wr_ptr + 1'b1;
            end

            if (do_read) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

    // FWFT: expose the current head word
    assign rd_data = empty ? {DATA_WIDTH{1'b0}} : mem[rd_ptr];

endmodule


