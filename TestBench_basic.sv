`timescale 1ns/1ps
module test1();
logic clk, rst;
logic [15:0] dbg_pc, dbg_instr, dbg_wb_data, dbg_alu, dbg_reg_val, dbg_mem_val;
logic [3:0] dbg_rd;
logic dbg_reg_we, dbg_mem_we, halt;

top_wire dut(.clk(clk), .rst(rst), .cpu_en(1'b1),
             .dbg_pc(dbg_pc), .dbg_instr(dbg_instr), .dbg_reg_we(dbg_reg_we), .dbg_rd(dbg_rd),
             .dbg_wb_data(dbg_wb_data), .dbg_mem_we(dbg_mem_we), .dbg_alu(dbg_alu),
             .dbg_reg_sel(4'd0), .dbg_reg_val(dbg_reg_val), .dbg_mem_addr(8'd0), .dbg_mem_val(dbg_mem_val),
             .halt(halt));

initial clk = 0;
always #5 clk = ~clk;

initial begin
    rst = 1;
    #20;
    rst = 0;
    @(negedge clk);
    while (halt !== 1'b1) @(negedge clk);
    #20 $finish;
end

always @(posedge clk) if (!rst && dbg_reg_we)
    $display("%0t pc=%04h instr=%04h $s%0d <= %04h",
             $time, dbg_pc, dbg_instr, dbg_rd, dbg_wb_data);

initial $dumpfile("wave.vcd");
initial $dumpvars(0, test1);

endmodule
