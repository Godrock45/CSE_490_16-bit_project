`timescale 1ns / 1ps
module basys3_top #(
    parameter TICK_DIV = 12_500_000,
    parameter DEBOUNCE_CYCLES = 250_000,
    parameter SCAN_BITS = 18
)(
    input logic clk,
    input logic btnC,
    input logic btnR,
    input logic [15:0] sw,
    output logic [15:0] led,
    output logic [6:0] seg,
    output logic dp,
    output logic [3:0] an
);

    logic clk_sys, locked;
    clk_gen u_clk (.clk_100(clk), .clk_sys(clk_sys), .locked(locked));

    logic [15:0] sw_meta = 16'h0000, sw_s = 16'h0000;
    logic step_meta = 1'b0, step_s = 1'b0;
    logic [1:0] rst_meta = 2'b11;

    always_ff @(posedge clk_sys) begin
        sw_meta <= sw;
        sw_s <= sw_meta;
        step_meta <= btnR;
        step_s <= step_meta;
        rst_meta <= {rst_meta[0], (btnC | ~locked)};
    end

    logic [3:0] rst_cnt = 4'h0;
    logic cpu_rst = 1'b1;

    always_ff @(posedge clk_sys) begin
        if (rst_meta[1]) begin
            rst_cnt <= 4'h0;
            cpu_rst <= 1'b1;
        end
        else if (rst_cnt != 4'hF) begin
            rst_cnt <= rst_cnt + 4'h1;
            cpu_rst <= 1'b1;
        end
        else begin
            cpu_rst <= 1'b0;
        end
    end

    logic step_db, step_db_q = 1'b0, step_pulse;
    debounce #(.CYCLES(DEBOUNCE_CYCLES)) u_db (.clk(clk_sys), .in(step_s), .out(step_db));

    always_ff @(posedge clk_sys) step_db_q <= step_db;
    assign step_pulse = step_db & ~step_db_q;

    logic [31:0] tick_cnt = 32'd0;
    logic tick = 1'b0;

    always_ff @(posedge clk_sys) begin
        if (tick_cnt >= TICK_DIV - 1) begin
            tick_cnt <= 32'd0;
            tick <= 1'b1;
        end
        else begin
            tick_cnt <= tick_cnt + 32'd1;
            tick <= 1'b0;
        end
    end

    logic run, fast, cpu_en;
    assign run = sw_s[15];
    assign fast = sw_s[14];
    assign cpu_en = run ? (fast ? 1'b1 : tick) : step_pulse;

    logic [15:0] dbg_pc, dbg_instr, dbg_wb_data, dbg_alu, dbg_reg_val, dbg_mem_val;
    logic [3:0] dbg_rd;
    logic dbg_reg_we, dbg_mem_we, halt;

    top_wire u_cpu (
        .clk(clk_sys),
        .rst(cpu_rst),
        .cpu_en(cpu_en),
        .dbg_pc(dbg_pc),
        .dbg_instr(dbg_instr),
        .dbg_reg_we(dbg_reg_we),
        .dbg_rd(dbg_rd),
        .dbg_wb_data(dbg_wb_data),
        .dbg_mem_we(dbg_mem_we),
        .dbg_alu(dbg_alu),
        .dbg_reg_sel(sw_s[3:0]),
        .dbg_reg_val(dbg_reg_val),
        .dbg_mem_addr(sw_s[7:0]),
        .dbg_mem_val(dbg_mem_val),
        .halt(halt)
    );

    logic [15:0] shown;
    always_comb begin
        case (sw_s[13:12])
            2'b00: shown = dbg_pc;
            2'b01: shown = dbg_instr;
            2'b10: shown = dbg_reg_val;
            default: shown = dbg_mem_val;
        endcase
    end

    logic [SCAN_BITS-1:0] scan = '0;
    logic [1:0] digit;
    logic [3:0] nibble;
    logic [6:0] seg_c;

    always_ff @(posedge clk_sys) scan <= scan + 1'b1;
    assign digit = scan[SCAN_BITS-1:SCAN_BITS-2];

    always_comb begin
        case (digit)
            2'd0: nibble = shown[3:0];
            2'd1: nibble = shown[7:4];
            2'd2: nibble = shown[11:8];
            default: nibble = shown[15:12];
        endcase
    end

    hex7seg u_hex (.hex(nibble), .seg(seg_c));

    logic [3:0] an_q = 4'b1111;
    logic [6:0] seg_q = 7'b1111111;
    always_ff @(posedge clk_sys) begin
        an_q <= ~(4'b0001 << digit);
        seg_q <= seg_c;
    end
    assign an = an_q;
    assign seg = seg_q;
    assign dp = 1'b1;

    assign led = {halt, run, dbg_reg_we, dbg_mem_we, dbg_instr[15:12], dbg_pc[7:0]};

endmodule
