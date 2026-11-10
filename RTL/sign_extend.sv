`timescale 1ns / 1ps
module sign_extend #(
    parameter IN_W = 4,
    parameter OUT_W = 16
)(
    input logic [IN_W-1:0] in,
    output logic [OUT_W-1:0] out
);

assign out = {{(OUT_W-IN_W){in[IN_W-1]}}, in};

endmodule
