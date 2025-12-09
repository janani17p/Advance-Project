`timescale 1ns/1ps

module edn_T5_detect_tb;

  reg clk;
  reg rst_n;

  // CSRNG response mock
  reg csrng_valid;
  reg csrng_ready;
  reg [127:0] csrng_entropy;

  // EDN outputs
  wire [127:0] edn_entropy_out;

  // Trojan internal tap
  wire trojan_reuse_flag;
  wire trojan_trigger;

  // DUT instance (exposing signals for test only)
  edn_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .reg2hw('{default:0}),
    .hw2reg(),
    .edn_i('{default:'0}),
    .edn_o(),
    .csrng_cmd_o(),
    .csrng_cmd_i('{ genbits_valid:csrng_valid,
                   genbits_bus:csrng_entropy,
                   genbits_fips:1'b0,
                   csrng_rsp_ack:csrng_ready,
                   csrng_rsp_sts:0 }),
    .recov_alert_test_o(),
    .fatal_alert_test_o(),
    .recov_alert_o(),
    .fatal_alert_o(),
    .intr_edn_cmd_req_done_o(),
    .intr_edn_fatal_err_o()
  );

  // Expose Trojan detection signals
  assign trojan_reuse_flag = dut.trojan_reuse_flag_q;
  assign trojan_trigger = dut.trojan_trigger;

  // For comparison
  reg [127:0] last_entropy_real;

  // Clock
  always #5 clk = ~clk;

  initial begin
    $display("\n===========================================================");
    $display(" EDN TROJAN 5 DETECTION SIMULATION");
    $display("===========================================================\n");

    clk = 0;
    rst_n = 0;
    csrng_valid = 0;
    csrng_ready = 1;
    csrng_entropy = 128'h1234;

    #20 rst_n = 1;
    $display("[%0t ns] Reset released\n", $time);

    // Feed 32767 valid entropy words
    repeat(32767) begin
      #10;
      csrng_valid = 1;
      csrng_entropy = $random;
      last_entropy_real = csrng_entropy;

      if (trojan_trigger)
        $display(">>> TROJAN TRIGGER COUNT REACHED at %0t ns <<<", $time);
    end

    csrng_valid = 1;
    csrng_entropy = $random;

    #10;

    if (trojan_reuse_flag) begin
      $display("\n>>> TROJAN ACTIVATED at time %0t ns <<<", $time);
      $display("Expected fresh entropy != output");
    end

    #20;
    $display("\nSimulation complete.");
    $finish;
  end

endmodule
