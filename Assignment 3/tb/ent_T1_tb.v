//Trojan 1: denial of service

module tb_trojan_entropy_src_1;

  logic clk, rst_n;
  logic entropy_req;
  wire  entropy_valid;
  wire [31:0] entropy_data;

  // Instantiate DUT
  entropy_src dut (
    .clk(clk),
    .rst_n(rst_n),
    .entropy_req(entropy_req),
    .entropy_valid(entropy_valid),
    .entropy_data(entropy_data)
  );

  // Clock
  always #5 clk = ~clk;

  // Stall detector
  fsm_state_t last_state;
  int stall_count = 0;

  initial begin
    clk = 0;
    rst_n = 0;
    entropy_req = 0;

    repeat(10) @(posedge clk);
    rst_n = 1;

    // Start entropy cycle
    @(posedge clk);
    entropy_req = 1;

    // Trojan detection monitor
    forever begin
      @(posedge clk);

      // FSM Stall detection (Trojan signature)
      if (dut.state == last_state)
        stall_count++;
      else
        stall_count = 0;

      if (stall_count > 1000) begin
        $display("\n[ERROR] FSM stall detected -> Possible Trojan activation!");
        $finish;
      end

      // entropy_valid suppression detection
      if (dut.state == READY && entropy_valid == 0) begin
        $display("\n[ERROR] entropy_valid suppressed illegally -> Trojan confirmed!");
        $finish;
      end

      last_state = dut.state;
    end
  end

endmodule
