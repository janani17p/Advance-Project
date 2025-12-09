Trojan 1: Denial of Service

module tb_trojan_detect;

  logic clk, rst_n;
  int golden_lat, trojan_lat;

  // Golden AES core (clean)
  aes_core golden (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rst_shadowed_ni(1'b1),
    /* other ports tied off or driven */
  );

  // Trojan AES core (your modified version)
  aes_core trojan (
    .clk_i(clk),
    .rst_ni(rst_n),
    .rst_shadowed_ni(1'b1),
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    #20 rst_n = 1;

    // Apply same input to both
    load_key_and_data();

    fork
      begin
        wait(golden.cipher_out_valid);
        golden_lat = $time;
      end
      begin
        wait(trojan.cipher_out_valid);
        trojan_lat = $time;
      end
    join

    if (trojan_lat != golden_lat) begin
      $display("TROJAN DETECTED!");
      $display("Golden latency = %0d", golden_lat);
      $display("Trojan latency = %0d", trojan_lat);
      $display("Latency difference = %0d cycles", 
                (trojan_lat - golden_lat) / 10);
    end else begin
      $display("No Trojan detected.");
    end

    $finish;
  end

endmodule
