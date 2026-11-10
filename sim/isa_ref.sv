`timescale 1ns / 1ps
module isa_ref #(
    parameter R0_ZERO = 0
);
    logic [15:0] pc;
    logic [15:0] r [0:15];
    logic [7:0] mem [0:255];
    logic [15:0] imem [0:127];

    logic wr_en;
    logic [3:0] wr_reg;
    logic [15:0] wr_val;
    logic st_en;
    logic [7:0] st_addr;
    logic [15:0] st_val;
    logic taken;
    logic [15:0] last_ir;
    logic [15:0] last_pc;

    function automatic logic [15:0] sx4(input logic [3:0] v);
        return {{12{v[3]}}, v};
    endfunction

    function automatic logic [15:0] sx12(input logic [11:0] v);
        return {{4{v[11]}}, v};
    endfunction

    task automatic reset();
        pc = 16'h0000;
        for (int i = 0; i < 16; i++) r[i] = 16'h0000;
    endtask

    task automatic write_reg(input logic [3:0] t, input logic [15:0] v);
        wr_en = 1'b1;
        wr_reg = t;
        wr_val = v;
        if (!(R0_ZERO && t == 4'd0)) r[t] = v;
    endtask

    function automatic logic [15:0] shift_left(input logic [15:0] v, input logic [15:0] n);
        for (int k = 0; k < 16; k++) begin
            if (k < n) v = {v[14:0], 1'b0};
        end
        return v;
    endfunction

    function automatic logic [15:0] shift_right_arith(input logic [15:0] v, input logic [15:0] n);
        for (int k = 0; k < 16; k++) begin
            if (k < n) v = {v[15], v[15:1]};
        end
        return v;
    endfunction

    task automatic step();
        logic [15:0] ir, rs_v, rt_v, npc, ea, w, simm, boff;
        logic [3:0] op, t, s, f;
        logic [7:0] hi, lo;
        ir = imem[pc[7:1]];
        last_ir = ir;
        last_pc = pc;
        op = ir[15:12];
        t = ir[11:8];
        s = ir[7:4];
        f = ir[3:0];
        simm = sx4(f);
        boff = {simm[14:0], 1'b0};
        rs_v = r[s];
        rt_v = r[t];
        npc = pc + 16'd2;
        wr_en = 1'b0;
        st_en = 1'b0;
        taken = 1'b0;
        case (op)
            4'h0: case (f)
                4'h0: write_reg(t, rs_v + rt_v);
                4'h1: write_reg(t, rs_v - rt_v);
                4'h2: write_reg(t, shift_left(rt_v, rs_v));
                4'h3: write_reg(t, rs_v & rt_v);
                4'h4: write_reg(t, ($signed(rs_v) < $signed(rt_v)) ? 16'd1 : 16'd0);
                4'h5: write_reg(t, rs_v ^ rt_v);
                4'h6: write_reg(t, (rs_v > 16'd15) ? 16'h0000 : (rt_v >> rs_v[3:0]));
                4'h7: write_reg(t, shift_right_arith(rt_v, rs_v));
                4'h8: write_reg(t, rs_v | rt_v);
                default:;
            endcase
            4'h1: begin
                ea = rs_v + sx4(f);
                hi = ea[7:0];
                lo = ea[7:0] + 8'd1;
                write_reg(t, {mem[hi], mem[lo]});
            end
            4'h2: begin
                ea = rs_v + sx4(f);
                hi = ea[7:0];
                lo = ea[7:0] + 8'd1;
                mem[hi] = rt_v[15:8];
                mem[lo] = rt_v[7:0];
                st_en = 1'b1;
                st_addr = hi;
                st_val = rt_v;
            end
            4'h3: write_reg(t, rs_v + sx4(f));
            4'h4: if (rt_v == rs_v) begin
                npc = npc + boff;
                taken = 1'b1;
            end
            4'h5: if (rt_v != rs_v) begin
                npc = npc + boff;
                taken = 1'b1;
            end
            4'h6: begin
                w = sx12(ir[11:0]);
                npc = npc + {w[14:0], 1'b0};
                taken = 1'b1;
            end
            default:;
        endcase
        pc = npc;
    endtask

    function automatic string disasm(input logic [15:0] ir, input logic [15:0] at);
        logic [3:0] op, t, s, f;
        logic [15:0] tgt, simm;
        int off;
        op = ir[15:12]; t = ir[11:8]; s = ir[7:4]; f = ir[3:0];
        simm = sx4(f);
        off = $signed(simm);
        case (op)
            4'h0: case (f)
                4'h0: return $sformatf("add  $s%0d, $s%0d", t, s);
                4'h1: return $sformatf("sub  $s%0d, $s%0d", t, s);
                4'h2: return $sformatf("sll  $s%0d, $s%0d", t, s);
                4'h3: return $sformatf("and  $s%0d, $s%0d", t, s);
                4'h4: return $sformatf("slt  $s%0d, $s%0d", t, s);
                4'h5: return $sformatf("xor  $s%0d, $s%0d", t, s);
                4'h6: return $sformatf("srl  $s%0d, $s%0d", t, s);
                4'h7: return $sformatf("sra  $s%0d, $s%0d", t, s);
                4'h8: return $sformatf("or   $s%0d, $s%0d", t, s);
                default: return $sformatf("nop  (%04h)", ir);
            endcase
            4'h1: return $sformatf("lw   $s%0d, %0d($s%0d)", t, off, s);
            4'h2: return $sformatf("sw   $s%0d, %0d($s%0d)", t, off, s);
            4'h3: return $sformatf("addi $s%0d, $s%0d, %0d", t, s, off);
            4'h4, 4'h5: begin
                tgt = at + 16'd2 + {simm[14:0], 1'b0};
                return $sformatf("%s  $s%0d, $s%0d, %0d (->%02h)", (op == 4'h4) ? "beq" : "bne", t, s, off, tgt);
            end
            4'h6: begin
                tgt = sx12(ir[11:0]);
                tgt = at + 16'd2 + {tgt[14:0], 1'b0};
                if (tgt == at) return "jmp  -1 (halt)";
                return $sformatf("jmp  %0d (->%02h)", $signed(sx12(ir[11:0])), tgt);
            end
            default: return $sformatf("nop  (%04h)", ir);
        endcase
    endfunction
endmodule
