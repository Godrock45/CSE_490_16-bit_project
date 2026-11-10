`timescale 1ns / 1ps
module rip (
    input logic OpA,
    input logic OpB,
    input logic cin,
    output logic sum,
    output logic cout
);

assign cout = (OpA & OpB) | (OpA & cin) | (OpB & cin);
assign sum = OpA ^ OpB ^ cin;

endmodule

module ripple #(
    parameter W = 16
)(
    input logic [W-1:0] A,
    input logic [W-1:0] B,
    input logic c_in,
    output logic c_out,
    output logic [W-1:0] sum
);

logic [W:0] carry;
assign carry[0] = c_in;

genvar i;
generate
    for (i = 0; i < W; i = i + 1) begin : fa
        rip u_fa (.OpA(A[i]), .OpB(B[i]), .cin(carry[i]), .sum(sum[i]), .cout(carry[i+1]));
    end
endgenerate

assign c_out = carry[W];

endmodule
