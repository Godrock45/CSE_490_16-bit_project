`timescale 1ns / 1ps
module control(
    input logic [3:0] Opcode,
    input logic [3:0] funct4,
    output logic RegWrite,
    output logic AluSrc,
    output logic MemRead,
    output logic MemWrite,
    output logic [3:0] AluCtrl,
    output logic MemToReg,
    output logic Branch,
    output logic BranchNe,
    output logic Jump
);

always_comb begin
    RegWrite=1'b0;
    AluSrc=1'b0;
    MemRead=1'b0;
    MemWrite=1'b0;
    AluCtrl=4'b0000;
    MemToReg=1'b0;
    Branch=1'b0;
    BranchNe=1'b0;
    Jump=1'b0;
    case (Opcode)
        4'b0000:begin
            AluCtrl=funct4;
            RegWrite=(funct4<=4'b1000);
        end
        4'b0001: begin
            AluSrc=1'b1;
            MemRead=1'b1;
            MemToReg=1'b1;
            RegWrite=1'b1;
        end
        4'b0010: begin
            AluSrc=1'b1;
            MemWrite=1'b1;
        end
        4'b0011: begin
            AluSrc=1'b1;
            RegWrite=1'b1;
        end
        4'b0100: begin
            AluCtrl=4'b0001;
            Branch=1'b1;
        end
        4'b0101: begin
            AluCtrl=4'b0001;
            BranchNe=1'b1;
        end
        4'b0110: begin
            Jump=1'b1;
        end
        default:;
    endcase
end

endmodule
