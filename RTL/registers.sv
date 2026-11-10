`timescale 1ns / 1ps
module registers #(
    parameter R0_ZERO = 0
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic we,
    input logic [3:0] rs1,
    input logic [3:0] rs2,
    input logic [3:0] rd,
    input logic [15:0] wd,
    output logic [15:0] rd1,
    output logic [15:0] rd2,
    input logic [3:0] dbg_sel,
    output logic [15:0] dbg_val
);

logic [15:0] regs [0:15];

always_comb begin
    rd1 = regs[rs1];
    rd2 = regs[rs2];
    dbg_val = regs[dbg_sel];
end

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < 16; i++) begin
            regs[i] <= 16'h0000;
        end
    end
    else if (en && we && !(R0_ZERO && rd == 4'd0)) begin
        regs[rd] <= wd;
    end
end

endmodule
