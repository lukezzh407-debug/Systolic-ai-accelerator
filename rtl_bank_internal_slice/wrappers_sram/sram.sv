module simple_dualport_ram #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 1 << ADDR_WIDTH 
)(    
    input  logic                  clk,
    input  logic                  rst_n, 
    input  logic                  sel,  
    // Read Port
    input  logic [ADDR_WIDTH-1:0] rd_addr, 
    input  logic                  rden, 
    output logic [DATA_WIDTH-1:0] rd_data,   
    // Write Port
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic                  wren,
    input  logic [DATA_WIDTH-1:0] wr_data
);

    logic [DATA_WIDTH-1:0] ram [0:DATA_DEPTH-1];

    always_ff @(posedge clk) begin
        if (wren && sel) begin     
            ram[wr_addr] <= wr_data;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data <= '0; 
        end
        else if (rden && sel) begin
            rd_data <= ram[rd_addr];
        end
    end

endmodule