`timescale 1ns / 1ps
module branch_logic(
    input logic Branch,
    input logic BranchNe,
    input logic Jump,
    input logic Zero,
    output logic PCSrc
);

assign PCSrc = Jump | (Branch & Zero) | (BranchNe & ~Zero);

endmodule
