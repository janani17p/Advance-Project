
`timescale 1ns/1ps

module tb_uart_trojan;

  // Clock & reset
  reg clk;
  reg rst;

  // UART pins
  reg  rx;
  wire tx;

  // Wishbone interface
  reg  [31:0] wb_adr_i;
  reg         wb_stb_i;
  reg         wb_cyc_i;
  reg         wb_we_i;
  reg  [31:0] wb_dat_i;
  wire [31:0] wb_dat_o;
  wire        wb_ack_o;

  // Instantiate DUT
  uart_core dut (
    .clk      (clk),
    .rst      (rst),
    .rx       (rx),
    .tx       (tx),
    .wb_adr_i (wb_adr_i),
    .wb_stb_i (wb_stb_i),
    .wb_cyc_i (wb_cyc_i),
    .wb_we_i  (wb_we_i),
    .wb_dat_i (wb_dat_i),
    .wb_dat_o (wb_dat_o),
    .wb_ack_o (wb_ack_o)
  );

  // Clock generation: 100 MHz
  initial clk = 0;
  always #5 clk = ~clk;   // 10 ns period

  // Roughly match your UART timing gaps (~1.04167e9 time units)
  // This is just for similar timestamps, not for real UART baud.
  localparam integer BYTE_GAP = 1041670000;

  // Task: perform a Wishbone READ and print ACK status
  task wb_read_access;
  begin
    wb_adr_i = 32'h0000_0000;
    wb_dat_i = 32'h0000_0000;
    wb_we_i  = 1'b0;

    wb_stb_i = 1'b1;
    wb_cyc_i = 1'b1;

    // Wait some cycles to allow ACK to appear (or not)
    repeat (10) @(posedge clk);

    if (wb_ack_o)
      $display("WB READ ACK at time %0t", $time);
    else
      $display("WB READ NO-ACK at time %0t", $time);

    wb_stb_i = 1'b0;
    wb_cyc_i = 1'b0;
    @(posedge clk);
  end
  endtask

  // Task: inject a "received" UART byte directly into DUT
  // (since the actual UART RX logic is not included)
  task send_uart_byte(input [7:0] b);
  begin
    // Hierarchical access to internal register
    dut.received_byte = b;
    $display("Time %0t : UART sent byte 0x%0h", $time, b);
    #(BYTE_GAP);
  end
  endtask

  initial begin
    // VCD dump
    $dumpfile("tb_uart_trojan.vcd");
    $dumpvars(0, tb_uart_trojan);

    // Default init
    rx       = 1'b1;
    wb_adr_i = 32'd0;
    wb_dat_i = 32'd0;
    wb_stb_i = 1'b0;
    wb_cyc_i = 1'b0;
    wb_we_i  = 1'b0;

    // Reset pulse
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
    repeat (5) @(posedge clk);

    // ------------------------------
    // 1) Normal Wishbone Access
    // ------------------------------
    $display("\n--- Normal Wishbone Access (should ACK) ---");
    wb_read_access;

    // ------------------------------
    // 2) Trojan trigger sequence
    //    10 A4 98 BD
    // ------------------------------
    $display("\n--- Sending Trojan trigger sequence: 10 A4 98 BD ---");
    send_uart_byte(8'h10);
    send_uart_byte(8'hA4);
    send_uart_byte(8'h98);
    send_uart_byte(8'hBD);

    // ------------------------------
    // 3) WB access after Trojan trigger
    // ------------------------------
    $display("\n--- Wishbone Access after Trojan Trigger (ACK should STOP) ---");
    wb_read_access;

    // ------------------------------
    // 4) Send recovery bytes: FE FE FE FE
    // ------------------------------
    $display("\n--- Sending recovery bytes FE FE FE FE ---");
    send_uart_byte(8'hFE);
    send_uart_byte(8'hFE);
    send_uart_byte(8'hFE);
    send_uart_byte(8'hFE);

    // ------------------------------
    // 5) WB access after recovery
    // ------------------------------
    $display("\n--- Wishbone Access after Trojan Recovery (ACK should RESUME) ---");
    wb_read_access;

    // ------------------------------
    // 6) Trojan 2 test: AF AF AF then B2
    // ------------------------------
    $display("\n--- Testing Trojan 2: Send AF AF AF ---");
    send_uart_byte(8'hAF);
    send_uart_byte(8'hAF);
    send_uart_byte(8'hAF);

    $display("\nTrigger active. Now sending byte 0xB2 (expect reversed 0x4D)");
    send_uart_byte(8'hB2);

    $finish;
  end

endmodule
