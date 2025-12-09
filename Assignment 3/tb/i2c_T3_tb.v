//Trojan 3: info leakage

module tb_trojan_detect_i2c3;

  logic clk, rst_n;

  // DUT instance
  i2c_core dut(
    .clk_i(clk),
    .rst_ni(rst_n),
    .ram_cfg_i('0),
    .ram_cfg_rsp_o(),
    .reg2hw('0),
    .hw2reg(),
    .scl_i(1'b1),
    .scl_o(),
    .sda_i(1'b1),
    .sda_o(),
    .lsio_trigger_o(),
    .intr_fmt_threshold_o(),
    .intr_rx_threshold_o(),
    .intr_acq_threshold_o(),
    .intr_rx_overflow_o(),
    .intr_controller_halt_o(),
    .intr_scl_interference_o(),
    .intr_sda_interference_o(),
    .intr_stretch_timeout_o(),
    .intr_sda_unstable_o(),
    .intr_cmd_complete_o(),
    .intr_tx_stretch_o(),
    .intr_tx_threshold_o(),
    .intr_acq_stretch_o(),
    .intr_unexp_stop_o(),
    .intr_host_timeout_o()
  );

  // clock
  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    #40 rst_n = 1;

    // Speed up Trojan activation:
    // Force host_idle to 1 then 0 repeatedly to simulate transitions
    repeat (200000) begin
      force dut.host_idle = 1'b1;
      @(posedge clk);
      force dut.host_idle = 1'b0;
      @(posedge clk);
    end

    $display("END OF SIM");
    $finish;
  end

  // monitor Trojan leak
  always @(posedge clk) begin
    if (dut.debug_unused_q !== 8'd0) begin
      $display("TROJAN LEAK DETECTED at time %0t  leaked_value=0x%0h",
               $time, dut.debug_unused_q);
      $finish;
    end
  end

endmodule
