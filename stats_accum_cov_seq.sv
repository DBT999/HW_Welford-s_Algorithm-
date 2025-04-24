`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Radiance Technologies
// Engineer: Daniel Tueller
// Modified by: [Your Name]
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
// This is a HW Welford's algorithim. Here is a link to help understand the implementation:
// https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_online_algorithm
//
//////////////////////////////////////////////////////////////////////////////////

module stats_accum#(
  localparam SIGNED_BIT = 1,
  parameter INT_BITS = 15,          
  parameter FRAC_BITS = 16,           
  parameter MATRIX_SIZE = 256,        
  parameter MAX_SAMPLES = 1024,       
  parameter COUNT_WIDTH = $clog2(MAX_SAMPLES) + 1,
  localparam VALUE_WIDTH = SIGNED_BIT+INT_BITS+FRAC_BITS,
  localparam DUB_VALUE_WIDTH = 2*(SIGNED_BIT+INT_BITS+FRAC_BITS)
)(
  input wire clk,                   
  input wire rst_n,                 
  input wire valid_in,                
  input wire signed [VALUE_WIDTH-1:0] x_matrix [MATRIX_SIZE-1:0],  // Input MATRIX_SIZEx1 matrix (as array)
  input wire compute_variance,        // Trigger to compute variance/covariance
  
  output logic valid_out,                 
  output logic signed [DUB_VALUE_WIDTH-1:0] variance [MATRIX_SIZE-1:0],  // Diagonal of covariance matrix (variances)
  output logic signed [DUB_VALUE_WIDTH-1:0] covariance [MATRIX_SIZE-1:0][MATRIX_SIZE-1:0],  // Full covariance matrix
  output logic signed [DUB_VALUE_WIDTH+$clog2(MATRIX_SIZE)-1:0] total_variance,  // Sum of all variances, a scalar
  output logic signed [VALUE_WIDTH-1:0] mean [MATRIX_SIZE-1:0]
);

  logic [COUNT_WIDTH-1:0] count;            
  logic [COUNT_WIDTH-1:0] element_processed_count; 
  logic [VALUE_WIDTH-1:0] inv_count;
  logic [VALUE_WIDTH-1:0] inv_count_prev;
  logic [FRAC_BITS-1:0] inv_count_frac;
  logic [FRAC_BITS-1:0] inv_count_frac_prev;
  logic [SIGNED_BIT+INT_BITS-1:0] empty_data_width = '0;
  
  // M2 accumulator for covariance calculation (sum of products of deviations)
  logic signed [DUB_VALUE_WIDTH*2-1:0] M2 [MATRIX_SIZE-1:0][MATRIX_SIZE-1:0];
  
  logic signed [VALUE_WIDTH-1:0] delta [MATRIX_SIZE-1:0]; 
  logic signed [VALUE_WIDTH-1:0] delta2 [MATRIX_SIZE-1:0];
  
  logic [$clog2(MATRIX_SIZE):0] i_index, j_index;  // Indices for covariance computation
  logic [$clog2(MATRIX_SIZE):0] next_i, next_j;    // For storing next indices
  logic compute_total_variance;                     // Flag to compute total variance

  inv_x_count_LUT_prev_and_next #(.SIZE_X(MAX_SAMPLES), .WD_REAL(FRAC_BITS)) inv_x_count_0
    (
      .x_count(count),
      .inv_x_count(inv_count_frac),
      .inv_x_count_prev(inv_count_frac_prev)
    );

  assign inv_count = (count == 1) ? 32'h00010000 : {empty_data_width, inv_count_frac};
  assign inv_count_prev = (count<=1) ? 32'h00010000 : {empty_data_width, inv_count_frac_prev};

  typedef enum logic [3:0] {
    IDLE,
    COMPUTE_DELTA,
    UPDATE_MEAN,
    COMPUTE_DELTA2,
    UPDATE_COV_INIT,
    UPDATE_COV_PROCESS,
    COMPUTE_COV_INIT,
    COMPUTE_COV_PROCESS,
    EXTRACT_VARIANCE,
    OUTPUT_READY
  } state_t;
  
  state_t state, next_state;
  
  function automatic void get_next_indices(
    input logic [$clog2(MATRIX_SIZE):0] i_in, j_in,
    output logic [$clog2(MATRIX_SIZE):0] i_out, j_out
  );
    if (j_in < MATRIX_SIZE-1) begin
      i_out = i_in;
      j_out = j_in + 1;
    end else begin
      i_out = i_in + 1;
      j_out = 0; 
    end
  endfunction
  
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
          next_state = COMPUTE_COV_INIT;
      end
      
      COMPUTE_DELTA: 
        next_state = UPDATE_MEAN;
      
      UPDATE_MEAN: 
        next_state = COMPUTE_DELTA2;
      
      COMPUTE_DELTA2: 
        next_state = UPDATE_COV_INIT;
      
      UPDATE_COV_INIT: begin
        next_state = UPDATE_COV_PROCESS;
      end
      
      UPDATE_COV_PROCESS: begin
        if (i_index == MATRIX_SIZE-1 && j_index == MATRIX_SIZE-1)
          next_state = IDLE;
        else
          next_state = UPDATE_COV_PROCESS;
      end
      
      COMPUTE_COV_INIT: begin
        next_state = COMPUTE_COV_PROCESS;
      end
      
      COMPUTE_COV_PROCESS: begin
        if (i_index == MATRIX_SIZE-1 && j_index == MATRIX_SIZE-1)
          next_state = EXTRACT_VARIANCE;
        else
          next_state = COMPUTE_COV_PROCESS;
      end
      
      EXTRACT_VARIANCE:
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
      total_variance <= '0;
      element_processed_count <= '0;
      i_index <= '0;
      j_index <= '0;
      next_i <= '0;
      next_j <= '0;
      compute_total_variance <= 1'b0;
      
      for (int i = 0; i < MATRIX_SIZE; i++) begin
        delta[i] <= '0;
        delta2[i] <= '0;
        mean[i] <= '0;
        variance[i] <= '0;
        
        for (int j = 0; j < MATRIX_SIZE; j++) begin
          M2[i][j] <= '0;
          covariance[i][j] <= '0;
        end
      end
    end else begin
      if (valid_in) count <= count + 1;
      
      case (state)
        IDLE: begin
          valid_out <= 1'b0;
          compute_total_variance <= 1'b0;
        end
        
        COMPUTE_DELTA: 
          // Compute delta = x - mean for current element
          for(int i = 0; i < MATRIX_SIZE; i++)
            delta[i] <= x_matrix[i] - mean[i];
        
        UPDATE_MEAN: begin
          for(int i = 0; i < MATRIX_SIZE; i++)
            mean[i] <= mean[i] + 
               ((64'(signed'(delta[i])) * 64'(signed'(inv_count))) >>> FRAC_BITS);
        end
        
        COMPUTE_DELTA2: begin
          // Compute delta2 = x - updated_mean for current element
          for(int i = 0; i < MATRIX_SIZE; i++)
            delta2[i] <= x_matrix[i] - mean[i];
        end
        
        UPDATE_COV_INIT: begin
          i_index <= '0;
          j_index <= '0;
        end
        
        UPDATE_COV_PROCESS: begin
          // Update covariance accumulator for the entire matrix
          M2[i_index][j_index] <= M2[i_index][j_index] + 
                                 ((delta[i_index] * delta2[j_index]) >>> FRAC_BITS);
          
          // Move to next element in the matrix
          get_next_indices(i_index, j_index, next_i, next_j);
          i_index <= next_i;
          j_index <= next_j;
        end
        
        COMPUTE_COV_INIT: begin
          i_index <= '0;
          j_index <= '0;
          total_variance <= '0;
          compute_total_variance <= 1'b1;
        end
        
        COMPUTE_COV_PROCESS: begin
          // Compute covariance = M2 / (count - 1) for the entire matrix
          if (count > 1) begin
            covariance[i_index][j_index] <= ((M2[i_index][j_index] * inv_count_prev) >>> FRAC_BITS);
          end else begin
            covariance[i_index][j_index] <= '0;
          end
          
          // Move to next element in the matrix
          get_next_indices(i_index, j_index, next_i, next_j);
          i_index <= next_i;
          j_index <= next_j;
        end
        
        EXTRACT_VARIANCE: begin
          for (int i = 0; i < MATRIX_SIZE; i++) begin
            variance[i] <= covariance[i][i];
            if (compute_total_variance)
              total_variance <= total_variance + covariance[i][i];
          end
          compute_total_variance <= 1'b0;
        end
        
        OUTPUT_READY: 
          valid_out <= 1'b1;
       
        default: begin
        end
      endcase
    end
  end
endmodule