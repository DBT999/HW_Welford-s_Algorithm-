`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Radiance Technologies
// Engineer: Daniel Tueller
// 
// Create Date: 03/18/2025 10:04:53 AM
// Design Name: 
// Module Name: stats_accum
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
// This is a HW Welford's algorithim. Here is a link to help understand the implementation:
// https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_online_algorithm
//
//////////////////////////////////////////////////////////////////////////////////

module stats_accum#(
  parameter SIGNED_BIT = 1,
  parameter DATA_WIDTH = 15,          
  parameter FRAC_BITS = 16,           
  parameter MATRIX_SIZE = 256,        
  parameter MAX_SAMPLES = 1024,       
  parameter COUNT_WIDTH = $clog2(MAX_SAMPLES) + 1 
)(
  input wire clk,                   
  input wire rst_n,                 
  input wire valid_in,                
  input wire signed [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] x_matrix [MATRIX_SIZE-1:0],  // Input MATRIX_SIZEx1 matrix (as array)
  input wire compute_variance,        // Trigger to compute variance
  
  output logic valid_out,                 
  output logic signed [SIGNED_BIT+(DATA_WIDTH+FRAC_BITS)*2-1:0] variance [MATRIX_SIZE-1:0],  // Diagonal of covariance matrix (variances)
  output logic signed [SIGNED_BIT+(DATA_WIDTH+FRAC_BITS)*2+8-1:0] total_variance,  // Sum of all variances, a scalar
  output logic signed [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] mean [MATRIX_SIZE-1:0]
);

  logic [COUNT_WIDTH-1:0] count;            
  logic [COUNT_WIDTH-1:0] element_processed_count; 
  logic signed [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] mean [MATRIX_SIZE-1:0];  
  logic [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] inv_count;
  logic [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] inv_count_next;
  logic [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] inv_count_prev;
  logic [FRAC_BITS-1:0] inv_count_frac;
  logic [FRAC_BITS-1:0] inv_count_frac_next;
  logic [FRAC_BITS-1:0] inv_count_frac_prev;
  logic [SIGNED_BIT+DATA_WIDTH-1:0] empty_data_width = '0;
  // M2 accumulator for variance calculation (sum of squared deviations), traack only diagonals for effciency.
  logic signed [SIGNED_BIT+(DATA_WIDTH+FRAC_BITS)*4-1:0] M2 [MATRIX_SIZE-1:0];
  
  logic signed [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] delta [MATRIX_SIZE-1:0]; 
  logic signed [SIGNED_BIT+DATA_WIDTH+FRAC_BITS-1:0] delta2 [MATRIX_SIZE-1:0];
  
  logic [$clog2(MATRIX_SIZE):0] process_counter;

  inv_x_count_LUT_prev_and_next #(.SIZE_X(MAX_SAMPLES), .WD_REAL(FRAC_BITS)) inv_x_count_0
    (
      .x_count(count),
      .inv_x_count(inv_count_frac),
      .inv_x_count_prev(inv_count_frac_prev)
    );

  assign inv_count = (count == 1) ? 32'h00010000 : {empty_data_width, inv_count_frac};
  assign inv_count_prev = (count<=1) ? 32'h00010000 : {empty_data_width, inv_count_frac_prev}; 
  assign inv_count_next = {empty_data_width, inv_count_frac_next};



  typedef enum logic [3:0] {
    IDLE,
    COMPUTE_DELTA,
    UPDATE_MEAN,
    COMPUTE_DELTA2,
    UPDATE_M2,
    PROCESS_NEXT,
    COMPUTE_VARIANCE_START,
    COMPUTE_VARIANCE_PROCESS,
    OUTPUT_READY
  } state_t;
  
  state_t state, next_state;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (valid_in)
          next_state = COMPUTE_DELTA;
        else if (compute_variance && count > 0)
          next_state = COMPUTE_VARIANCE_START;
      end
      
      COMPUTE_DELTA: 
        next_state = UPDATE_MEAN;
      
      UPDATE_MEAN: 
        next_state = COMPUTE_DELTA2;
      
      COMPUTE_DELTA2: 
        next_state = UPDATE_M2;
      
      UPDATE_M2: begin
        next_state = PROCESS_NEXT;
      end
      
      PROCESS_NEXT: 
        next_state = IDLE;
      
      COMPUTE_VARIANCE_START: 
        next_state = COMPUTE_VARIANCE_PROCESS;
      
      COMPUTE_VARIANCE_PROCESS: 
        next_state = OUTPUT_READY;
      
      OUTPUT_READY: 
        next_state = IDLE;
      
      default: 
        next_state = IDLE;
    endcase
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= '0;
      valid_out <= 1'b0;
      process_counter <= '0;
      total_variance <= '0;
      element_processed_count <= '0; 
      for (int i = 0; i < MATRIX_SIZE; i++) begin
        delta[i] <= '0;
        delta2[i] <= '0;
        mean[i] <= '0;
        M2[i] <= '0;
        variance[i] <= '0;
      end
    end else begin
      if (valid_in) count <= count + 1;
      case (state)
        IDLE: begin
          valid_out <= 1'b0;
        end
        COMPUTE_DELTA: 
          // Compute delta = x - mean for current element
          for(int i = 0; i < MATRIX_SIZE; i++)
            delta[i] <= x_matrix[i] - mean[i];
        
        UPDATE_MEAN: begin
          for(int i = 0; i < MATRIX_SIZE; i++)
            mean[i] <= mean[i] + 
               ((64'(signed'(delta[i])) * 64'(signed'(inv_count))) >>> FRAC_BITS); // Temporary cast into larger widths because it wasn't working otherwise. Need 1/count from LUT.
        end
        
        COMPUTE_DELTA2: begin
          // Compute delta2 = x - updated_mean for current element
          for(int i = 0; i < MATRIX_SIZE; i++)
            delta2[i] <= x_matrix[i] - mean[i];
        end
        
        UPDATE_M2: begin
          // Accumulate in M2 for current element. M2 += delta * delta2 (only diagonal elements since this is Welford's online algorithm with Matrices as the elements)
          for(int i = 0; i < MATRIX_SIZE; i++)
            M2[i] <= M2[i] + ((delta[i] * delta2[i]) >>> FRAC_BITS);
        end
        
        PROCESS_NEXT: 
          element_processed_count <= element_processed_count + 1;
        
        COMPUTE_VARIANCE_START: begin
          total_variance <= '0;
        end
        
        COMPUTE_VARIANCE_PROCESS: begin
          // Compute variance = M2 / (count - 1) for each element
          if (count > 1) begin
            for(int i = 0; i < MATRIX_SIZE; i++)
              variance[i] <= ((M2[i] * inv_count_prev) >>> FRAC_BITS); // Need to get 1/(count - 1) from LUT
          end else begin
            for(int i = 0; i < MATRIX_SIZE; i++) 
              variance[i] <= '0; 
          end
          // Add to total variance
          if (count > 1) begin
            for(int i = 0; i < MATRIX_SIZE; i++)
              total_variance <= total_variance + ((M2[i] * inv_count_prev) >>> FRAC_BITS); // Need  1/(count - 1) again
          end
        end
        
        OUTPUT_READY: 
          valid_out <= 1'b1;
       
        default: begin
        end
      endcase
    end
  end
endmodule

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
    logic signed [SIGNED_BIT+(DATA_WIDTH+FRAC_BITS)*2-1:0] variance [MATRIX_SIZE-1:0];
    logic signed [SIGNED_BIT+(DATA_WIDTH+FRAC_BITS)*2+8-1:0] total_variance;

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
