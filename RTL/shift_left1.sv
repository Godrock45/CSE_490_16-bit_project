`timescale 1ns / 1ps
module shift_left1 #(
    parameter W = 16
)(
    input logic [W-1:0] in,
    output logic [W-1:0] out
);

assign out = {in[W-2:0], 1'b0};

endmodule
