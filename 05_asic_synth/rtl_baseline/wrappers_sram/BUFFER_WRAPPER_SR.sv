`timescale 1ns / 1ps

module BUFFER_WRAPPER_SR #(
    parameter SRAM_DEPTH = 32, // Global Matrix Dimension
    parameter ARRAY_SIZE = 16, // Size of SA
    parameter MATRIX_DW  = 32,
    parameter SUM_DW     = 32,
    parameter APB_AW     = 10,
    parameter APB_DW     = 32
)(
    input  logic        pclk,
    input  logic        prst_n,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [APB_AW-1:0] paddr,
    input  logic [APB_DW-1:0] pwr_data,
    output logic        pready,
    output logic        pslverr,
    output logic [APB_DW-1:0] prd_data,

    input  logic [ARRAY_SIZE-1:0] ctrl_act_fifoen, 
    input  logic [ARRAY_SIZE-1:0] ctrl_wei_fifoen, 
 
    output logic [ARRAY_SIZE*MATRIX_DW-1:0] matrix_act_din,
    output logic [ARRAY_SIZE*MATRIX_DW-1:0] matrix_wei_din,   
    input  logic [SUM_DW-1:0]               matrix_c_dout,
    input  logic                            matrix_c_valid,
    output logic                            sa_out_rd_en,

    output logic compute_en,
    input  logic sa_done,
    output logic [5:0] array_size,
    output logic [1:0] matrix_dw,
    output logic [1:0] sum_dw
);  
    //以8*8tile为例
    localparam TOTAL_ELEMENTS = SRAM_DEPTH * SRAM_DEPTH;  //1024          
    localparam BANK_DEPTH     = TOTAL_ELEMENTS / ARRAY_SIZE;    //128   
    localparam CNT_WIDTH      = $clog2(TOTAL_ELEMENTS);            
    localparam ADDR_WIDTH     = $clog2(BANK_DEPTH);                
    localparam TILES_PER_DIM  = SRAM_DEPTH / ARRAY_SIZE;  // 4

    // Address decoders
    logic sel_act;  assign sel_act  = (paddr == 32'h0000); 
    logic sel_wei;  assign sel_wei  = (paddr == 32'h0004); 
    logic sel_out;  assign sel_out  = (paddr == 32'h0008); 
    logic sel_ctrl; assign sel_ctrl = (paddr == 32'h000C); 
    logic sel_bias; assign sel_bias = (paddr == 32'h0010);

    logic apb_write_valid; assign apb_write_valid = psel & penable &  pwrite;
    logic apb_read_valid;  assign apb_read_valid  = psel & penable & ~pwrite;

    logic [11:0] config_reg; 
    always_ff @(posedge pclk or negedge prst_n) begin
        if(!prst_n) begin
            config_reg <= 'b0;
        end
        else begin
            config_reg[0] <= 1'b0; // pulse
            
            if (sa_done) config_reg[11] <= 1'b1;

            if (apb_write_valid && pready && !pslverr && sel_ctrl) begin
                config_reg[0]    <= pwr_data[0];    // compute enable
                config_reg[2:1]  <= pwr_data[2:1];  // matrix dw
                config_reg[4:3]  <= pwr_data[4:3];  // sum dw
                config_reg[10:5] <= pwr_data[10:5]; // array size
                if (pwr_data[11] == 1'b1) config_reg[11] <= 1'b0; // RW1C
            end
        end
    end
    assign compute_en = config_reg[0]; 
    assign matrix_dw  = config_reg[2:1];
    assign sum_dw     = config_reg[4:3];
    assign array_size = config_reg[10:5];

    //Data unpack
    logic [31:0] current_unpack_data;
    logic        unpack_ready;

    DATA_UNPACKER #(
        .APB_DW(APB_DW)
    ) u_data_unpacker (
        .pclk               (pclk),
        .prst_n             (prst_n),
        .matrix_dw          (matrix_dw),
        .pwr_data           (pwr_data),
        .apb_write_valid    (apb_write_valid),
        .sel_act            (sel_act),
        .sel_wei            (sel_wei),
        .pslverr            (pslverr),
        .psel               (psel),
        .current_unpack_data(current_unpack_data),
        .unpack_ready       (unpack_ready)
    );

    // writing logic
    logic [CNT_WIDTH-1:0] wr_cnt_act;
    logic [CNT_WIDTH-1:0] wr_cnt_wei;
    logic [9:0]           rd_cnt_out;
    wire [5:0] act_global_row  = wr_cnt_act / SRAM_DEPTH;
    wire [5:0] act_global_col  = wr_cnt_act % SRAM_DEPTH;
    wire [5:0] act_target_bank = act_global_row % ARRAY_SIZE; 
    wire [ADDR_WIDTH-1:0] act_wr_addr_val = (act_global_row / ARRAY_SIZE) * SRAM_DEPTH + act_global_col;

    wire [5:0] wei_global_row  = wr_cnt_wei / SRAM_DEPTH;
    wire [5:0] wei_global_col  = wr_cnt_wei % SRAM_DEPTH;
    wire [5:0] wei_target_bank = wei_global_row % ARRAY_SIZE; 
    wire [ADDR_WIDTH-1:0] wei_wr_addr_val = (wei_global_row / ARRAY_SIZE) * SRAM_DEPTH + wei_global_col;
    
    //pslverr logic
    wire current_act_sram_full  = (wr_cnt_act >= TOTAL_ELEMENTS);
    wire current_wei_sram_full  = (wr_cnt_wei >= TOTAL_ELEMENTS); 
    wire current_out_read_empty = (rd_cnt_out >= ARRAY_SIZE * ARRAY_SIZE);

    always_comb begin
        pslverr = 1'b0;
        if(psel && penable) begin
            if (pwrite) begin
                if (sel_act && current_act_sram_full) pslverr = 1'b1;
                if (sel_wei && current_wei_sram_full) pslverr = 1'b1;
            end
            else begin
                if(sel_out && current_out_read_empty) pslverr = 1'b1;
            end
        end
    end
    
    // pready logic
    always_comb begin
        if (pslverr) pready = 1'b1; 
        else if ((sel_act || sel_wei) && pwrite) pready = unpack_ready; 
        else if (sel_out && !pwrite) pready = matrix_c_valid; 
        else pready = 1'b1; 
    end

    localparam TOTAL_TILES = (SRAM_DEPTH / ARRAY_SIZE) * (SRAM_DEPTH / ARRAY_SIZE);
    logic [7:0]           tile_cnt;
    logic [$clog2(SRAM_DEPTH)-1:0] wr_cnt_bias;
    logic [SUM_DW-1:0]    bias_reg [0:SRAM_DEPTH-1]; 
    logic [ADDR_WIDTH-1:0] act_rd_addr [0:ARRAY_SIZE-1];
    logic [ADDR_WIDTH-1:0] wei_rd_addr [0:ARRAY_SIZE-1]; 

    wire [7:0]  current_tile_row = tile_cnt / TILES_PER_DIM;
    wire [7:0]  current_tile_col = tile_cnt % TILES_PER_DIM;

    wire do_act_write = apb_write_valid && sel_act && ~pslverr;
    wire do_wei_write = apb_write_valid && sel_wei && ~pslverr;

    always_ff @(posedge pclk or negedge prst_n) begin
        if (!prst_n) begin
            wr_cnt_act  <= '0;
            wr_cnt_wei  <= '0;
            rd_cnt_out  <= '0;
            wr_cnt_bias <= '0;
            tile_cnt    <= '0;
            for(int i=0; i<ARRAY_SIZE; i++) begin
                act_rd_addr[i] <= '0;
                wei_rd_addr[i] <= '0;
            end
        end 
        else if (apb_write_valid && pready && !pslverr && sel_ctrl && pwr_data[0] == 1'b1) begin
            // received compute_en
            rd_cnt_out <= '0;
            
            for(int i=0; i<ARRAY_SIZE; i++) begin
                // every compute enable, give it a base address
                act_rd_addr[i] <= current_tile_row * SRAM_DEPTH; 
                wei_rd_addr[i] <= current_tile_col * SRAM_DEPTH;
            end
        end 
        else begin
            if (do_act_write) begin
            wr_cnt_act <= (wr_cnt_act == TOTAL_ELEMENTS) ? wr_cnt_act : wr_cnt_act + 1'b1;
            end
            if (do_wei_write) begin
                wr_cnt_wei <= (wr_cnt_wei == TOTAL_ELEMENTS) ? wr_cnt_wei : wr_cnt_wei + 1'b1;
            end
            if (apb_write_valid && pready && !pslverr && sel_bias) begin
                bias_reg[wr_cnt_bias] <= pwr_data;
                wr_cnt_bias <= wr_cnt_bias + 1'b1;
            end
            if (apb_read_valid && pready && sel_out) begin
                rd_cnt_out <= rd_cnt_out + 1'b1;
                if (rd_cnt_out == (ARRAY_SIZE * ARRAY_SIZE) - 1) begin
                    tile_cnt <= (tile_cnt == TOTAL_TILES - 1) ? 8'd0 : tile_cnt + 8'd1;
                end
            end

            for(int i=0; i<ARRAY_SIZE; i++) begin
                if (ctrl_act_fifoen[i]) act_rd_addr[i] <= act_rd_addr[i] + 1'b1;
                if (ctrl_wei_fifoen[i]) wei_rd_addr[i] <= wei_rd_addr[i] + 1'b1;
            end
        end
    end

    logic apb_read_valid_reg;
    always @(posedge pclk) begin
        apb_read_valid_reg <= apb_read_valid;
    end
    assign sa_out_rd_en = (apb_read_valid & ~apb_read_valid_reg) & sel_out;

    // APB Read Multiplexer & Bias Adder
    wire [4:0] current_col_idx  = (current_tile_col * ARRAY_SIZE) + (rd_cnt_out % ARRAY_SIZE); 

    always_comb begin
        if (!pwrite) begin
            if (sel_out) prd_data = matrix_c_dout + bias_reg[current_col_idx];
            else if (sel_ctrl) prd_data = {20'd0, config_reg}; 
            else prd_data = 32'h0000_0000;
        end 
        else prd_data = 32'h0000_0000;
    end

    // Global SRAM Instantiation 
    genvar i;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin : sram_inst_block
            
            wire act_wr_en = do_act_write && (act_target_bank == i);

            simple_dualport_ram #(
                .ADDR_WIDTH (ADDR_WIDTH),
                .DATA_WIDTH (MATRIX_DW),
                .DATA_DEPTH (BANK_DEPTH)
            ) u_act_sram (
                .clk      (pclk),
                .rst_n    (prst_n),
                .sel      (1'b1), 
                .rd_addr  (act_rd_addr[i]),
                .rden     (ctrl_act_fifoen[i]), 
                .rd_data  (matrix_act_din[i*MATRIX_DW +: MATRIX_DW]),
                .wr_addr  (act_wr_addr_val),
                .wren     (act_wr_en),
                .wr_data  (current_unpack_data)
            );

            wire wei_wr_en = do_wei_write && (wei_target_bank == i);

            simple_dualport_ram #(
                .ADDR_WIDTH (ADDR_WIDTH),
                .DATA_WIDTH (MATRIX_DW),
                .DATA_DEPTH (BANK_DEPTH)
            ) u_wei_sram (
                .clk      (pclk),
                .rst_n    (prst_n),
                .sel      (1'b1), 
                .rd_addr  (wei_rd_addr[i]),
                .rden     (ctrl_wei_fifoen[i]), 
                .rd_data  (matrix_wei_din[i*MATRIX_DW +: MATRIX_DW]),
                .wr_addr  (wei_wr_addr_val),
                .wren     (wei_wr_en),
                .wr_data  (current_unpack_data)
            );
        end
    endgenerate

endmodule