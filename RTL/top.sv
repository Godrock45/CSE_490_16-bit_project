`timescale 1ns / 1ps
module top_wire(
    input logic clk,
    input logic rst,
    input logic cpu_en,
    output logic [15:0] dbg_pc,
    output logic [15:0] dbg_instr,
    output logic dbg_reg_we,
    output logic [3:0] dbg_rd,
    output logic [15:0] dbg_wb_data,
    output logic dbg_mem_we,
    output logic [15:0] dbg_alu,
    input logic [3:0] dbg_reg_sel,
    output logic [15:0] dbg_reg_val,
    input logic [7:0] dbg_mem_addr,
    output logic [15:0] dbg_mem_val,
    output logic halt
);

    logic [15:0] PC_loc, next_PC_loc, PC_plus2_loc, target_loc;
    logic [15:0] IR_loc;
    logic [3:0] opcode_loc, rd_loc, rs1_loc, funct4_loc, imm4_loc;
    logic [11:0] jaddr_loc;
    logic [15:0] imm_ext_loc, jaddr_ext_loc, offset_loc, offset_x2_loc;
    logic RegWrite_loc, AluSrc_loc, MemRead_loc, MemWrite_loc, MemToReg_loc;
    logic Branch_loc, BranchNe_loc, Jump_loc, PCSrc_loc;
    logic [3:0] AluCtrl_loc;
    logic [15:0] rd1_loc, rd2_loc, OpB_loc, res_loc, mem_dat_loc, wd_loc;
    logic zero_loc;

    PrgCo ad (.clk(clk), .rst(rst), .pc_en(cpu_en), .next_pc(next_PC_loc), .pc(PC_loc));
    ROME dc (.PC(PC_loc), .IR(IR_loc));

    decoder tnt (
        .instruct(IR_loc),
        .opcode(opcode_loc),
        .rd(rd_loc),
        .rs1(rs1_loc),
        .funct4(funct4_loc),
        .imm(imm4_loc),
        .addr(jaddr_loc)
    );

    control pnp (
        .Opcode(opcode_loc),
        .funct4(funct4_loc),
        .RegWrite(RegWrite_loc),
        .AluSrc(AluSrc_loc),
        .MemRead(MemRead_loc),
        .MemWrite(MemWrite_loc),
        .AluCtrl(AluCtrl_loc),
        .MemToReg(MemToReg_loc),
        .Branch(Branch_loc),
        .BranchNe(BranchNe_loc),
        .Jump(Jump_loc)
    );

    registers npn (
        .clk(clk),
        .rst(rst),
        .en(cpu_en),
        .we(RegWrite_loc),
        .rs1(rs1_loc),
        .rs2(rd_loc),
        .rd(rd_loc),
        .wd(wd_loc),
        .rd1(rd1_loc),
        .rd2(rd2_loc),
        .dbg_sel(dbg_reg_sel),
        .dbg_val(dbg_reg_val)
    );

    sign_extend #(.IN_W(4), .OUT_W(16)) se_imm (.in(imm4_loc), .out(imm_ext_loc));
    sign_extend #(.IN_W(12), .OUT_W(16)) se_jmp (.in(jaddr_loc), .out(jaddr_ext_loc));

    mux2 #(.W(16)) alusrc_mux (.d0(rd2_loc), .d1(imm_ext_loc), .sel(AluSrc_loc), .y(OpB_loc));

    ALU tsmc (.OpA(rd1_loc), .OpB(OpB_loc), .ALUCtrl(AluCtrl_loc), .Res(res_loc), .Zero(zero_loc));

    memory meme (
        .clk(clk),
        .rst(rst),
        .en(cpu_en),
        .addr(res_loc),
        .dat(rd2_loc),
        .write_ena(MemWrite_loc),
        .read_ena(MemRead_loc),
        .mem_dat(mem_dat_loc),
        .dbg_addr(dbg_mem_addr),
        .dbg_dat(dbg_mem_val)
    );

    mux2 #(.W(16)) wb_mux (.d0(res_loc), .d1(mem_dat_loc), .sel(MemToReg_loc), .y(wd_loc));

    ripple #(.W(16)) pc_add (.A(PC_loc), .B(16'd2), .c_in(1'b0), .c_out(), .sum(PC_plus2_loc));

    mux2 #(.W(16)) off_mux (.d0(imm_ext_loc), .d1(jaddr_ext_loc), .sel(Jump_loc), .y(offset_loc));
    shift_left1 #(.W(16)) off_shl (.in(offset_loc), .out(offset_x2_loc));
    ripple #(.W(16)) tgt_add (.A(PC_plus2_loc), .B(offset_x2_loc), .c_in(1'b0), .c_out(), .sum(target_loc));

    branch_logic brl (.Branch(Branch_loc), .BranchNe(BranchNe_loc), .Jump(Jump_loc), .Zero(zero_loc), .PCSrc(PCSrc_loc));

    mux2 #(.W(16)) pc_mux (.d0(PC_plus2_loc), .d1(target_loc), .sel(PCSrc_loc), .y(next_PC_loc));

    comparator halt_cmp (.OpA(next_PC_loc), .OpB(PC_loc), .funct3(3'b000), .cmp(halt));

    assign dbg_pc = PC_loc;
    assign dbg_instr = IR_loc;
    assign dbg_reg_we = RegWrite_loc;
    assign dbg_rd = rd_loc;
    assign dbg_wb_data = wd_loc;
    assign dbg_mem_we = MemWrite_loc;
    assign dbg_alu = res_loc;

endmodule
