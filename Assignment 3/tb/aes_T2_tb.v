//Trojan 2: Functionality Change

module tb_trojan_detect;

  logic clk, rst_n;

  // For logging corruption
  int count_valid = 0;

  // AES input signals
  aes_reg2hw_t reg2hw;
  aes_hw2reg_t hw2reg_golden;
  aes_hw2reg_t hw2reg_trojan;

  // Instantiate golden AES
  aes_core golden (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rst_shadowed_ni(1'b1),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg_golden)
  );

  // Instantiate Trojan AES
  aes_core trojan (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rst_shadowed_ni(1'b1),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg_trojan)
  );

  // Clock generator
  always #5 clk = ~clk;

  task load_inputs;
    begin
      reg2hw.key_share0[0].q = 32'h00010203;
      reg2hw.key_share0[1].q = 32'h04050607;
      reg2hw.key_share0[2].q = 32'h08090A0B;
      reg2hw.key_share0[3].q = 32'h0C0D0E0F;

      reg2hw.data_in[0].q = 32'h00112233;
      reg2hw.data_in[1].q = 32'h44556677;
      reg2hw.data_in[2].q = 32'h8899AABB;
      reg2hw.data_in[3].q = 32'hCCDDEEFF;

      reg2hw.trigger.start.q = 1;
    end
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    #25 rst_n = 1;

    load_inputs();

    // Run many encryptions until mismatch appears
    repeat (70000) begin
      @(posedge clk);
      if (hw2reg_golden.status.output_valid.d == 1 &&
          hw2reg_trojan.status.output_valid.d == 1) begin

        count_valid++;

        if (hw2reg_golden.data_out != hw2reg_trojan.data_out) begin
          $display("========== TROJAN DETECTED ==========");
          $display("cipher_out_valid event = %0d", count_valid);
          $display("Golden = %h", hw2reg_golden.data_out);
          $display("Trojan = %h", hw2reg_trojan.data_out);
          $display("Diff   = %h",
                   hw2reg_golden.data_out ^ hw2reg_trojan.data_out);
          $finish;
        end

      end
    end

    $display("NO TROJAN DETECTED (Test ended)");
    $finish;
  end

endmodule
