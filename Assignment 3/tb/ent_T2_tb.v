//Trojan 2: functionality change

module tb_trojan_entropy_src_2;

  logic clk, rst_n;
  logic [7:0] entropy_in;
  logic sample_en;
  wire [7:0] entropy_out;

  // DUT
  entropy_src dut (
    .clk(clk),
    .rst_n(rst_n),
    .entropy_in(entropy_in),
    .sample_en(sample_en),
    .entropy_out(entropy_out)
  );

  // Clock
  always #5 clk = ~clk;

  // Expected value tracker
  logic [7:0] expected_value;

  initial begin
    clk = 0;
    rst_n = 0;
    sample_en = 0;
    entropy_in = 8'h00;

    repeat(10) @(posedge clk);
    rst_n = 1;

    // Trojan activation sweep
    sample_en = 1;
    for (int i = 0; i < 100000; i++) begin
      @(posedge clk);
      entropy_in = $urandom;

      expected_value = entropy_in;

      @(posedge clk);

      // Detect payload corruption
      if (entropy_out !== expected_value) begin
        $display("\n[ERROR] Bit-flip corruption detected!");
        $display("Expected: %h  Observed: %h", expected_value, entropy_out);
        $finish;
      end
    end

    $display("\n[INFO] No corruption observed -> Trojan NOT triggered");
    $finish;
  end

endmodule
