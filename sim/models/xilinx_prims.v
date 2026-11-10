`timescale 1ps / 1ps
module MMCME2_BASE #(
    parameter BANDWIDTH = "OPTIMIZED",
    parameter real CLKIN1_PERIOD = 10.0,
    parameter integer DIVCLK_DIVIDE = 1,
    parameter real CLKFBOUT_MULT_F = 5.0,
    parameter real CLKFBOUT_PHASE = 0.0,
    parameter real CLKOUT0_DIVIDE_F = 1.0,
    parameter real CLKOUT0_DUTY_CYCLE = 0.5,
    parameter real CLKOUT0_PHASE = 0.0,
    parameter STARTUP_WAIT = "FALSE"
)(
    input CLKIN1, CLKFBIN, PWRDWN, RST,
    output CLKFBOUT, CLKFBOUTB,
    output reg CLKOUT0,
    output CLKOUT0B, CLKOUT1, CLKOUT1B, CLKOUT2, CLKOUT2B, CLKOUT3, CLKOUT3B,
    output CLKOUT4, CLKOUT5, CLKOUT6,
    output reg LOCKED
);
    localparam real HALF_PS = CLKIN1_PERIOD * 1000.0 * DIVCLK_DIVIDE * CLKOUT0_DIVIDE_F
                              / CLKFBOUT_MULT_F / 2.0;
    initial begin
        CLKOUT0 = 1'b0;
        LOCKED = 1'b0;
        #(HALF_PS * 40.0) LOCKED = 1'b1;
    end
    always #(HALF_PS) CLKOUT0 = ~CLKOUT0;
    assign CLKFBOUT = CLKIN1;
endmodule

module BUFG (input I, output O);
    assign O = I;
endmodule
