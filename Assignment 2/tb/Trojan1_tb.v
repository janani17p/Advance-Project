`timescale 1ns/1ps

module aes_T1_detect_tb();

  reg clk, rst_ni, rst_shadowed_ni;
  reg start;
  reg [127:0] data_in;
  reg [127:0] key_in;

  wire idle;
  wire output_valid;
  wire stall;

  // Instantiate DUT (Trojan-inserted AES core)
  aes_core dut (
    .clk_i(clk),
    .rst_ni(rst_ni),
    .rst_shadowed_ni(rst_shadowed_ni),

    .reg2hw({
      /* simplified struct wiring for testbench */
      .trigger.start.q(start),
      .data_in[0].q(data_in[31:0]),
      .data_in[1].q(data_in[63:32]),
      .data_in[2].q(data_in[95:64]),
      .data_in[3].q(data_in[127:96]),

      .key_share0[0].q(key_in[31:0]),
      .key_share0[1].q(key_in[63:32]),
      .key_share0[2].q(key_in[95:64]),
      .key_share0[3].q(key_in[127:96])
    }),

    .hw2reg(),     // unused
    .alert_recov_o(),
    .alert_fatal_o()
  );

  // clock
  always #5 clk = ~clk;

  integer cycle = 0;
  integer start_cycle = 0;
  integer ov_cycle = 0;

  always @(posedge clk) begin
    cycle <= cycle + 1;

    if (start && start_cycle == 0)
      start_cycle <= cycle;

    if (output_valid && ov_cycle == 0)
      ov_cycle <= cycle;

    if (stall)
      $display("STALL asserted at cycle %0d", cycle);
  end

  initial begin
    clk = 0;
    rst_ni = 0;
    rst_shadowed_ni = 0;
    start = 0;
    data_in = 128'h00112233445566778899aabbccddeeff;
    key_in  = 128'h000102030405060708090a0b0c0d0e0f;

    #20;
    rst_ni = 1;
    rst_shadowed_ni = 1;

    #20;
    $display("Starting AES...");
    start = 1;

    #10 start = 0;

    // allow FSM to run
    #500;

    $display("--------------------------------------------------");
    $display("Start cycle      : %0d", start_cycle);
    $display("Output_valid @   : %0d", ov_cycle);
    $display("Latency (cycles) : %0d", ov_cycle - start_cycle);

    if ((ov_cycle - start_cycle) > 1) begin
      $display("");
      $display(">>> TROJAN DETECTED: EXTRA FSM CYCLE IN CRYPT STATE <<<");
      $display("AES output_valid arrived 1 cycle late.");
    end else begin
      $display("");
      $display("No Trojan detected.");
    end

    $display("--------------------------------------------------");

    $finish;
  end
endmodule