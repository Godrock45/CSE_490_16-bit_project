`timescale 1ns / 1ps
module tb_random;
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

    int programs = 300;
    int cycles = 400;
    int seed = 2026;
    int errors = 0, checks = 0, executed = 0;

    int n_op [0:15];
    int n_fn [0:15];
    int beq_t = 0, beq_n = 0, bne_t = 0, bne_n = 0, jmp_back = 0, jmp_fwd = 0;
    int sll_big = 0, neg_imm = 0, odd_addr = 0, wrap_addr = 0, ld_after_st = 0, s0_writes = 0;
    logic [7:0] last_st;
    logic have_st;

    task automatic check(input string what, input logic [15:0] got, input logic [15:0] exp);
        checks++;
        if (got !== exp) begin
            errors++;
            if (errors <= 20)
                $display("FAIL  %s: got %04h, expected %04h  (t=%0t, pc=%04h ir=%04h)",
                         what, got, exp, $time, gold.last_pc, gold.last_ir);
        end
    endtask

    task automatic compare_state();
        check("PC", dut.PC_loc, gold.pc);
        for (int i = 0; i < 16; i++)
            check($sformatf("$s%0d", i), dut.npn.regs[i], gold.r[i]);
        for (int i = 0; i < 256; i++)
            check($sformatf("MEM[%02h]", i), {8'h00, dut.meme.memistan[i]}, {8'h00, gold.mem[i]});
    endtask

    function automatic logic [3:0] rnd4();
        return $random(seed);
    endfunction

    function automatic logic [3:0] rnd_off4();
        logic [3:0] o;
        do o = $random(seed); while (o == 4'hF);
        return o;
    endfunction

    function automatic logic [15:0] rand_instr();
        int k;
        logic [11:0] j;
        logic [3:0] x;
        k = {$random(seed)} % 100;
        x = 4'h4 + ({$random(seed)} % 5);
        if (k < 9) return {4'h0, rnd4(), rnd4(), 4'h0};
        if (k < 18) return {4'h0, rnd4(), rnd4(), 4'h1};
        if (k < 25) return {4'h0, rnd4(), rnd4(), 4'h2};
        if (k < 32) return {4'h0, rnd4(), rnd4(), 4'h3};
        if (k < 35) return {4'h0, rnd4(), rnd4(), x};
        if (k < 55) return {4'h3, rnd4(), rnd4(), rnd4()};
        if (k < 65) return {4'h1, rnd4(), rnd4(), rnd4()};
        if (k < 75) return {4'h2, rnd4(), rnd4(), rnd4()};
        if (k < 84) return {4'h4, rnd4(), rnd4(), rnd_off4()};
        if (k < 93) return {4'h5, rnd4(), rnd4(), rnd_off4()};
        do j = ({$random(seed)} % 33) - 16; while (j == 12'hFFF);
        return {4'h6, j};
    endfunction

    task automatic count(input logic [15:0] ir);
        logic [3:0] op, f, s;
        logic [15:0] ea;
        op = ir[15:12]; f = ir[3:0]; s = ir[7:4];
        n_op[op]++;
        if (op == 4'h0) n_fn[f]++;
        if (op == 4'h0 && f == 4'h2 && gold.r[s] > 16'd15) sll_big++;
        if ((op == 4'h1 || op == 4'h2 || op == 4'h3) && f[3]) neg_imm++;
        if (op == 4'h1 || op == 4'h2) begin
            ea = gold.r[s] + {{12{f[3]}}, f};
            if (ea[0]) odd_addr++;
            if (ea[7:0] == 8'hFF) wrap_addr++;
            if (op == 4'h1 && have_st && ea[7:0] == last_st) ld_after_st++;
            if (op == 4'h2) begin last_st = ea[7:0]; have_st = 1'b1; end
        end
        if ((op == 4'h0 || op == 4'h1 || op == 4'h3) && ir[11:8] == 4'd0) s0_writes++;
    endtask

    initial begin
        if ($value$plusargs("programs=%d", programs));
        if ($value$plusargs("cycles=%d", cycles));
        if ($value$plusargs("seed=%d", seed));
        for (int i = 0; i < 16; i++) begin n_op[i] = 0; n_fn[i] = 0; end
        $display("random programs: %0d programs x %0d cycles, seed %0d", programs, cycles, seed);

        for (int p = 0; p < programs && errors == 0; p++) begin
            rst = 1'b1;
            have_st = 1'b0;
            @(negedge clk);
            for (int i = 0; i < 128; i++) begin
                dut.dc.registan[i] = rand_instr();
                gold.imem[i] = dut.dc.registan[i];
            end
            for (int i = 0; i < 256; i++) begin
                dut.meme.memistan[i] = $random(seed);
                gold.mem[i] = dut.meme.memistan[i];
            end
            gold.reset();
            @(posedge clk);
            #1 rst = 1'b0;
            compare_state();
            for (int c = 0; c < cycles; c++) begin
                @(negedge clk);
                count(dut.IR_loc);
                gold.step();
                executed++;
                if (gold.last_ir[15:12] == 4'h4) begin if (gold.taken) beq_t++; else beq_n++; end
                if (gold.last_ir[15:12] == 4'h5) begin if (gold.taken) bne_t++; else bne_n++; end
                if (gold.last_ir[15:12] == 4'h6) begin if (gold.last_ir[11]) jmp_back++; else jmp_fwd++; end
                check("RegWrite", {15'b0, we}, {15'b0, gold.wr_en});
                check("MemWrite", {15'b0, mwe}, {15'b0, gold.st_en});
                if (gold.wr_en) check("write-back", wb, gold.wr_val);
                @(posedge clk);
                #1 compare_state();
            end
        end

        $display("");
        $display("coverage (instructions executed: %0d)", executed);
        $display("  add  %6d    sub  %6d    sll  %6d    and  %6d", n_fn[0], n_fn[1], n_fn[2], n_fn[3]);
        $display("  lw   %6d    sw   %6d    addi %6d", n_op[1], n_op[2], n_op[3]);
        $display("  beq  %6d (taken %0d, not taken %0d)", n_op[4], beq_t, beq_n);
        $display("  bne  %6d (taken %0d, not taken %0d)", n_op[5], bne_t, bne_n);
        $display("  jmp  %6d (forward %0d, backward %0d)", n_op[6], jmp_fwd, jmp_back);
        $display("  extras slt/xor/srl/sra/or: %0d/%0d/%0d/%0d/%0d", n_fn[4], n_fn[5], n_fn[6], n_fn[7], n_fn[8]);
        $display("  negative immediates %0d, sll by >= 16: %0d, writes to $s0: %0d", neg_imm, sll_big, s0_writes);
        $display("  lw/sw at odd byte address %0d, at 0xFF (wraps) %0d, lw from the latest sw address %0d",
                 odd_addr, wrap_addr, ld_after_st);
        $display("");
        if (errors == 0) $display("PASS: tb_random  %0d checks, 0 mismatches", checks);
        else $display("FAIL: tb_random  %0d checks, %0d mismatches", checks, errors);
        $finish;
    end
endmodule
