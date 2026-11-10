`timescale 1ns / 1ps
module debounce #(
    parameter CYCLES = 250_000
)(
    input logic clk,
    input logic in,
    output logic out
);

    logic [31:0] cnt = 32'd0;
    logic state = 1'b0;

    always_ff @(posedge clk) begin
        if (in == state) begin
            cnt <= 32'd0;
        end
        else if (cnt >= CYCLES - 1) begin
            state <= in;
            cnt <= 32'd0;
        end
        else begin
            cnt <= cnt + 32'd1;
        end
    end

    assign out = state;

endmodule
