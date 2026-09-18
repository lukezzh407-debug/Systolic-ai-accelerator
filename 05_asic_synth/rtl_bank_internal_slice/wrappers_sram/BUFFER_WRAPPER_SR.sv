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
    // bank级切片：不同bank所属寄存器组的下标位宽
    localparam BANK_IDX_W     = $clog2(ARRAY_SIZE);  //有多少个bank
    // bank内切片：每个逻辑 bank 再切成 N_SLICE 片。MATRIX_SIZE=32、ARRAY_SIZE=4 时
    // BANK_DEPTH=256 → 4×64，写数据扇出从 1→256 变为 1→4（片寄存器）再 1→64。
    // 写寄存器下到片级，仍只多 1 拍，不在 bank 级寄存器后再叠一拍。
    localparam N_SLICE        = 4;
    localparam SLICE_DEPTH    = BANK_DEPTH / N_SLICE;  //单片slice的深度
    localparam SLICE_AW       = $clog2(SLICE_DEPTH);  //每个slice里的第几行
    localparam SLICE_IDX_W    = $clog2(N_SLICE); //第几个slice
    // 要求 BANK_DEPTH 能被 N_SLICE 整除，否则高低位切分会对不齐
    if (BANK_DEPTH % N_SLICE != 0)
        $error("BUFFER_WRAPPER_SR: BANK_DEPTH must be divisible by N_SLICE");

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
    wire [ADDR_WIDTH-1:0] act_wr_addr_val = (act_global_row / ARRAY_SIZE) * SRAM_DEPTH + act_global_col;  //当前元素在当前sram bank的第几行
    // 第一层切片：用写计数器算出的 bank 号作为写寄存器下标
    wire [BANK_IDX_W-1:0] act_bank = act_target_bank[BANK_IDX_W-1:0];
    // 第二层切片：逻辑地址高位选片、低位为片内地址
    // 对一个0~255地址切片，可提取其最高两位作为片选信号，将其切成4份。
    wire [SLICE_IDX_W-1:0] act_wr_slice      = act_wr_addr_val[ADDR_WIDTH-1 -: SLICE_IDX_W];
    wire [SLICE_AW-1:0]    act_wr_slice_addr = act_wr_addr_val[SLICE_AW-1:0];

    wire [5:0] wei_global_row  = wr_cnt_wei / SRAM_DEPTH;
    wire [5:0] wei_global_col  = wr_cnt_wei % SRAM_DEPTH;
    wire [5:0] wei_target_bank = wei_global_row % ARRAY_SIZE; 
    wire [ADDR_WIDTH-1:0] wei_wr_addr_val = (wei_global_row / ARRAY_SIZE) * SRAM_DEPTH + wei_global_col;
    wire [BANK_IDX_W-1:0] wei_bank = wei_target_bank[BANK_IDX_W-1:0];
    // [EDIT]
    wire [SLICE_IDX_W-1:0] wei_wr_slice      = wei_wr_addr_val[ADDR_WIDTH-1 -: SLICE_IDX_W];
    wire [SLICE_AW-1:0]    wei_wr_slice_addr = wei_wr_addr_val[SLICE_AW-1:0];
    
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
        if (pslverr) pready = 1'b1;  //疑惑点：拉高不会把错误的写或读操作执行吗？但不拉高的话又如何让cpu废除当前指令而不是一直卡在等待执行？
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
                // every compute enable, give it a base address 每次计算都要更新当前读取的sram块的基地址
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

    // [EDIT] 写寄存器下到「bank × slice」。仍只多 1 拍：
    // unpacker → *_q[bank][slice] → 该片 64 深 RAM。
    // 4个bank,每个里4个切片: [0:bank数][0:片数]
    logic [MATRIX_DW-1:0]  act_wdata_q [0:ARRAY_SIZE-1][0:N_SLICE-1]; //16个数据寄存器
    logic [SLICE_AW-1:0]   act_waddr_q [0:ARRAY_SIZE-1][0:N_SLICE-1]; //16个片内地址寄存器
    logic                  act_wren_q  [0:ARRAY_SIZE-1][0:N_SLICE-1]; //16个写使能
    logic [MATRIX_DW-1:0]  wei_wdata_q [0:ARRAY_SIZE-1][0:N_SLICE-1];
    logic [SLICE_AW-1:0]   wei_waddr_q [0:ARRAY_SIZE-1][0:N_SLICE-1];
    logic                  wei_wren_q  [0:ARRAY_SIZE-1][0:N_SLICE-1];
    logic [MATRIX_DW-1:0]  act_slice_rdata [0:ARRAY_SIZE-1][0:N_SLICE-1]; //16个读数据寄存器
    logic [MATRIX_DW-1:0]  wei_slice_rdata [0:ARRAY_SIZE-1][0:N_SLICE-1];
    // sram.sv 读口已经晚 1 拍，片选择也要延迟 1 拍再 mux
    logic [SLICE_IDX_W-1:0] act_rd_slice_q [0:ARRAY_SIZE-1];
    logic [SLICE_IDX_W-1:0] wei_rd_slice_q [0:ARRAY_SIZE-1];

    integer b, sl;
    always_ff @(posedge pclk or negedge prst_n) begin
        if (!prst_n) begin
            for (b = 0; b < ARRAY_SIZE; b++) begin
                for (sl = 0; sl < N_SLICE; sl++) begin
                    act_wren_q[b][sl] <= 1'b0;
                    wei_wren_q[b][sl] <= 1'b0;
                end
            end
        end else begin
            for (b = 0; b < ARRAY_SIZE; b++) begin  //写之前要先把使能信号清零，防止上一拍的数据继续写
                for (sl = 0; sl < N_SLICE; sl++) begin
                    act_wren_q[b][sl] <= 1'b0;
                    wei_wren_q[b][sl] <= 1'b0;
                end
            end

            if (do_act_write) begin  //16个sram片的写寄存器组
                act_wdata_q[act_bank][act_wr_slice] <= current_unpack_data;
                act_waddr_q[act_bank][act_wr_slice] <= act_wr_slice_addr;
                act_wren_q [act_bank][act_wr_slice] <= 1'b1;
            end
            if (do_wei_write) begin
                wei_wdata_q[wei_bank][wei_wr_slice] <= current_unpack_data;
                wei_waddr_q[wei_bank][wei_wr_slice] <= wei_wr_slice_addr;
                wei_wren_q [wei_bank][wei_wr_slice] <= 1'b1;
            end
        end
    end

    // Global SRAM Instantiation：每个逻辑 bank 拆成 N_SLICE 个 SLICE_DEPTH 深的物理阵列
    genvar i, s;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin : sram_inst_block
            wire [SLICE_IDX_W-1:0] act_rd_slice = act_rd_addr[i][ADDR_WIDTH-1 -: SLICE_IDX_W]; //当前第i个bank的地址的高2位(片选信号)
            wire [SLICE_AW-1:0]    act_rd_slice_addr = act_rd_addr[i][SLICE_AW-1:0];  //片内地址
            wire [SLICE_IDX_W-1:0] wei_rd_slice = wei_rd_addr[i][ADDR_WIDTH-1 -: SLICE_IDX_W];
            wire [SLICE_AW-1:0]    wei_rd_slice_addr = wei_rd_addr[i][SLICE_AW-1:0];

            always_ff @(posedge pclk or negedge prst_n) begin
                if (!prst_n) begin
                    act_rd_slice_q[i] <= '0;
                    wei_rd_slice_q[i] <= '0;
                end else begin  //读某bank的时候要将当前片选信号打一拍，来和sram的读时序匹配。
                    if (ctrl_act_fifoen[i]) act_rd_slice_q[i] <= act_rd_slice;
                    if (ctrl_wei_fifoen[i]) wei_rd_slice_q[i] <= wei_rd_slice;
                end
            end

            for (s = 0; s < N_SLICE; s = s + 1) begin : act_slice
                simple_dualport_ram #(
                    .ADDR_WIDTH (SLICE_AW),
                    .DATA_WIDTH (MATRIX_DW),
                    .DATA_DEPTH (SLICE_DEPTH)
                ) u_act_sram (
                    .clk      (pclk),
                    .rst_n    (prst_n),
                    .sel      (1'b1),
                    .rd_addr  (act_rd_slice_addr),
                    .rden     (ctrl_act_fifoen[i] && (act_rd_slice == s[SLICE_IDX_W-1:0])),
                    .rd_data  (act_slice_rdata[i][s]),
                    .wr_addr  (act_waddr_q[i][s]),  //0-63
                    .wren     (act_wren_q[i][s]),  
                    .wr_data  (act_wdata_q[i][s])
                );
            end

            for (s = 0; s < N_SLICE; s = s + 1) begin : wei_slice
                simple_dualport_ram #(
                    .ADDR_WIDTH (SLICE_AW),
                    .DATA_WIDTH (MATRIX_DW),
                    .DATA_DEPTH (SLICE_DEPTH)
                ) u_wei_sram (
                    .clk      (pclk),
                    .rst_n    (prst_n),
                    .sel      (1'b1),
                    .rd_addr  (wei_rd_slice_addr),
                    .rden     (ctrl_wei_fifoen[i] && (wei_rd_slice == s[SLICE_IDX_W-1:0])),
                    .rd_data  (wei_slice_rdata[i][s]),
                    .wr_addr  (wei_waddr_q[i][s]),
                    .wren     (wei_wren_q[i][s]),
                    .wr_data  (wei_wdata_q[i][s])
                );
            end

            assign matrix_act_din[i*MATRIX_DW +: MATRIX_DW] = act_slice_rdata[i][act_rd_slice_q[i]]; //组合逻辑输出，直接连接4*32根线，每根线会mux到同一bank的不同slice上。
            assign matrix_wei_din[i*MATRIX_DW +: MATRIX_DW] = wei_slice_rdata[i][wei_rd_slice_q[i]];
        end
    endgenerate

endmodule