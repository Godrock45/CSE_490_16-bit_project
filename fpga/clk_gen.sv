`timescale 1ns / 1ps
module clk_gen (
    input logic clk_100,
    output logic clk_sys,
    output logic locked
);

    logic clkfb_out, clkfb_buf, clk_mmcm;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(10.0),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(10.0),
        .CLKFBOUT_PHASE(0.0),
        .CLKOUT0_DIVIDE_F(40.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKIN1(clk_100),
        .CLKFBIN(clkfb_buf),
        .CLKFBOUT(clkfb_out),
        .CLKFBOUTB(),
        .CLKOUT0(clk_mmcm),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .LOCKED(locked),
        .PWRDWN(1'b0),
        .RST(1'b0)
    );

    BUFG u_fb_buf (.I(clkfb_out), .O(clkfb_buf));
    BUFG u_clk_buf (.I(clk_mmcm), .O(clk_sys));

endmodule
