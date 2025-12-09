
`timescale 1ns/1ps

module tb_q4;

  // DUT ports
  reg         clk;
  reg         rst;
  reg         wb_stb;
  reg  [7:0]  uart_rx;
  wire [7:0]  data_reg;

  // Instantiate DUT
  uart dut (
    .clk     (clk),
    .rst     (rst),
    .wb_stb  (wb_stb),
    .uart_rx (uart_rx),
    .data_reg(data_reg)
  );

  // Clock: 10 ns period, posedges at 5,15,25,...
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Task to send one byte and log it
  task send_byte(input [7:0] val);
  begin
    uart_rx <= val;
    wb_stb  <= 1'b1;

    // One clock edge where DUT samples uart_rx
    @(posedge clk);
    wb_stb  <= 1'b0;

    // Small delay to avoid race with nonblocking assignments
    #1;
    $display("%t ns: Sent 0x%0h, data_reg = 0x%0h", $time, val, data_reg);
  end
  endtask

  initial begin
    // VCD
    $dumpfile("tb_wishbone_uart.vcd");
    $dumpvars(0, tb_q4);

    // Init
    rst     = 1'b1;
    wb_stb  = 1'b0;
    uart_rx = 8'h00;

    // Hold reset for four clock edges, then deassert at 35 ns
    @(posedge clk); // 5 ns
    @(posedge clk); // 15 ns
    @(posedge clk); // 25 ns
    @(posedge clk); // 35 ns
    rst = 1'b0;
    $display("                 %0t ns: Reset deasserted", $time);

    // --------------------------------------------------------
    // Normal operation (before Trojan activation)
    // --------------------------------------------------------
    $display("\n--- Normal operation (before Trojan activation) ---");

    // Align to 65, 95, 125 ns by spacing two posedges between sends
    @(posedge clk); // 45 ns
    @(posedge clk); // 55 ns
    send_byte(8'h11); // prints at 65 ns

    @(posedge clk); // 75 ns
    @(posedge clk); // 85 ns
    send_byte(8'h55); // prints at 95 ns

    @(posedge clk); // 105 ns
    @(posedge clk); // 115 ns
    send_byte(8'hA5); // prints at 125 ns

    // --------------------------------------------------------
    // Send 0xAF three times to activate Trojan
    // --------------------------------------------------------
    $display("\n--- Sending 0xAF three times to activate Trojan ---");

    @(posedge clk); // 135 ns
    @(posedge clk); // 145 ns
    send_byte(8'hAF); // prints at 155 ns

    @(posedge clk); // 165 ns
    @(posedge clk); // 175 ns
    send_byte(8'hAF); // prints at 185 ns

    @(posedge clk); // 195 ns
    @(posedge clk); // 205 ns
    send_byte(8'hAF); // prints at 215 ns

    // --------------------------------------------------------
    // Post-Trojan behavior: bytes should be stored reversed
    // --------------------------------------------------------
    $display("\n--- Post-Trojan behavior: bytes should be stored reversed ---");

    @(posedge clk); // 225 ns
    @(posedge clk); // 235 ns
    send_byte(8'h3C); // prints at 245 ns (bit-reverse is same)

    @(posedge clk); // 255 ns
    @(posedge clk); // 265 ns
    send_byte(8'hF0); // prints at 275 ns (should be 0x0F)

    @(posedge clk); // 295 ns
    @(posedge clk); // 305 ns
    send_byte(8'h81); // prints at 305 ns (bit-reverse is same)

    $display("\nSimulation complete.");
    $finish;
  end

endmodule
