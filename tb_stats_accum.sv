`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/28/2025 12:43:15 PM
// Design Name: 
// Module Name: tb_stats_accum
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module tb_stats_accum();
    localparam SIGNED_BIT = 1;
    localparam DATA_WIDTH = 15;
    localparam FRAC_BITS = 16;
    localparam MATRIX_SIZE = 4; // Using 4x1 for testbench 
    localparam MAX_SAMPLES = 1024;
    
    logic clk;
    logic rst_n;
    logic valid_in;
    logic compute_variance;
    logic signed [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] x_matrix [MATRIX_SIZE-1:0];
    
    logic valid_out;
    logic signed [(SIGNED_BIT+DATA_WIDTH+FRAC_BITS)*2-1:0] variance [MATRIX_SIZE-1:0];
    logic signed [(SIGNED_BIT+DATA_WIDTH+FRAC_BITS)*2+$clog2(MATRIX_SIZE)-1:0] total_variance;

    stats_accum #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .MATRIX_SIZE(MATRIX_SIZE),
        .MAX_SAMPLES(MAX_SAMPLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .x_matrix(x_matrix),
        .compute_variance(compute_variance),
        .valid_out(valid_out),
        .variance(variance),
        .total_variance(total_variance)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        valid_in = 0;
        compute_variance = 0;
        x_matrix = '{32'h0, 32'h0, 32'h0, 32'h0};
        
        #20 rst_n = 1;
        
        #10;
        valid_in = 1;
        x_matrix = '{32'h00010000, 32'h00020000, 32'h00030000, 32'h000A199A};
        #10;
        valid_in = 0;
        
        wait(dut.state == dut.IDLE);
        #20;
        
        valid_in = 1;
        x_matrix = '{32'h00040000, 32'h00050000, 32'h00060000, 32'h0009199A};
        #10;
        valid_in = 0;
        
        wait(dut.state == dut.IDLE);
        #20;
        
        valid_in = 1;
        x_matrix = '{32'h00070000, 32'h00080000, 32'h00090000, 32'h000A3333};
        #10;
        valid_in = 0;
        
        wait(dut.state == dut.IDLE);
        #20;
        
        valid_in = 1;
        x_matrix = '{32'h000A0000, 32'h000B0000, 32'h000C0000, 32'h000A3333};
        #10;
        valid_in = 0;
        
        wait(dut.state == dut.IDLE);
        #20;
        
        compute_variance = 1;
        #10;
        compute_variance = 0;
        
        wait(valid_out);
        #50;
        
        $finish;
    end

endmodule