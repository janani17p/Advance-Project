`timescale 1ns/1ps

module uart_T4_detect_tb;

  reg clk;
  reg rst_n;

  // DUT inputs
  reg rx;
  reg tx_enable_fake;

  // DUT outputs
  wire tx;
  wire trojan_noise_o;

  // Create minimal fake reg2hw structure
  // Only signals needed for trojan triggering are driven
  reg [15:0] rx_val_force;
  reg tx_fifo_empty;

  // Instantiate DUT (modified to expose trojan_noise_o)
  uart_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),

    .reg2hw('{default:0}),
    .hw2reg(),

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
    .intr_rx_parity_err_o(),

    .trojan_noise_o(trojan_noise_o)
  );

  // Clock
  always #5 clk = ~clk;

  // Monitor trojan activation
  initial begin
    $display("\n=======================================================");
    $display(" UART TROJAN 4 DETECTION SIMULATION");
    $display("=======================================================\n");

    clk = 0;
    rst_n = 0;
    rx = 1;

    #20 rst_n = 1;
    $display("[%0t ns] Reset released", $time);

    // Wait for TX idle
    #100;
    $display("[%0t ns] TX idle detected, FIFO empty", $time);

    // Inject crafted trigger pattern
    rx_val_force = 16'hA005;
    force dut.rx_val_q = rx_val_force;

    $display("[%0t ns] Injecting trigger pattern: Axxx5", $time);

    // Wait for trojan
    repeat(20) begin
      #10;
      if (dut.trojan_enable_q) begin
        $display("\n>>> TROJAN TRIGGERED at time %0t ns <<<", $time);
      end

      if (trojan_noise_o) begin
        $display("trojan_noise_o toggled: %0d", trojan_noise_o);
      end
    end

    $display("\nSimulation complete.\n");
    $finish;
  end

endmodule