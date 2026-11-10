`timescale 1ns / 1ps
module PrgCo(
    input logic clk,
    input logic rst,
    input logic pc_en,
    input logic [15:0] next_pc,
    output logic [15:0] pc
);

always_ff @(posedge clk) begin
    if (rst) begin
        pc <= 16'h0000;
    end
    else if (pc_en) begin
        pc <= next_pc;
    end
end

endmodule
