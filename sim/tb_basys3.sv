`timescale 1ns / 1ps
module tb_basys3;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic btnC = 1'b0, btnR = 1'b0;
    logic [15:0] sw = 16'h0000;
    logic [15:0] led;
    logic [6:0] seg;
    logic dp;
    logic [3:0] an;

    localparam SCAN = 6;

    basys3_top #(.TICK_DIV(40), .DEBOUNCE_CYCLES(8), .SCAN_BITS(SCAN)) dut (
        .clk(clk), .btnC(btnC), .btnR(btnR), .sw(sw), .led(led), .seg(seg), .dp(dp), .an(an)
    );

    int errors = 0, checks = 0;

    task automatic check(input string what, input logic [15:0] got, input logic [15:0] exp);
        checks++;
        if (got !== exp) begin
            errors++;
            $display("FAIL  %s: got %04h, expected %04h  (t=%0t)", what, got, exp, $time);
        end
        else $display("  ok  %-34s %04h", what, got);
    endtask

    function automatic logic [4:0] seg2hex(input logic [6:0] s);
        case (s)
            7'b1000000: return 5'h10; 7'b1111001: return 5'h11; 7'b0100100: return 5'h12;
            7'b0110000: return 5'h13; 7'b0011001: return 5'h14; 7'b0010010: return 5'h15;
            7'b0000010: return 5'h16; 7'b1111000: return 5'h17; 7'b0000000: return 5'h18;
            7'b0010000: return 5'h19; 7'b0001000: return 5'h1A; 7'b0000011: return 5'h1B;
            7'b1000110: return 5'h1C; 7'b0100001: return 5'h1D; 7'b0000110: return 5'h1E;
            7'b0001110: return 5'h1F;
            default: return 5'h00;
        endcase
    endfunction

    logic [3:0] digit_val [0:3];
    logic [4:0] d;
    always @(posedge dut.clk_sys) begin
        d = seg2hex(seg);
        case (an)
            4'b1110: if (d[4]) digit_val[0] <= d[3:0];
            4'b1101: if (d[4]) digit_val[1] <= d[3:0];
            4'b1011: if (d[4]) digit_val[2] <= d[3:0];
            4'b0111: if (d[4]) digit_val[3] <= d[3:0];
            default:;
        endcase
    end

    task automatic read_display(output logic [15:0] v);
        repeat (3 * (1 << SCAN)) @(posedge dut.clk_sys);
        v = {digit_val[3], digit_val[2], digit_val[1], digit_val[0]};
    endtask

    task automatic show(input logic [1:0] mode, input logic [7:0] sel, input string what,
                        input logic [15:0] exp);
        logic [15:0] v;
        sw[13:12] = mode;
        sw[7:0] = sel;
        read_display(v);
        check(what, v, exp);
    endtask

    task automatic press_step();
        repeat (3) begin btnR = 1'b1; #60; btnR = 1'b0; #60; end
        btnR = 1'b1;
        repeat (30) @(posedge dut.clk_sys);
        repeat (3) begin btnR = 1'b0; #60; btnR = 1'b1; #60; end
        btnR = 1'b0;
        repeat (30) @(posedge dut.clk_sys);
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

    initial begin
        $dumpfile("tb_basys3.vcd");
        $dumpvars(1, tb_basys3);
        $dumpvars(1, tb_basys3.dut);
        $dumpvars(1, tb_basys3.dut.u_cpu);

        $display("board-level test (basys3_top)");
        wait (dut.locked === 1'b1);
        btnC = 1'b1;
        repeat (10) @(posedge dut.clk_sys);
        btnC = 1'b0;
        repeat (30) @(posedge dut.clk_sys);

        show(2'b00, 8'h00, "after reset: PC", 16'h0000);
        check("after reset: led[7:0] = PC", {8'h00, led[7:0]}, 16'h0000);
        press_step();
        show(2'b00, 8'h00, "1 press: PC", 16'h0002);
        show(2'b10, 8'h01, "1 press: $s1 (addi $s1,$s0,5)", 16'h0005);
        press_step();
        press_step();
        show(2'b00, 8'h00, "3 presses: PC", 16'h0006);
        show(2'b01, 8'h00, "3 presses: instruction (sub)", 16'h0211);
        check("3 presses: led[11:8] = opcode 0", {12'h000, led[11:8]}, 16'h0000);
        check("3 presses: led[13] = RegWrite", {15'b0, led[13]}, 16'h0001);
        show(2'b10, 8'h01, "3 presses: $s1 = 3 + 5", 16'h0008);

        sw[15] = 1'b1;
        for (int k = 0; k < 20000 && led[15] !== 1'b1; k++) @(posedge dut.clk_sys);
        check("RUN: HALT led", {15'b0, led[15]}, 16'h0001);
        check("RUN: RUN led", {15'b0, led[14]}, 16'h0001);
        show(2'b00, 8'h00, "halted: PC", 16'h0042);
        show(2'b01, 8'h00, "halted: instruction (jmp -1)", 16'h6FFF);
        for (int i = 0; i < 16; i++)
            show(2'b10, i[7:0], $sformatf("halted: $s%0d", i), exp_reg(i));
        show(2'b11, 8'h08, "halted: MEM[0x08]", 16'h00A0);
        show(2'b11, 8'h0A, "halted: MEM[0x0A]", 16'h0008);
        show(2'b11, 8'h0C, "halted: MEM[0x0C]", 16'h000F);
        show(2'b11, 8'h09, "halted: MEM[0x09] (odd address)", 16'hA000);

        btnC = 1'b1;
        repeat (10) @(posedge dut.clk_sys);
        btnC = 1'b0;
        sw[15] = 1'b0;
        repeat (30) @(posedge dut.clk_sys);
        show(2'b10, 8'h0C, "after reset: $s12", 16'h0000);
        show(2'b11, 8'h08, "after reset: MEM[0x08] kept", 16'h00A0);

        sw[15:14] = 2'b11;
        repeat (200) @(posedge dut.clk_sys);
        check("FAST: HALT led", {15'b0, led[15]}, 16'h0001);
        show(2'b10, 8'h0C, "FAST: $s12 = 1+2+3+4+5", 16'h000F);

        $display("");
        if (errors == 0) $display("PASS: tb_basys3  %0d checks, 0 mismatches", checks);
        else $display("FAIL: tb_basys3  %0d checks, %0d mismatches", checks, errors);
        $finish;
    end
endmodule
