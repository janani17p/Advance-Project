// Trojan 3: Info leakage

module tb_trojan_entropy_src_3;

  logic clk, rst_n;
  wire normal_out;
  wire trojan_leak;

  // DUT instantiation
  module_name dut (
    .clk(clk),
    .rst_n(rst_n),
    .normal_out(normal_out),
    .trojan_leak(trojan_leak)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Leak detection variables
  int leak_toggle_count = 0;

  initial begin
    clk = 0;
    rst_n = 0;

    repeat(10) @(posedge clk);
    rst_n = 1;

    // Run long enough to cross trigger threshold
    for (int i = 0; i < 80000; i++) begin
      @(posedge clk);

      // Detect suspicious leakage
      if (trojan_leak !== 1'b0) begin
        $display("\n[ERROR] Trojan leak detected at time %0t", $time);
        $display("Leak output toggled unexpectedly");
        $finish;
      end
    end

    $display("\n[INFO] No leakage observed -> Trojan NOT triggered");
    $finish;
  end

endmodule

