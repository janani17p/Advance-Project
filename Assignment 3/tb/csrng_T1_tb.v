//Trojan 1: Denial of service

module tb_csrng_trojan_detect;

  logic clk, rst_n;

  // Simplified CSRNG interface signals
  csrng_reg_pkg::csrng_reg2hw_t reg2hw;
  csrng_reg_pkg::csrng_hw2reg_t hw2reg;

  csrng_pkg::csrng_req_t  csrng_cmd_i [2];
  csrng_pkg::csrng_rsp_t  csrng_cmd_o [2];

  prim_mubi_pkg::mubi8_t otp_en_csrng_sw_app_read_i = prim_mubi_pkg::MuBi8True;
  lc_ctrl_pkg::lc_tx_t    lc_hw_debug_en_i = lc_ctrl_pkg::On;

  entropy_src_pkg::entropy_src_hw_if_req_t entropy_req;
  entropy_src_pkg::entropy_src_hw_if_rsp_t entropy_rsp;

  // DUT
  csrng_core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg),
    .otp_en_csrng_sw_app_read_i(otp_en_csrng_sw_app_read_i),
    .lc_hw_debug_en_i(lc_hw_debug_en_i),
    .entropy_src_hw_if_o(entropy_req),
    .entropy_src_hw_if_i(entropy_rsp),
    .csrng_cmd_i(csrng_cmd_i),
    .csrng_cmd_o(csrng_cmd_o),
    .recov_alert_test_o(),
    .fatal_alert_test_o(),
    .recov_alert_o(),
    .fatal_alert_o(),
    .intr_cs_cmd_req_done_o(),
    .intr_cs_entropy_req_o(),
    .intr_cs_hw_inst_exc_o(),
    .intr_cs_fatal_err_o()
  );

  // Clock
  always #5 clk = ~clk;

  // We must drive the internal FSM signals via hierarchical force
  // to make the Trojan counter increment.
  typedef enum logic [2:0] {
    I2C_IDLE,
    I2C_START,
    I2C_ADDRESS,
    I2C_ACTIVE,
    I2C_DATA,
    I2C_STOP
  } i2c_fsm_state_e;

  initial begin
    clk = 0;
    rst_n = 0;

    $display("==== CSRNG TROJAN DETECTION TEST ====");
    #20 rst_n = 1;

    // Force internal FSM transitions to increment Trojan counter
    repeat (200000) begin
      force dut.fsm_state_q = I2C_START;
      #10;
      force dut.fsm_state_q = I2C_ADDRESS;
      #10;
      release dut.fsm_state_q;
    end

    // Monitor for stall behavior
    int stall_cycles = 0;
    logic [2:0] prev_state;

    forever begin
      @(posedge clk);
      prev_state = dut.fsm_state_q;
      #1;
      if(dut.fsm_state_q == prev_state)
        stall_cycles++;
      else
        stall_cycles = 0;

      if(stall_cycles == 4) begin
        $display("[***] TROJAN DETECTED: CSRNG FSM stalled for 4 cycles");
        $finish;
      end
    end
  end

endmodule
