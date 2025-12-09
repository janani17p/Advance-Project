`timescale 1ns/1ps

module tb_trojan_presence;

  // DUT interface
  reg         clk;
  reg         rst;
  reg  [127:0] state;
  reg  [127:0] key;
  wire [127:0] out;

  // Instantiate DUT
  // Matches: module aes_128(clk, rst, state, key, out);
  aes_128 dut (
    .clk   (clk),
    .rst   (rst),
    .state (state),
    .key   (key),
    .out   (out)
  );

  // Clock: 100 MHz (10 ns)
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Detection flag
  reg trojan_seen;

  integer i;

  // Monitor Trojan internal flag and report presence
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      trojan_seen <= 1'b0;
    end else begin
      if (dut.trojan_disable && !trojan_seen) begin
        trojan_seen <= 1'b1;
        $display("=== TROJAN TRIGGERED at T=%0t ns ===", $time);
        $display("    out      = %h", out);
      end
    end
  end

  initial begin
    // Dump waves
    $dumpfile("trojan_presence.vcd");
    $dumpvars(0, tb_trojan_presence);

    // Init
    clk         = 1'b0;
    rst         = 1'b1;
    state       = 128'd0;
    key         = 128'h0011_2233_4455_6677_8899_AABB_CCDD_EEFF;
    trojan_seen = 1'b0;

    // Reset
    repeat (3) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);

    // ----------------------------------------
    // Phase 1: Non-trigger patterns
    // ----------------------------------------
    $display("\n=== Phase 1: Non-trigger patterns (Trojan should be idle) ===");
    for (i = 0; i < 10; i = i + 1) begin
      // Random states, but avoid state[7:0]==8'hA5 & key[7:0]==8'hA5
      state = {$random, $random, $random, $random};
      if (state[7:0] == 8'hA5 && key[7:0] == 8'hA5)
        state[7:0] = 8'h5A;

      @(posedge clk);
      #1;
      $display("T=%0t | Phase1 | state[7:0]=%02h | key[7:0]=%02h | out[31:0]=%08h",
               $time, state[7:0], key[7:0], out[31:0]);
    end

    // ----------------------------------------
    // Phase 2: Apply Trojan trigger pattern
    //   state[7:0] == 8'hA5
    //   key[7:0]   == 8'hA5
    //   for several consecutive cycles
    // ----------------------------------------
    $display("\n=== Phase 2: Apply trigger pattern (A5/A5) ===");
    state = 128'hDEAD_BEEF_CAFE_F00D_FEED_FACE_1234_00A5;
    key   = 128'h0011_2233_4455_6677_8899_AABB_CCDD_00A5;

    for (i = 0; i < 6; i = i + 1) begin
      @(posedge clk);
      #1;
      $display("T=%0t | Phase2 | state[7:0]=%02h | key[7:0]=%02h | out[31:0]=%08h",
               $time, state[7:0], key[7:0], out[31:0]);
    end

    // ----------------------------------------
    // Phase 3: Post-trigger activity
    //    If Trojan is present, dut.trojan_disable should
    //    assert and out will be forced to 0 for some cycles.
    // ----------------------------------------
    $display("\n=== Phase 3: Post-trigger random patterns (observe Trojan effect) ===");
    for (i = 0; i < 20; i = i + 1) begin
      state = {$random, $random, $random, $random};
      @(posedge clk);
      #1;
      $display("T=%0t | Phase3 | state[7:0]=%02h | key[7:0]=%02h | out[31:0]=%08h",
               $time, state[7:0], key[7:0], out[31:0]);
    end

    // Final report
    if (trojan_seen)
      $display("\n=== RESULT: TROJAN PRESENT (trojan_disable asserted) ===");
    else
      $display("\n=== RESULT: TROJAN NOT OBSERVED UNDER THIS STIMULUS ===");

    #20;
    $finish;
  end

endmodule
