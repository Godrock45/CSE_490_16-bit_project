`timescale 1ns / 1ps
module ALU(
    input logic [15:0] OpA,
    input logic [15:0] OpB,
    input logic [3:0] ALUCtrl,
    output logic [15:0] Res,
    output logic Zero
);

always_comb begin
    case (ALUCtrl)
    4'b0000: Res = OpA + OpB;
    4'b0001: Res = OpA - OpB;
    4'b0010: Res = OpB << OpA;
    4'b0011: Res = OpA & OpB;
    4'b0100: Res = {15'b0, ($signed(OpA) < $signed(OpB))};
    4'b0101: Res = OpA ^ OpB;
    4'b0110: Res = OpB >> OpA;
    4'b0111: Res = $signed(OpB) >>> OpA;
    4'b1000: Res = OpA | OpB;
    default: Res = 16'h0000;
    endcase
end

assign Zero = (Res == 16'h0000);

endmodule
