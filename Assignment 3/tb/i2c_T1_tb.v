//Trojan 1: denial of service

module tb_trojan_detect;

  logic clk, rst_n;
  logic scl, sda;
  logic scl_o, sda_o;

  // Instantiate DUT
  i2c dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .scl_i(scl),
    .sda_i(sda),
    .scl_o(scl_o),
    .sda_o(sda_o)
    // other signals tied off or defaulted
  );

  // Clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset
  initial begin
    rst_n = 0;
    #40;
    rst_n = 1;
  end

  // Simple stimulus
  initial begin
    // Idle bus
    scl = 1;
    sda = 1;

    // Wait for controller actions
    repeat (20000) @(posedge clk);

    $finish;
  end

  // Trojan detection
  logic [3:0] last_state;
  int stall_count = 0;

  always @(posedge clk) begin
    last_state <= dut.i2c_ctrl_fsm_state_q;

    // FSM not progressing
    if (dut.i2c_ctrl_fsm_state_q == last_state)
      stall_count++;
    else
      stall_count = 0;

    if (stall_count == 4) begin
      $display("TROJAN DETECTED: FSM stalled for 4 cycles at time %0t", $time);
      $finish;
    end

    // Host timeout check
    if (dut.intr_host_timeout_o) begin
      $display("TROJAN DETECTED: Host timeout triggered at time %0t", $time);
      $finish;
    end
  end

endmodule
