`timescale 1ns / 1ps

`ifndef _constants_vh_
`define _constants_vh_


// Fixed Point Constants
`define N 48
`define Q 20

// Division Constants
`define NUM_NR_ITERATIONS 6
`define P_0 -12 // 8 diff between P_1 and P_0
`define P_1 -4  //   midway between 3 and -13
`define P_2  4  // 8 diff between P_2 and P_1
`define FIXED_POINT_VALUE_ONE (1 << `Q)

`endif
