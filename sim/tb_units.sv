`timescale 1ns / 1ps
module tb_units;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    int errors = 0, checks = 0;
    int s_err, s_chk;
    int seed = 490;

    task automatic check(input string what, input logic [15:0] got, input logic [15:0] exp);
        checks++;
        if (got !== exp) begin
            errors++;
            if (errors <= 30)
                $display("FAIL  %s: got %04h, expected %04h  (t=%0t)", what, got, exp, $time);
        end
    endtask

    task automatic begin_section();
        s_err = errors;
        s_chk = checks;
    endtask

    task automatic end_section(input string name);
        $display("  %-14s %7d checks  %0d mismatches", name, checks - s_chk, errors - s_err);
    endtask

    function automatic logic [15:0] rnd16();
        return $random(seed);
    endfunction

    logic [15:0] alu_a, alu_b, alu_res;
    logic [3:0] alu_ctrl;
    logic alu_zero;
    ALU u_alu (.OpA(alu_a), .OpB(alu_b), .ALUCtrl(alu_ctrl), .Res(alu_res), .Zero(alu_zero));

    logic [3:0] se4_in; logic [15:0] se4_out;
    logic [11:0] se12_in; logic [15:0] se12_out;
    sign_extend #(.IN_W(4), .OUT_W(16)) u_se4 (.in(se4_in), .out(se4_out));
    sign_extend #(.IN_W(12), .OUT_W(16)) u_se12 (.in(se12_in), .out(se12_out));

    logic [15:0] add_a, add_b, add_s;
    logic add_ci, add_co;
    ripple #(.W(16)) u_add (.A(add_a), .B(add_b), .c_in(add_ci), .c_out(add_co), .sum(add_s));

    logic [15:0] mx_d0, mx_d1, mx_y, sh_in, sh_out;
    logic mx_sel;
    mux2 #(.W(16)) u_mux (.d0(mx_d0), .d1(mx_d1), .sel(mx_sel), .y(mx_y));
    shift_left1 #(.W(16)) u_shl (.in(sh_in), .out(sh_out));
    logic bl_br, bl_bne, bl_j, bl_z, bl_src;
    branch_logic u_bl (.Branch(bl_br), .BranchNe(bl_bne), .Jump(bl_j), .Zero(bl_z), .PCSrc(bl_src));
    logic [15:0] cmp_a, cmp_b;
    logic cmp_eq;
    comparator u_cmp (.OpA(cmp_a), .OpB(cmp_b), .funct3(3'b000), .cmp(cmp_eq));

    logic [3:0] c_op, c_fn, c_alu;
    logic c_rw, c_as, c_mr, c_mw, c_m2r, c_br, c_bne, c_j;
    control u_ctrl (.Opcode(c_op), .funct4(c_fn), .RegWrite(c_rw), .AluSrc(c_as), .MemRead(c_mr),
                    .MemWrite(c_mw), .AluCtrl(c_alu), .MemToReg(c_m2r), .Branch(c_br),
                    .BranchNe(c_bne), .Jump(c_j));

    logic [15:0] d_ir;
    logic [3:0] d_op, d_rd, d_rs, d_fn, d_imm;
    logic [11:0] d_addr;
    decoder u_dec (.instruct(d_ir), .opcode(d_op), .rd(d_rd), .rs1(d_rs), .funct4(d_fn),
                   .imm(d_imm), .addr(d_addr));

    logic rf_rst = 1'b0, rf_en = 1'b1, rf_we = 1'b0;
    logic [3:0] rf_rs1 = 4'd0, rf_rs2 = 4'd0, rf_rd = 4'd0, rf_dsel = 4'd0;
    logic [15:0] rf_wd = 16'h0, rf_rd1, rf_rd2, rf_dval, rz_rd1, rz_rd2, rz_dval;
    registers #(.R0_ZERO(0)) u_rf (.clk(clk), .rst(rf_rst), .en(rf_en), .we(rf_we), .rs1(rf_rs1),
                                   .rs2(rf_rs2), .rd(rf_rd), .wd(rf_wd), .rd1(rf_rd1), .rd2(rf_rd2),
                                   .dbg_sel(rf_dsel), .dbg_val(rf_dval));
    registers #(.R0_ZERO(1)) u_rz (.clk(clk), .rst(rf_rst), .en(rf_en), .we(rf_we), .rs1(rf_rs1),
                                   .rs2(rf_rs2), .rd(rf_rd), .wd(rf_wd), .rd1(rz_rd1), .rd2(rz_rd2),
                                   .dbg_sel(rf_dsel), .dbg_val(rz_dval));

    logic dm_rst = 1'b0, dm_en = 1'b1, dm_we = 1'b0, dm_re = 1'b0;
    logic [15:0] dm_addr = 16'h0, dm_din = 16'h0, dm_dout, dm_dval;
    logic [7:0] dm_daddr = 8'h0;
    memory u_dm (.clk(clk), .rst(dm_rst), .en(dm_en), .addr(dm_addr), .dat(dm_din), .write_ena(dm_we),
                 .read_ena(dm_re), .mem_dat(dm_dout), .dbg_addr(dm_daddr), .dbg_dat(dm_dval));

    logic pc_rst = 1'b0, pc_en = 1'b0;
    logic [15:0] pc_next = 16'h0, pc_q;
    PrgCo u_pc (.clk(clk), .rst(pc_rst), .pc_en(pc_en), .next_pc(pc_next), .pc(pc_q));

    logic [15:0] rom_pc = 16'h0, rom_ir;
    ROME u_rom (.PC(rom_pc), .IR(rom_ir));

    function automatic logic [15:0] ref_alu(input logic [3:0] op, input logic [15:0] a, input logic [15:0] b);
        logic [31:0] wide;
        logic [15:0] v;
        case (op)
            4'h0: return a + b;
            4'h1: return a + (~b) + 16'd1;
            4'h2: begin
                if (a > 16'd15) return 16'h0000;
                wide = {16'h0, b} * (32'd1 << a);
                return wide[15:0];
            end
            4'h3: return a & b;
            4'h4: return (a[15] != b[15]) ? {15'b0, a[15]} : {15'b0, (a < b)};
            4'h5: return a ^ b;
            4'h6: return (a > 16'd15) ? 16'h0000 : (b / (16'd1 << a));
            4'h7: begin
                v = b;
                for (int k = 0; k < 16; k++) if (k < a) v = {v[15], v[15:1]};
                return v;
            end
            4'h8: return a | b;
            default: return 16'h0000;
        endcase
    endfunction

    function automatic logic [7:0] ref_ctrl(input logic [3:0] op, input logic [3:0] fn);
        case (op)
            4'h0: return {(fn <= 4'h8), 7'b0000000};
            4'h1: return 8'b1110_1000;
            4'h2: return 8'b0101_0000;
            4'h3: return 8'b1100_0000;
            4'h4: return 8'b0000_0100;
            4'h5: return 8'b0000_0010;
            4'h6: return 8'b0000_0001;
            default: return 8'b0000_0000;
        endcase
    endfunction

    task automatic alu_vec(input logic [3:0] op, input logic [15:0] a, input logic [15:0] b,
                           input logic [15:0] exp, input string name);
        alu_ctrl = op; alu_a = a; alu_b = b;
        #10;
        check(name, alu_res, exp);
        check({name, " zero"}, {15'b0, alu_zero}, {15'b0, (exp == 16'h0)});
    endtask

    logic [15:0] shadow_r [0:15];
    logic [7:0] shadow_m [0:255];
    logic [7:0] hb;
    logic [15:0] v16;
    int a8;

    initial begin
        $dumpfile("tb_units.vcd");
        $dumpvars(0, tb_units);
        $display("unit tests");

        begin_section();
        alu_vec(4'h0, 16'h0005, 16'h0003, 16'h0008, "add 5+3");
        alu_vec(4'h0, 16'h7FFF, 16'h0001, 16'h8000, "add 7FFF+1");
        alu_vec(4'h0, 16'hFFFF, 16'h0001, 16'h0000, "add FFFF+1");
        alu_vec(4'h1, 16'h0008, 16'h0003, 16'h0005, "sub 8-3");
        alu_vec(4'h1, 16'h0003, 16'h0008, 16'hFFFB, "sub 3-8");
        alu_vec(4'h1, 16'h0005, 16'h0005, 16'h0000, "sub 5-5");
        alu_vec(4'h2, 16'h0004, 16'h005A, 16'h05A0, "sll 005A<<4");
        alu_vec(4'h2, 16'h0001, 16'h8001, 16'h0002, "sll 8001<<1");
        alu_vec(4'h2, 16'h0010, 16'hFFFF, 16'h0000, "sll by 16");
        alu_vec(4'h3, 16'h000C, 16'h000A, 16'h0008, "and 000C&000A");
        alu_vec(4'h3, 16'hF0F0, 16'h0FF0, 16'h00F0, "and F0F0&0FF0");
        alu_vec(4'h4, 16'hFFFF, 16'h0005, 16'h0001, "slt -1<5");
        alu_vec(4'h5, 16'hFF00, 16'h0FF0, 16'hF0F0, "xor");
        alu_vec(4'h6, 16'h000F, 16'h8000, 16'h0001, "srl 8000>>15");
        alu_vec(4'h7, 16'h000F, 16'h8000, 16'hFFFF, "sra 8000>>>15");
        alu_vec(4'h8, 16'hF000, 16'h000F, 16'hF00F, "or");
        $dumpoff;
        for (int i = 0; i < 40000; i++) begin
            alu_ctrl = i[3:0];
            alu_a = (i % 3 == 0) ? {12'h0, rnd16() & 16'h001F} : rnd16();
            alu_b = rnd16();
            #1;
            check("ALU random", alu_res, ref_alu(alu_ctrl, alu_a, alu_b));
            check("ALU zero", {15'b0, alu_zero}, {15'b0, (ref_alu(alu_ctrl, alu_a, alu_b) == 16'h0)});
        end
        $dumpon;
        end_section("ALU");

        begin_section();
        for (int i = 0; i < 16; i++) begin
            se4_in = i[3:0];
            #5;
            check("sext4", se4_out, (i < 8) ? i[15:0] : (i[15:0] - 16'd16));
        end
        $dumpoff;
        for (int i = 0; i < 4096; i++) begin
            se12_in = i[11:0];
            #1;
            check("sext12", se12_out, (i < 2048) ? i[15:0] : (i[15:0] - 16'd4096));
        end
        $dumpon;
        end_section("sign_extend");

        begin_section();
        add_a = 16'h0000; add_b = 16'h0002; add_ci = 1'b0; #10; check("PC+2", add_s, 16'h0002);
        add_a = 16'h0040; add_b = 16'h0002; #10; check("PC+2", add_s, 16'h0042);
        add_a = 16'h0038; add_b = 16'hFFFA; #10; check("target 38-6", add_s, 16'h0032);
        add_a = 16'hFFFF; add_b = 16'h0001; #10; check("carry out", {15'b0, add_co}, 16'h0001);
        $dumpoff;
        for (int i = 0; i < 20000; i++) begin
            add_a = rnd16(); add_b = rnd16(); add_ci = i[0];
            #1;
            check("ripple sum", add_s, add_a + add_b + {15'b0, add_ci});
            check("ripple cout", {15'b0, add_co}, {15'b0, ({1'b0, add_a} + {1'b0, add_b} + {16'b0, add_ci}) >> 16});
        end
        $dumpon;
        end_section("ripple adder");

        begin_section();
        for (int i = 0; i < 2000; i++) begin
            mx_d0 = rnd16(); mx_d1 = rnd16(); mx_sel = i[0]; sh_in = rnd16();
            cmp_a = rnd16(); cmp_b = i[1] ? cmp_a : rnd16();
            #1;
            check("mux2", mx_y, mx_sel ? mx_d1 : mx_d0);
            check("shift_left1", sh_out, sh_in * 16'd2);
            check("comparator", {15'b0, cmp_eq}, {15'b0, (cmp_a == cmp_b)});
        end
        for (int i = 0; i < 16; i++) begin
            {bl_br, bl_bne, bl_j, bl_z} = i[3:0];
            #5;
            check("branch_logic", {15'b0, bl_src}, {15'b0, (bl_j || (bl_br && bl_z) || (bl_bne && !bl_z))});
        end
        end_section("mux/shift/br");

        begin_section();
        for (int i = 0; i < 256; i++) begin
            c_op = i[7:4]; c_fn = i[3:0];
            #2;
            check($sformatf("control op=%h fn=%h", c_op, c_fn),
                  {8'h00, c_rw, c_as, c_mr, c_mw, c_m2r, c_br, c_bne, c_j}, {8'h00, ref_ctrl(c_op, c_fn)});
            if (c_op == 4'h0) check("AluCtrl R", {12'h0, c_alu}, {12'h0, c_fn});
            if (c_op == 4'h1 || c_op == 4'h2 || c_op == 4'h3) check("AluCtrl add", {12'h0, c_alu}, 16'h0000);
            if (c_op == 4'h4 || c_op == 4'h5) check("AluCtrl sub", {12'h0, c_alu}, 16'h0001);
        end
        end_section("control");

        begin_section();
        for (int i = 0; i < 5000; i++) begin
            d_ir = rnd16();
            #1;
            check("opcode", {12'h0, d_op}, {12'h0, d_ir[15:12]});
            check("rt/rd", {12'h0, d_rd}, {12'h0, d_ir[11:8]});
            check("rs", {12'h0, d_rs}, {12'h0, d_ir[7:4]});
            check("funct", {12'h0, d_fn}, {12'h0, d_ir[3:0]});
            check("imm", {12'h0, d_imm}, {12'h0, d_ir[3:0]});
            check("addr", {4'h0, d_addr}, {4'h0, d_ir[11:0]});
        end
        end_section("decoder");

        begin_section();
        @(negedge clk) rf_rst = 1'b1;
        @(negedge clk) rf_rst = 1'b0;
        for (int i = 0; i < 16; i++) begin
            rf_rs1 = i[3:0]; rf_rs2 = 4'd15 - i[3:0]; rf_dsel = i[3:0];
            #1;
            check("reset rd1", rf_rd1, 16'h0); check("reset rd2", rf_rd2, 16'h0); check("reset dbg", rf_dval, 16'h0);
        end
        for (int i = 0; i < 16; i++) begin
            @(negedge clk);
            rf_we = 1'b1; rf_rd = i[3:0]; rf_wd = 16'h1111 * i[15:0];
            shadow_r[i] = 16'h1111 * i[15:0];
        end
        @(negedge clk) rf_we = 1'b0;
        for (int i = 0; i < 16; i++) begin
            rf_rs1 = i[3:0]; rf_rs2 = 4'd15 - i[3:0]; rf_dsel = i[3:0];
            #1;
            check("read rd1", rf_rd1, shadow_r[i]);
            check("read rd2", rf_rd2, shadow_r[15 - i]);
            check("read dbg", rf_dval, shadow_r[i]);
            check("R0_ZERO copy", rz_rd1, (i == 0) ? 16'h0000 : shadow_r[i]);
        end
        @(negedge clk) begin rf_we = 1'b0; rf_rd = 4'd3; rf_wd = 16'hDEAD; end
        @(negedge clk) begin rf_we = 1'b1; rf_en = 1'b0; end
        @(negedge clk) begin rf_we = 1'b0; rf_en = 1'b1; rf_rs1 = 4'd3; end
        #1 check("write blocked", rf_rd1, shadow_r[3]);
        @(negedge clk) begin rf_we = 1'b1; rf_rd = 4'd5; rf_wd = 16'hBEEF; rf_rs1 = 4'd5; end
        #1 check("old value before edge", rf_rd1, shadow_r[5]);
        @(posedge clk) #1 check("new value after edge", rf_rd1, 16'hBEEF);
        shadow_r[5] = 16'hBEEF;
        @(negedge clk) rf_we = 1'b0;
        $dumpoff;
        for (int i = 0; i < 3000; i++) begin
            @(negedge clk);
            check("rf random rd1", rf_rd1, shadow_r[rf_rs1]);
            check("rf random rd2", rf_rd2, shadow_r[rf_rs2]);
            rf_we = rnd16() & 1; rf_rd = rnd16(); rf_wd = rnd16(); rf_rs1 = rnd16(); rf_rs2 = rnd16();
            rf_en = (rnd16() & 3) != 0;
            if (rf_we && rf_en) shadow_r[rf_rd] = rf_wd;
        end
        @(negedge clk) begin rf_we = 1'b0; rf_en = 1'b1; end
        $dumpon;
        end_section("register file");

        begin_section();
        for (int i = 0; i < 256; i++) shadow_m[i] = 8'h00;
        for (int i = 0; i < 256; i++) check("power-up zero", {8'h0, u_dm.memistan[i]}, 16'h0);
        @(negedge clk) begin dm_we = 1'b1; dm_addr = 16'h0010; dm_din = 16'h1234; end
        @(negedge clk) begin dm_we = 1'b1; dm_addr = 16'h0021; dm_din = 16'hABCD; end
        @(negedge clk) begin dm_we = 1'b1; dm_addr = 16'h00FF; dm_din = 16'hBEEF; end
        @(negedge clk) begin dm_we = 1'b0; dm_re = 1'b1; dm_addr = 16'h0010; end
        #1 check("read 0x10", dm_dout, 16'h1234);
        check("big-endian hi byte", {8'h0, u_dm.memistan[8'h10]}, 16'h0012);
        check("big-endian lo byte", {8'h0, u_dm.memistan[8'h11]}, 16'h0034);
        @(negedge clk) dm_addr = 16'h0021;
        #1 check("read unaligned 0x21", dm_dout, 16'hABCD);
        @(negedge clk) dm_addr = 16'h0020;
        #1 check("read 0x20 = {00,AB}", dm_dout, 16'h00AB);
        @(negedge clk) dm_addr = 16'h00FF;
        #1 check("read wrap 0xFF", dm_dout, 16'hBEEF);
        check("wrap byte 0x00", {8'h0, u_dm.memistan[8'h00]}, 16'h00EF);
        @(negedge clk) dm_addr = 16'h0110;
        #1 check("high address bits ignored", dm_dout, 16'h1234);
        @(negedge clk) dm_re = 1'b0;
        #1 check("read_ena = 0 gives 0", dm_dout, 16'h0000);
        @(negedge clk) begin dm_we = 1'b1; dm_en = 1'b0; dm_addr = 16'h0010; dm_din = 16'h5555; end
        @(negedge clk) begin dm_we = 1'b0; dm_en = 1'b1; dm_re = 1'b1; end
        #1 check("en = 0 blocks write", dm_dout, 16'h1234);
        @(negedge clk) begin dm_we = 1'b1; dm_rst = 1'b1; dm_din = 16'h6666; end
        @(negedge clk) begin dm_we = 1'b0; dm_rst = 1'b0; end
        #1 check("rst blocks write", dm_dout, 16'h1234);
        shadow_m[8'h10] = 8'h12; shadow_m[8'h11] = 8'h34; shadow_m[8'h21] = 8'hAB;
        shadow_m[8'h22] = 8'hCD; shadow_m[8'hFF] = 8'hBE; shadow_m[8'h00] = 8'hEF;
        $dumpoff;
        for (int i = 0; i < 4000; i++) begin
            @(negedge clk);
            a8 = dm_addr[7:0];
            check("dm random read", dm_dout, dm_re ? {shadow_m[a8[7:0]], shadow_m[(a8 + 1) % 256]} : 16'h0000);
            check("dm debug read", dm_dval, {shadow_m[dm_daddr], shadow_m[dm_daddr + 8'd1]});
            dm_we = (rnd16() & 3) == 0; dm_re = rnd16() & 1; dm_addr = rnd16(); dm_din = rnd16();
            dm_daddr = rnd16();
            if (dm_we) begin
                shadow_m[dm_addr[7:0]] = dm_din[15:8];
                shadow_m[dm_addr[7:0] + 8'd1] = dm_din[7:0];
            end
        end
        @(negedge clk) dm_we = 1'b0;
        $dumpon;
        end_section("data memory");

        begin_section();
        @(negedge clk) pc_rst = 1'b1;
        @(negedge clk) begin pc_rst = 1'b0; check("PC reset", pc_q, 16'h0000); end
        @(negedge clk) begin pc_en = 1'b1; pc_next = 16'h0002; end
        @(negedge clk) begin check("PC load", pc_q, 16'h0002); pc_next = 16'h0032; end
        @(negedge clk) begin check("PC load", pc_q, 16'h0032); pc_en = 1'b0; pc_next = 16'h1234; end
        @(negedge clk) begin check("PC hold", pc_q, 16'h0032); pc_en = 1'b1; pc_rst = 1'b1; end
        @(negedge clk) begin check("reset beats enable", pc_q, 16'h0000); pc_rst = 1'b0; pc_en = 1'b0; end
        $dumpoff;
        v16 = 16'h0000;
        for (int i = 0; i < 2000; i++) begin
            @(negedge clk);
            check("PC random", pc_q, v16);
            pc_en = rnd16() & 1; pc_next = rnd16();
            if (pc_en) v16 = pc_next;
        end
        $dumpon;
        end_section("PC");

        begin_section();
        for (int k = 0; k < 128; k++) begin
            rom_pc = 2 * k; #1 check("ROM even", rom_ir, u_rom.registan[k]);
            rom_pc = 2 * k + 1; #1 check("ROM odd byte -> same word", rom_ir, u_rom.registan[k]);
            rom_pc = 2 * k + 256; #1 check("ROM wraps at 256", rom_ir, u_rom.registan[k]);
        end
        rom_pc = 16'h0000; #1 check("ROM word 0 = addi $s1,$s0,5", rom_ir, 16'h3105);
        end_section("instr memory");

        $display("");
        if (errors == 0) $display("PASS: tb_units  %0d checks, 0 mismatches", checks);
        else $display("FAIL: tb_units  %0d checks, %0d mismatches", checks, errors);
        $finish;
    end
endmodule
