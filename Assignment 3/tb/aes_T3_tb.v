//Trojan 3: Information Leakage

module tb_trojan_detect_keyleak;

  logic clk, rst_n;

  // AES standard interfaces
  aes_reg2hw_t reg2hw;
  aes_hw2reg_t hw2reg_golden;
  aes_hw2reg_t hw2reg_trojan;

  // Used to monitor trojan leakage
  logic [31:0] unused_golden [4];
  logic [31:0] unused_trojan [4];

  // Connect wires from trojan AES instance
  // (These internal signals must be made public using a bind or wrapper)
  // For demonstration, assume we expose unused_data_out_q
  wire [31:0] trojan_unused_q0;
  wire [31:0] golden_unused_q0;

  // Instantiate GOLDEN AES
  aes_core golden (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rst_shadowed_ni(1'b1),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg_golden)
  );

  // Instantiate TROJAN AES
  aes_core trojan (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rst_shadowed_ni(1'b1),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg_trojan)
  );

  // Clock
  always #5 clk = ~clk;

  // Load key and plaintext
  task program_inputs;
    begin
      // AES-128 key (4 words)
      reg2hw.key_share0[0].q = 32'h00010203;
      reg2hw.key_share0[1].q = 32'h04050607;
      reg2hw.key_share0[2].q = 32'h08090A0B;
      reg2hw.key_share0[3].q = 32'h0C0D0E0F;

      // Plaintext
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
    #20 rst_n = 1;

    program_inputs();

    // Run long enough for internal counter to reach 0xA53DC
    repeat (800000) begin
      @(posedge clk);

      // Monitor unused internal bus (key leak)
      if (trojan_unused_q0 !== golden_unused_q0) begin
        $display("========== TROJAN DETECTED ==========");
        $display("Trigger cycle reached");
        $display("Golden unused = %h", golden_unused_q0);
        $display("Trojan unused = %h", trojan_unused_q0);
        $finish;
      end
    end

    $display("NO TROJAN DETECTED");
    $finish;
  end

endmodule
