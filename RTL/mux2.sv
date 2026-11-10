`timescale 1ns / 1ps
module mux2 #(
    parameter W = 16
)(
    input logic [W-1:0] d0,
    input logic [W-1:0] d1,
    input logic sel,
    output logic [W-1:0] y
);

assign y = sel ? d1 : d0;

endmodule
