// Trojan 3: Info leakage



module csrng_trojan_detect_tb;

  // Clocks and reset
  logic clk;
  logic rst_n;

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  // Device under test
  csrng_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .* // connect required interfaces
  );

  // Golden reference model instance
  csrng_core_golden golden (
    .clk_i(clk),
    .rst_ni(rst_n),
    .* // same connections
  );

  // Output comparison
  always @(posedge clk) begin
    if (rst_n) begin

      if (dut.genbits_core_bus !== golden.genbits_core_bus) begin
        $display("ERROR at time %t  genbits mismatch between DUT and Golden", $time);
      end

      if (dut.cs_main_sm_state !== golden.cs_main_sm_state) begin
        $display("ERROR at time %t  state machine mismatch", $time);
      end

      if (dut.cmd_stage_ack !== golden.cmd_stage_ack) begin
        $display("ERROR at time %t  command acknowledge mismatch", $time);
      end

      // Generic detection of unused toggling signals
      if (dut.trojan_exfiltrate_o === 1) begin
        $display("ERROR at time %t  unexpected activity detected on unused signal", $time);
      end

    end
  end

endmodule
