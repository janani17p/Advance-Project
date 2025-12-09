`timescale 1ns/1ps

module aes_T2_detect_tb;

  // DUT inputs
  reg clk;
  reg rst_n;
  reg [3:0][3:0][7:0] data_i;
  reg aes_pkg::ciph_op_e op_i;

  // DUT output
  wire [3:0][3:0][7:0] data_o;

  // Force access to internal Trojan counter + trigger
  // (This is allowed in testbench-only verification)
  // Path MUST match your instance name
  logic [19:0] force_cnt;
  logic force_trig;

  // Instantiate DUT
  aes_mix_columns dut (
    .clk(clk),
    .rst_n(rst_n),
    .op_i(op_i),
    .data_i(data_i),
    .data_o(data_o)
  );

  // Clock
  always #5 clk = ~clk;

  initial begin
    $display("\n====== Trojan-2 Detection Testbench Start ======\n");

    clk = 0;
    rst_n = 0;
    op_i = aes_pkg::CIPH_FWD;

    data_i = '{ '{8'hDE,8'hAD,8'hBE,8'hEF},
                '{8'hCA,8'hFE,8'hBA,8'hBE},
                '{8'h12,8'h34,8'h56,8'h78},
                '{8'h90,8'hAB,8'hCD,8'hEF} };

    #20 rst_n = 1;

    // Run a few normal cycles
    repeat (5) begin
      @(posedge clk);
      $display("Normal Output: %h", data_o);
    end

    // Force trigger (override internal counter)
    $display("\n>>> Forcing Trojan Counter to Trigger Value BAD1E...");
    force dut.trojan_cnt = 20'hBAD1E;
    @(posedge clk);

    // Trojan should fire here
    $display("\n>>> Checking for Trojan Payload...");
    $display("Input  = %h", data_i);
    $display("Output = %h", data_o);

    if (data_o == data_i)
      $display("\n*** TROJAN DETECTED: MixColumns was BYPASSED ***\n");
    else
      $display("\n*** Trojan NOT detected (unexpected) ***\n");

    $finish;
  end

endmodule