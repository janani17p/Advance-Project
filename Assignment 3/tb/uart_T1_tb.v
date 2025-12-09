//Trojan 1: Denial of service

module uart_trojan_detect_tb;

  logic clk, rst_n;
  logic rx;
  logic tx_golden, tx_trojan;

  // Simple clock
  always #5 clk = ~clk;

  // Instantiate golden UART
  uart_core golden (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rx(rx),
    .tx(tx_golden),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg_golden),
    .* // interrupts ignored for detection
  );

  // Instantiate trojan UART
  uart_core trojan (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rx(rx),
    .tx(tx_trojan),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg_trojan),
    .*
  );

  // Stimulus: feed data repeatedly to provoke tx_fifo_rready
  initial begin
    clk=0; rst_n=0; rx=1;
    #40 rst_n=1;

    repeat (2000000) begin
      drive_tx_byte(8'h55);
    end

    #2000;
    $finish;
  end

  // Task to push byte into UART WDATA register
  task drive_tx_byte(input [7:0] b);
    reg2hw.wdata.q = b;
    reg2hw.wdata.qe = 1;
    #10 reg2hw.wdata.qe = 0;
  endtask

  // Comparison logic
  always @(posedge clk) begin
    if (rst_n) begin
      if (tx_golden !== tx_trojan) begin
        $display("[%0t] TROJAN DETECTED: TX mismatch golden=%b trojan=%b",
                 $time, tx_golden, tx_trojan);
      end
    end
  end

endmodule
