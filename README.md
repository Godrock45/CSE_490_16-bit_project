# CSE 490/590 Project 1: 16-bit Single-Cycle CPU

A 16-bit single-cycle processor in SystemVerilog, running on a Digilent Basys 3 (Artix-7 XC7A35T).
It executes the 10 required instructions (add, sub, sll, and, lw, sw, addi, beq, bne, jmp) plus slt, xor, srl, sra and or.
Memory is byte-addressed and big-endian, and the top level (`RTL/top.sv`) is purely structural.

## Layout

| Folder | Contents |
| --- | --- |
| `RTL/` | CPU modules; `ROM.sv` holds the demo program |
| `fpga/` | Basys 3 wrapper, pin constraints, Vivado scripts, `cpu16_basys3.bit` |
| `sim/` | Self-checking testbenches and an ISA reference model |

## Simulate (Icarus Verilog)

```
iverilog -g2012 -s tb_cpu -o tb_cpu.vvp RTL/*.sv sim/isa_ref.sv sim/tb_cpu.sv
vvp tb_cpu.vvp
```

Swap in `tb_units` or `tb_random` the same way. For the board test, add the wrapper and clock models:

```
iverilog -g2012 -s tb_basys3 -o tb_basys3.vvp RTL/*.sv sim/isa_ref.sv sim/tb_basys3.sv fpga/basys3_top.sv fpga/clk_gen.sv fpga/debounce.sv fpga/hex7seg.sv sim/models/xilinx_prims.v
vvp tb_basys3.vvp
```

Each testbench prints `PASS` with 0 mismatches.

## Build (Vivado)

```
vivado -mode batch -source fpga/build.tcl
```

This writes `fpga/cpu16_basys3.bit`. Use `fpga/create_project.tcl` instead to open the project in the GUI.

## Board controls

| Control | Function |
| --- | --- |
| Center button | Reset |
| Right button | Step one instruction (SW15 off) |
| SW15 / SW14 | Run / full speed |
| SW13, SW12 | Display: 00 PC, 01 instruction, 10 register, 11 memory |
| SW3-SW0 / SW7-SW0 | Register number / memory address |
| LD15 | Halted |

The demo program halts at PC `0042`.
