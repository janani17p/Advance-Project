`timescale 1ns/1ps

// Simple lightweight reg2hw struct replacement
typedef struct packed {
  struct packed {
    logic        tx;
    logic        rx;
    logic        nf;
    logic        slpbk;
    logic        llpbk;
    logic        parity_en;
    logic        parity_odd;
    logic [15:0] nco;
  } ctrl;

  struct packed {
    logic        txrst;
    logic        txrst_qe;
    logic        rxrst;
    logic        rxrst_qe;
    logic [2:0]  rxilvl;
    logic [2:0]  txilvl;
  } fifo_ctrl;

  struct packed {
    logic        txen;
    logic        txval;
  } ovrd;

  struct packed {
    logic [7:0]  q;
    logic        qe;
  } wdata;

  struct packed {
    logic        re;
  } rdata;

  struct packed {
    logic [31:0] alert_test;
  } alert_test;

  struct packed {
    struct packed { logic q; } tx_watermark;
    struct packed { logic q; } tx_empty;
    struct packed { logic q; } rx_watermark;
    struct packed { logic q; } tx_done;
    struct packed { logic q; } rx_overflow;
    struct packed { logic q; } rx_frame_err;
    struct packed { logic q; } rx_break_err;
    struct packed { logic q; } rx_timeout;
    struct packed { logic q; } rx_parity_err;
  } intr_enable;

  struct packed {
    struct packed { logic q; logic qe; } tx_watermark;
    struct packed { logic q; logic qe; } tx_empty;
    struct packed { logic q; logic qe; } rx_watermark;
    struct packed { logic q; logic qe; } tx_done;
    struct packed { logic q; logic qe; } rx_overflow;
    struct packed { logic q; logic qe; } rx_frame_err;
    struct packed { logic q; logic qe; } rx_break_err;
    struct packed { logic q; logic qe; } rx_timeout;
    struct packed { logic q; logic qe; } rx_parity_err;
  } intr_test;

  struct packed {
    struct packed { logic q; } tx_watermark;
    struct packed { logic q; } tx_empty;
    struct packed { logic q; } rx_watermark;
    struct packed { logic q; } tx_done;
    struct packed { logic q; } rx_overflow;
    struct packed { logic q; } rx_frame_err;
    struct packed { logic q; } rx_break_err;
    struct packed { logic q; } rx_timeout;
    struct packed { logic q; } rx_parity_err;
  } intr_state;

  struct packed { logic [7:0] val; } timeout_ctrl;

} uart_reg2hw_t;


module uart_troj_detect_tb;
  logic clk, rst_n;
  logic rx, tx;

  uart_reg2hw_t reg2hw;
  logic dummy;

  // DUT instance
  uart_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .reg2hw(reg2hw),
    .hw2reg(dummy),
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

  // Clock
  always #5 clk = ~clk;

  // Simple UART RX push procedure
  task send_rx_byte(input [7:0] b);
    rx = 0; repeat (16) @(posedge clk);
    foreach (b[i]) begin
      rx = b[i];
      repeat(16) @(posedge clk);
    end
    rx = 1; repeat(16) @(posedge clk);
  endtask

  initial begin
    clk = 0; rx = 1; rst_n = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;

    // Enable UART
    reg2hw.ctrl.tx = 1;
    reg2hw.ctrl.rx = 1;

    $display("\n===== TROJAN DETECTION TEST START =====\n");

    // Trigger sequence A7 3C F1
    send_rx_byte(8'hA7);
    $display("Sent A7");
    send_rx_byte(8'h3C);
    $display("Sent 3C");
    send_rx_byte(8'hF1);
    $display("Sent F1 (Trigger)");


    // Now push a byte for TX to send out
    reg2hw.wdata.q = 8'h5A;
    reg2hw.wdata.qe = 1'b1;
    @(posedge clk);
    reg2hw.wdata.qe = 1'b0;

    // Wait a little for TX to produce output
    repeat(500) @(posedge clk);

    $display("\nTX Output Bitstream:");
    $display("TX = %b", tx);

    $display("\n===== END TROJAN DETECTION =====\n");
    $finish;
  end
endmodule