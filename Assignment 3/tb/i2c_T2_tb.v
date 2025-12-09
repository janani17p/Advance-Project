//Trojan 2: funtionality change

module tb_trojan_detect_i2c2;

  logic clk, rst_n;
  logic scl, sda;
  logic [7:0] expected_byte = 8'h3A;  
  logic [7:0] received_byte;

  // DUT
  i2c_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .scl_i(scl),
    .sda_i(sda)
    // other ports default or tied off
  );

  // clock
  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    scl = 1;
    sda = 1;
    #40 rst_n = 1;

    // wait long enough for Trojan counter to reach A95C and fire
    repeat (200000) @(posedge clk);
    $finish;
  end

  // Monitor transmit FIFO (simplified)
  always @(posedge clk) begin
    if (dut.tx_fifo_wvalid && dut.tx_fifo_wready) begin
      received_byte = dut.tx_fifo_wdata;
      if (received_byte !== expected_byte) begin
        if (received_byte == (expected_byte ^ 8'h96)) begin
          $display("TROJAN DETECTED: Byte corrupted with XOR 0x96 at time %0t", $time);
        end else begin
          $display("DATA CORRUPTION: Unexpected mismatch %0t", $time);
        end
        $finish;
      end
    end
  end

  // direct Trojan pulse detection
  always @(posedge clk) begin
    if (dut.trojan_corrupt_next_byte)
      $display("TROJAN PAYLOAD ENABLED at %0t", $time);
  end

endmodule
