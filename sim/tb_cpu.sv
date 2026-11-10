`timescale 1ns / 1ps
module tb_cpu;
    logic clk = 1'b0;
    logic rst = 1'b1;
    always #5 clk = ~clk;

    logic [15:0] pc, ir, wb, alu, regv, memv;
    logic [3:0] rd;
    logic we, mwe, halt;

    top_wire dut (
        .clk(clk), .rst(rst), .cpu_en(1'b1),
        .dbg_pc(pc), .dbg_instr(ir), .dbg_reg_we(we), .dbg_rd(rd), .dbg_wb_data(wb),
        .dbg_mem_we(mwe), .dbg_alu(alu),
        .dbg_reg_sel(4'd0), .dbg_reg_val(regv), .dbg_mem_addr(8'd0), .dbg_mem_val(memv),
        .halt(halt)
    );

    isa_ref gold ();

    wire [15:0] s1 = dut.npn.regs[1], s2 = dut.npn.regs[2], s3 = dut.npn.regs[3];
    wire [15:0] s4 = dut.npn.regs[4], s5 = dut.npn.regs[5], s6 = dut.npn.regs[6];
    wire [15:0] s7 = dut.npn.regs[7], s8 = dut.npn.regs[8], s9 = dut.npn.regs[9];
    wire [15:0] s10 = dut.npn.regs[10], s11 = dut.npn.regs[11], s12 = dut.npn.regs[12];
    wire [15:0] s13 = dut.npn.regs[13], s14 = dut.npn.regs[14], s15 = dut.npn.regs[15];
    wire [15:0] mem_08 = {dut.meme.memistan[8'h08], dut.meme.memistan[8'h09]};
    wire [15:0] mem_0A = {dut.meme.memistan[8'h0A], dut.meme.memistan[8'h0B]};
    wire [15:0] mem_0C = {dut.meme.memistan[8'h0C], dut.meme.memistan[8'h0D]};

    int errors = 0;
    int checks = 0;
    int executed = 0;

    task automatic check(input string what, input logic [15:0] got, input logic [15:0] exp);
        checks++;
        if (got !== exp) begin
            errors++;
            if (errors <= 20)
                $display("FAIL  %s: got %04h, expected %04h  (t=%0t)", what, got, exp, $time);
        end
    endtask

    task automatic compare_state();
        check("PC", dut.PC_loc, gold.pc);
        for (int i = 0; i < 16; i++)
            check($sformatf("$s%0d", i), dut.npn.regs[i], gold.r[i]);
        for (int i = 0; i < 256; i++)
            check($sformatf("MEM[%02h]", i), {8'h00, dut.meme.memistan[i]}, {8'h00, gold.mem[i]});
    endtask

    function automatic logic [15:0] exp_reg(input int i);
        case (i)
            1: return 16'h0008; 2: return 16'h0005; 3: return 16'h0004;
            4: return 16'h00A0; 5: return 16'h0008; 6: return 16'h000A;
            7: return 16'h00A0; 8: return 16'hA000; 9: return 16'h0002;
           10: return 16'h0005; 11: return 16'h0005; 12: return 16'h000F;
           13: return 16'h0000; 14: return 16'hFFFF; 15: return 16'h000F;
           default: return 16'h0000;
        endcase
    endfunction

    function automatic logic [7:0] exp_byte(input int a);
        case (a)
            8'h09: return 8'hA0;
            8'h0B: return 8'h08;
            8'h0D: return 8'h0F;
            default: return 8'h00;
        endcase
    endfunction

    string effect;

    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);

        #1;
        for (int i = 0; i < 128; i++) gold.imem[i] = dut.dc.registan[i];
        for (int i = 0; i < 256; i++) gold.mem[i] = dut.meme.memistan[i];
        gold.reset();

        repeat (2) @(posedge clk);
        #1 rst = 1'b0;
        compare_state();

        $display("");
        $display(" cyc   pc    ir    instruction                    effect");
        $display(" ---   ----  ----  -----------------------------  ------------------------");
        while (!halt && executed < 500) begin
            @(negedge clk);
            gold.step();
            check("RegWrite", {15'b0, we}, {15'b0, gold.wr_en});
            check("MemWrite", {15'b0, mwe}, {15'b0, gold.st_en});
            if (gold.wr_en) begin
                check("rd", {12'b0, rd}, {12'b0, gold.wr_reg});
                check("write-back data", wb, gold.wr_val);
            end
            if (gold.st_en) check("store address", {8'h00, alu[7:0]}, {8'h00, gold.st_addr});

            if (gold.wr_en) effect = $sformatf("$s%0d <- %04h", gold.wr_reg, gold.wr_val);
            else if (gold.st_en) effect = $sformatf("MEM[%02h] <- %04h", gold.st_addr, gold.st_val);
            else if (gold.last_ir[15:12] == 4'h4 || gold.last_ir[15:12] == 4'h5)
                                 effect = gold.taken ? "branch taken" : "branch not taken";
            else if (gold.last_ir[15:12] == 4'h6) effect = "jump";
            else effect = "";
            executed++;
            $display(" %3d   %04h  %04h  %-29s  %s", executed, gold.last_pc, gold.last_ir,
                     gold.disasm(gold.last_ir, gold.last_pc), effect);

            @(posedge clk);
            #1 compare_state();
        end

        repeat (3) begin
            @(negedge clk);
            gold.step();
            @(posedge clk);
            #1 compare_state();
        end

        $display("");
        $display("halted at PC = %04h after %0d instructions (halt = %b)", pc, executed, halt);
        check("final PC", pc, 16'h0042);
        check("halt", {15'b0, halt}, 16'h0001);
        for (int i = 0; i < 16; i++)
            check($sformatf("final $s%0d", i), dut.npn.regs[i], exp_reg(i));
        for (int i = 0; i < 256; i++)
            check($sformatf("final MEM[%02h]", i), {8'h00, dut.meme.memistan[i]}, {8'h00, exp_byte(i)});

        $display("");
        $display("registers:");
        for (int i = 0; i < 16; i += 4)
            $display("  $s%-2d=%04h  $s%-2d=%04h  $s%-2d=%04h  $s%-2d=%04h",
                     i, dut.npn.regs[i], i+1, dut.npn.regs[i+1], i+2, dut.npn.regs[i+2], i+3, dut.npn.regs[i+3]);
        $display("data memory words 0x00..0x0E:");
        $write("  ");
        for (int a = 0; a < 16; a += 2) $write("[%02h]=%02h%02h ", a[7:0], dut.meme.memistan[a], dut.meme.memistan[a+1]);
        $display("");
        $display("");
        if (errors == 0) $display("PASS: tb_cpu  %0d checks, 0 mismatches", checks);
        else $display("FAIL: tb_cpu  %0d checks, %0d mismatches", checks, errors);
        $finish;
    end
endmodule
