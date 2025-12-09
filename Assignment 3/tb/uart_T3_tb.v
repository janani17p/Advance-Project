// Trojan 3: Info Leakage

module uart_trojan_detect_tb;

  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk;

  // UART interface
  reg  rx;
  wire tx;

  uart_reg_pkg::uart_reg2hw_t reg2hw;
  uart_reg_pkg::uart_hw2reg_t hw2reg;

  // DUT
  uart_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg),
    .rx(rx),
    .tx(tx),
    .lsio_trigger_o(),
    .intr_tx_watermark_o(),
    .intr_tx_empty_o(),
    .intr_rx_watermark_o(),
    .intr_tx_done_o(),
    .intr_rx_overflow_o(),
    .intr_rx_frame_err_o(),
    .intr_rx_break_err_o(),
    .intr_rx_timeout_o(),
    .intr_rx_parity_err_o()
  );

  integer leak_detected = 0;

  // -----------------------------
  // Reset
  // -----------------------------
  initial begin
    $display("UART TROJAN DETECTION TEST BEGIN");
    rst_n = 0;
    rx = 1'b1;

    reg2hw.ctrl.tx.q = 1;
    reg2hw.ctrl.rx.q = 1;
    reg2hw.ctrl.parity_en.q = 0;

    #40 rst_n = 1;
    $display("Reset released at %0t", $time);

    // Feed some data into RX path to load rx_shift_reg
    repeat (12) begin
      rx = $random;
      #20;
    end

    // Monitor for info leak
    fork
      begin : info_leak_check
        forever begin
          @(posedge clk);

          // Check unused_rx_reg for illegal movement
          if (dut.unused_rx_reg !== 8'h00) begin
            $display("[INFO LEAK DETECTED @ %0t]", $time);
            $display("  rx_shift_reg = %02h", dut.trojan_rx_shift_reg);
            $display("  leaked_value = %02h", dut.unused_rx_reg);
            leak_detected = 1;
            disable info_leak_check;
          end
        end
      end
    join_any

    #2000;

    if (leak_detected)
      $display("FINAL RESULT: TROJAN DETECTED");
    else
      $display("FINAL RESULT: NO TROJAN DETECTED");

    $finish;
  end

endmodule
