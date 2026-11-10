`timescale 1ns / 1ps
module decoder(
    input logic [15:0] instruct,
    output logic [3:0] opcode,
    output logic [3:0] rd,
    output logic [3:0] rs1,
    output logic [3:0] funct4,
    output logic [3:0] imm,
    output logic [11:0] addr
);

assign opcode = instruct[15:12];
assign rd = instruct[11:8];
assign rs1 = instruct[7:4];
assign funct4 = instruct[3:0];
assign imm = instruct[3:0];
assign addr = instruct[11:0];

endmodule
