`timescale 1ns / 1ps
module memory(
    input logic clk,
    input logic rst,
    input logic en,
    input logic [15:0] addr,
    input logic [15:0] dat,
    input logic write_ena,
    input logic read_ena,
    output logic [15:0] mem_dat,
    input logic [7:0] dbg_addr,
    output logic [15:0] dbg_dat
);

logic [7:0] memistan [0:255];
logic [7:0] a_hi, a_lo, d_hi, d_lo;

assign a_hi = addr[7:0];
assign a_lo = addr[7:0]+8'd1;
assign d_hi = dbg_addr;
assign d_lo = dbg_addr+8'd1;

initial begin
    for (int i = 0; i < 256; i++) begin
        memistan[i] = 8'h00;
    end
end

always_comb begin
    mem_dat = read_ena ? {memistan[a_hi], memistan[a_lo]} : 16'h0000;
    dbg_dat = {memistan[d_hi], memistan[d_lo]};
end

always @(posedge clk) begin
    if (!rst && en && write_ena) begin
        memistan[a_hi] <= dat[15:8];
        memistan[a_lo] <= dat[7:0];
    end
end

endmodule
