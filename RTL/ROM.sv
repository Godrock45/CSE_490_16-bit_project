`timescale 1ns / 1ps
module ROME(
    input logic [15:0] PC,
    output logic [15:0] IR
);

logic [15:0] registan [0:127];

initial begin
    for (int i = 0; i < 128; i++) begin
        registan[i] = 16'h6FFF;
    end
    registan[0] = 16'h3105; // addi $s1, $s0, 5
    registan[1] = 16'h3203; // addi $s2, $s0, 3
    registan[2] = 16'h0120; // add $s1, $s2
    registan[3] = 16'h0211; // sub $s2, $s1
    registan[4] = 16'h330C; // addi $s3, $s0, -4
    registan[5] = 16'h0310; // add $s3, $s1
    registan[6] = 16'h3405; // addi $s4, $s0, 5
    registan[7] = 16'h0440; // add $s4, $s4
    registan[8] = 16'h3506; // addi $s5, $s0, 6
    registan[9] = 16'h0550; // add $s5, $s5
    registan[10] = 16'h0543; // and $s5, $s4
    registan[11] = 16'h0432; // sll $s4, $s3
    registan[12] = 16'h3607; // addi $s6, $s0, 7
    registan[13] = 16'h3663; // addi $s6, $s6, 3
    registan[14] = 16'h246E; // sw $s4, -2($s6)
    registan[15] = 16'h2560; // sw $s5, 0($s6)
    registan[16] = 16'h176E; // lw $s7, -2($s6)
    registan[17] = 16'h186F; // lw $s8, -1($s6)
    registan[18] = 16'h4741; // beq $s7, $s4, skip1 (0x28)
    registan[19] = 16'h3907; // addi $s9, $s0, 7
    registan[20] = 16'h4751; // beq $s7, $s5, skip2 (0x2C)
    registan[21] = 16'h3991; // addi $s9, $s9, 1
    registan[22] = 16'h5741; // bne $s7, $s4, skip3 (0x30)
    registan[23] = 16'h3991; // addi $s9, $s9, 1
    registan[24] = 16'h3A05; // addi $s10, $s0, 5
    registan[25] = 16'h3BB1; // addi $s11, $s11, 1
    registan[26] = 16'h0CB0; // add $s12, $s11
    registan[27] = 16'h5BAD; // bne $s11, $s10, loop (0x32)
    registan[28] = 16'h6001; // jmp over (0x3C)
    registan[29] = 16'h3D07; // addi $s13, $s0, 7
    registan[30] = 16'h2C62; // sw $s12, 2($s6)
    registan[31] = 16'h3E0F; // addi $s14, $s0, -1
    registan[32] = 16'h1F62; // lw $s15, 2($s6)
    registan[33] = 16'h6FFF; // jmp done (0x42)
end

assign IR = registan[PC[7:1]];

endmodule
