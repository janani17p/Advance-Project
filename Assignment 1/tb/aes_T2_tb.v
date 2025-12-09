`timescale 1ns/1ps

module tb_trojan_presence;

  // ----------------------------------------
  // DUT interface
  // ----------------------------------------
  reg         clk;
  reg         rst_n;          // active-low reset
  reg  [127:0] state;
  reg  [127:0] key;
  wire [127:0] out;
  wire         trojan_out;    // dedicated Trojan pin

  // ----------------------------------------
  // Instantiate DUT
  // If your top is called aes2, change aes_128 -> aes2.
  // If your reset is rst (active-high), change the port mapping accordingly.
  // ----------------------------------------
  aes_128 dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .state      (state),
    .key        (key),
    .out        (out),
    .trojan_out (trojan_out)
  );

  // ----------------------------------------
  // Clock generation: 100 MHz (10 ns period)
  // ----------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ----------------------------------------
  // Trojan presence detection
  // ----------------------------------------
  localparam [127:0] TEST_KEY = 128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210;

  integer cycle;
  integer trojan_toggle_count;
  reg     trojan_seen;
  reg     trojan_prev;

  // Monitor trojan_out for any activity after reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trojan_prev         <= 1'b0;
      trojan_toggle_count <= 0;
      trojan_seen         <= 1'b0;
    end else begin
      // If trojan_out changes, we consider that Trojan behavior
      if (trojan_out !== trojan_prev) begin
        trojan_toggle_count <= trojan_toggle_count + 1;
        trojan_seen         <= 1'b1;
        $display(">>> [T=%0t ns] TROJAN_OUT TOGGLED: %b -> %b <<<",
                 $time, trojan_prev, trojan_out);
      end
      trojan_prev <= trojan_out;
    end
  end

  // ----------------------------------------
  // Stimulus: just shake the design with random traffic.
  // We don't try to guess the exact trigger; we just ask:
  // "Does trojan_out ever do anything non-constant?"
  // ----------------------------------------
  initial begin
    // Waveform dump
    $dumpfile("trojan_presence.vcd");
    $dumpvars(0, tb_trojan_presence);

    // Initial conditions
    clk                 = 1'b0;
    rst_n               = 1'b0;  // assert reset (active low)
    state               = 128'd0;
    key                 = TEST_KEY;
    trojan_toggle_count = 0;
    trojan_seen         = 1'b0;
    trojan_prev         = 1'b0;

    // Hold reset for a few cycles
    repeat (5) @(posedge clk);
    rst_n = 1'b1;                // deassert reset
    @(posedge clk);

    $display("\n=== Trojan Presence Test: start ===");

    // Phase 1: random states, fixed key
    $display("=== Phase 1: random states, fixed key ===");
    for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
      state = { $random, $random, $random, $random };
      // key fixed to TEST_KEY
      @(posedge clk);
      #1;
      $display("T=%0t ns | cyc=%0d | trojan_out=%b | out[15:0]=%h",
               $time, cycle, trojan_out, out[15:0]);
    end

    // Phase 2: random states and random keys
    $display("=== Phase 2: random states and random keys ===");
    for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
      state = { $random, $random, $random, $random };
      key   = { $random, $random, $random, $random };
      @(posedge clk);
      #1;
      $display("T=%0t ns | cyc=%0d | trojan_out=%b | out[15:0]=%h",
               $time, cycle + 200, trojan_out, out[15:0]);
    end

    // Final decision
    $display("\n=== Trojan Presence Summary ===");
    if (trojan_seen) begin
      $display("RESULT: TROJAN LIKELY PRESENT (trojan_out toggled %0d times).",
               trojan_toggle_count);
    end else begin
      $display("RESULT: No trojan activity observed on trojan_out under this stimulus.");
    end

    #20;
    $finish;
  end

endmodule
