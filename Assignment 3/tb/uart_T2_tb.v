//Trojan 2: Functionlaity change

module uart_trojan_detect_tb;

  // Clock and reset
  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk;   // 100 MHz clock

  // UART DUT signals
  reg  rx;
  wire tx;

  // Minimal register model
  uart_reg_pkg::uart_reg2hw_t reg2hw;
  uart_reg_pkg::uart_hw2reg_t hw2reg;

  // Instantiate DUT
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

  // ------------------------------
  // Testbench internal signals
  // ------------------------------
  reg [7:0] test_data [0:15];
  integer i;

  integer stall_count;
  integer corruption_found = 0;

  reg [7:0] expected_byte;
  reg [7:0] observed_byte;

  // UART bit timing (assuming default divisor for simulation)
  localparam BIT_TIME = 160;  // adjust per NCO settings

  // ---------------------------------------
  // RESET SEQUENCE
  // ---------------------------------------
  initial begin
    $display("UART TROJAN DETECTION TEST STARTING...");
    rst_n = 0;
    rx = 1'b1;

    // Clear reg2hw defaults
    reg2hw.ctrl.tx.q = 1;
    reg2hw.ctrl.rx.q = 1;
    reg2hw.ctrl.parity_en.q = 0;
    reg2hw.ctrl.parity_odd.q = 0;

    #50 rst_n = 1;
    $display("Reset deasserted at %t", $time);

    // Load test data
    for (i = 0; i < 16; i++)
      test_data[i] = 8'h55;   // known predictable byte

    // ------------------------------------------------
    // Apply stimulus
    // ------------------------------------------------
    $display("Injecting UART test pattern...");

    for (i = 0; i < 4; i++) begin
      reg2hw.wdata.q  = test_data[i];
      reg2hw.wdata.qe = 1'b1;
      #20 reg2hw.wdata.qe = 1'b0;

      // Allow time for TX FIFO to push
      #(BIT_TIME * 12);
    end

    // ------------------------------------------------
    // DETECT STALL TROJAN
    // ------------------------------------------------
    stall_count = 0;
    fork
      begin
        while (tx == 1'b0 || tx == 1'b1) begin
          if (dut.uart_tx.tx_busy) begin
            stall_count = stall_count + 1;
          end else begin
            stall_count = 0;
          end

          if (stall_count > 30) begin
            $display("[TROJAN DETECTED] Stall behavior: TX busy frozen > 30 cycles at %0t", $time);
            corruption_found = 1;
            disable fork;
          end

          #10;
        end
      end
    join_any

    // ------------------------------------------------
    // DETECT CORRUPTED BYTE PAYLOAD
    // ------------------------------------------------
    expected_byte = 8'h55;

    // sample TX waveform for one frame
    #(BIT_TIME);  // wait start bit
    observed_byte = 0;

    for (i = 0; i < 8; i++) begin
      #(BIT_TIME);
      observed_byte[i] = tx;
    end

    if (observed_byte !== expected_byte) begin
      $display("[TROJAN DETECTED] TX corruption detected!");
      $display(" Expected: %02h  Observed: %02h", expected_byte, observed_byte);
      corruption_found = 1;
    end

    // ------------------------------------------------
    // FINAL RESULT
    // ------------------------------------------------
    if (corruption_found)
      $display("FINAL RESULT: TROJAN PRESENT");
    else
      $display("FINAL RESULT: NO TROJAN DETECTED");

    $finish;
  end

endmodule
