// Software-side model shared by directed TB, UVM tests, and later C code.
// Golden GEMM: C[i,j] = sum_k A[i,k] * W[j,k] + bias[j]
// (same convention as origin_project verification, weight rows are not transposed).
package ai_acc_sw_model;

  typedef enum int {
    MODE_4BIT  = 0,
    MODE_8BIT  = 1,
    MODE_16BIT = 2,
    MODE_32BIT = 3
  } e_data_width;

  typedef struct {
    e_data_width act_dw;
    e_data_width wei_dw;
    e_data_width out_dw;
    string       name;
  } test_mode_t;

  // Same mode table as sw/main_ai_acc_sram/main_ai_acc_sram.c TEST_MODE_*.
  function automatic int num_c_modes();
    return 10;
  endfunction

  function automatic test_mode_t c_mode(int idx);
    test_mode_t m;
    case (idx)
      0: begin m.act_dw=MODE_32BIT; m.wei_dw=MODE_32BIT; m.out_dw=MODE_32BIT; m.name="mode0_32b_32b"; end
      1: begin m.act_dw=MODE_4BIT;  m.wei_dw=MODE_4BIT;  m.out_dw=MODE_32BIT; m.name="mode1_4b_4b";   end
      2: begin m.act_dw=MODE_8BIT;  m.wei_dw=MODE_8BIT;  m.out_dw=MODE_32BIT; m.name="mode2_8b_8b";   end
      3: begin m.act_dw=MODE_16BIT; m.wei_dw=MODE_16BIT; m.out_dw=MODE_32BIT; m.name="mode3_16b_16b"; end
      4: begin m.act_dw=MODE_4BIT;  m.wei_dw=MODE_32BIT; m.out_dw=MODE_32BIT; m.name="mode4_4b_32b";  end
      5: begin m.act_dw=MODE_8BIT;  m.wei_dw=MODE_32BIT; m.out_dw=MODE_32BIT; m.name="mode5_8b_32b";  end
      6: begin m.act_dw=MODE_8BIT;  m.wei_dw=MODE_4BIT;  m.out_dw=MODE_32BIT; m.name="mode6_8b_4b";   end
      7: begin m.act_dw=MODE_16BIT; m.wei_dw=MODE_32BIT; m.out_dw=MODE_32BIT; m.name="mode7_16b_32b"; end
      8: begin m.act_dw=MODE_16BIT; m.wei_dw=MODE_4BIT;  m.out_dw=MODE_32BIT; m.name="mode8_16b_4b";  end
      9: begin m.act_dw=MODE_16BIT; m.wei_dw=MODE_8BIT;  m.out_dw=MODE_32BIT; m.name="mode9_16b_8b";  end
      default: begin m.act_dw=MODE_32BIT; m.wei_dw=MODE_32BIT; m.out_dw=MODE_32BIT; m.name="mode0_32b_32b"; end
    endcase
    return m;
  endfunction

  function automatic int precision_bits(e_data_width dw);
    case (dw)
      MODE_4BIT:  return 4;
      MODE_8BIT:  return 8;
      MODE_16BIT: return 16;
      default:    return 31; // keep 32-bit products from overflowing SUM_DW
    endcase
  endfunction

  function automatic int elems_per_word(e_data_width dw);
    case (dw)
      MODE_4BIT:  return 8;
      MODE_8BIT:  return 4;
      MODE_16BIT: return 2;
      default:    return 1;
    endcase
  endfunction

  function automatic logic [31:0] pack_word(
      e_data_width dw,
      input logic signed [31:0] mat[],
      int idx
  );
    logic [31:0] data;
    data = '0;
    case (dw)
      MODE_4BIT: begin
        data[3:0]   = mat[idx];
        data[7:4]   = mat[idx+1];
        data[11:8]  = mat[idx+2];
        data[15:12] = mat[idx+3];
        data[19:16] = mat[idx+4];
        data[23:20] = mat[idx+5];
        data[27:24] = mat[idx+6];
        data[31:28] = mat[idx+7];
      end
      MODE_8BIT: begin
        data[7:0]   = mat[idx];
        data[15:8]  = mat[idx+1];
        data[23:16] = mat[idx+2];
        data[31:24] = mat[idx+3];
      end
      MODE_16BIT: begin
        data[15:0]  = mat[idx];
        data[31:16] = mat[idx+1];
      end
      default: data = mat[idx];
    endcase
    return data;
  endfunction

  function automatic logic [31:0] make_ctrl(
      int array_size,
      e_data_width in_dw,
      e_data_width out_dw,
      bit start,
      bit clear_done
  );
    logic [31:0] data;
    data = '0;
    data[0]     = start;
    data[2:1]   = in_dw;
    data[4:3]   = out_dw;
    data[10:5]  = array_size[5:0];
    data[11]    = clear_done;
    return data;
  endfunction

  // n is the matrix dimension (N x N). mat has n*n elements, row-major.
  function automatic void fill_pattern(
      string pattern,
      int n,
      int precision,
      ref logic signed [31:0] mat[]
  );
    int signed lo;
    int signed hi;
    int signed tmp;
    int row, col;
    lo = -(1 <<< (precision - 1));
    hi =  (1 <<< (precision - 1)) - 1;
    for (int i = 0; i < n * n; i++) begin
      row = i / n;
      col = i % n;
      case (pattern)
        "zeros":      tmp = 0;
        "ones":       tmp = 1;
        "sequential": tmp = (i % (hi + 1));
        "row-index":  tmp = row;
        "identity":   tmp = (row == col) ? 1 : 0;
        default: begin
          void'(std::randomize(tmp) with { tmp >= lo; tmp <= hi; });
        end
      endcase
      if (tmp < lo) tmp = lo;
      if (tmp > hi) tmp = hi;
      mat[i] = tmp;
    end
  endfunction

  function automatic void golden_gemm(
      int n,
      input logic signed [31:0] act[],
      input logic signed [31:0] wei[],
      input logic signed [31:0] bias[],
      output logic signed [31:0] exp[]
  );
    longint signed acc;
    exp = new[n*n];
    for (int i = 0; i < n; i++) begin
      for (int j = 0; j < n; j++) begin
        acc = bias[j];
        for (int k = 0; k < n; k++) begin
          acc += longint'(act[i*n+k]) * longint'(wei[j*n+k]);
        end
        exp[i*n+j] = acc[31:0];
      end
    end
  endfunction

endpackage
