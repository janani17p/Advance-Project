//Trojan 2: functionality change

module csrng_trojan_detect_tb;

  logic clk, rst_n;

  // Stimulus
  csrng_req_t   csrng_cmd_i_golden, csrng_cmd_i_trojan;
  csrng_rsp_t   csrng_cmd_o_golden, csrng_cmd_o_trojan;

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // Reset
  initial begin
    rst_n = 0;
    #40 rst_n = 1;
  end

  // Instantiate GOLDEN CSRNG
  csrng_core golden_csrng (
    .clk_i(clk),
    .rst_ni(rst_n),
    .csrng_cmd_i('{default:csrng_cmd_i_golden}),
    .csrng_cmd_o(csrng_cmd_o_golden),
    .*
  );

  // Instantiate TROJAN CSRNG
  csrng_core trojan_csrng (
    .clk_i(clk),
    .rst_ni(rst_n),
    .csrng_cmd_i('{default:csrng_cmd_i_trojan}),
    .csrng_cmd_o(csrng_cmd_o_trojan),
    .*
  );

  // Compare outputs
  always @(posedge clk) begin
    if (rst_n) begin
      if (csrng_cmd_o_golden.genbits_valid !== csrng_cmd_o_trojan.genbits_valid) begin
        $display("ERROR: GENBITS_VALID diverged at time %0t", $time);
        $stop;
      end

      if (csrng_cmd_o_golden.genbits_bus !== csrng_cmd_o_trojan.genbits_bus) begin
        $display("ERROR: GENBITS output mismatch at time %0t", $time);
        $stop;
      end
    end
  end

  // Simple stimulus
  initial begin
    csrng_cmd_i_golden = '0;
    csrng_cmd_i_trojan = '0;

    @(posedge rst_n);
    #20;

    // Issue INIT command to both
    csrng_cmd_i_golden.csrng_req_valid = 1;
    csrng_cmd_i_trojan.csrng_req_valid = 1;

    csrng_cmd_i_golden.csrng_req_bus = 32'h00010001;
    csrng_cmd_i_trojan.csrng_req_bus = 32'h00010001;

    #10;
    csrng_cmd_i_golden.csrng_req_valid = 0;
    csrng_cmd_i_trojan.csrng_req_valid = 0;

    // Wait for responses
    repeat (200) @(posedge clk);

    $display("INFO: Trojan detection test completed");
    $finish;
  end

endmodule
