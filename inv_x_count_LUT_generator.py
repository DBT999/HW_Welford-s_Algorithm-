import itertools
from math import ceil, log

def generate_inv_lut(output_file="c:/RERUN/stats_accum/inv_x_count_LUT_prev_and_next.sv"):
    SIZE_X = 1024
    WD_REAL = 16
    SCALING = 2 ** WD_REAL
    WD_X = ceil(log(SIZE_X, 2))
    WD_INV_X = WD_X + 1
    
    with open(output_file, 'w') as f:
        f.write("module inv_x_count_LUT_prev_and_next #(\n")
        f.write("  parameter int unsigned\n")
        f.write("  SIZE_X = 1024,\n")
        f.write("  WD_REAL = 16\n")    
        f.write(")\n")
        f.write("(\n") 
        f.write(f"  input [{WD_X-1}:0] x_count,\n")
        f.write(f"  output logic [{WD_REAL-1}:0] inv_x_count,\n")
        f.write(f"  output logic [{WD_REAL-1}:0] inv_x_count_prev,\n")
        f.write(f"  output logic [{WD_REAL-1}:0] inv_x_count_next\n")
        f.write(");\n\n")
        
        # First case block for inv_x_count
        f.write("  always_comb begin\n")
        f.write("    case (x_count)\n")
        for x_count in range(2, (SIZE_X+1)):
            fixed_point_value = round((1/x_count) * SCALING)
            f.write(f"      {WD_X}'d{x_count}: inv_x_count = {WD_REAL}'b{fixed_point_value:0{WD_REAL}b}; // 1/{x_count} = {1/x_count:.10f}\n")
        f.write("      default: inv_x_count = '0; // Default case\n")
        f.write("    endcase\n")
        f.write("  end\n\n")
        
        f.write("  always_comb begin\n")
        f.write("    case (x_count-1)\n")
        for x_count in range(2, (SIZE_X+1)):
            fixed_point_value = round((1/x_count) * SCALING)
            f.write(f"      {WD_X}'d{x_count}: inv_x_count_prev = {WD_REAL}'b{fixed_point_value:0{WD_REAL}b}; // 1/{x_count} = {1/x_count:.10f}\n")
        f.write("      default: inv_x_count_prev = '0; // Default case\n")
        f.write("    endcase\n")
        f.write("  end\n")

        f.write("  always_comb begin\n")
        f.write("    case (x_count+1)\n")
        for x_count in range(2, (SIZE_X+1)):
            fixed_point_value = round((1/x_count) * SCALING)
            f.write(f"      {WD_X}'d{x_count}: inv_x_count_next = {WD_REAL}'b{fixed_point_value:0{WD_REAL}b}; // 1/{x_count} = {1/x_count:.10f}\n")
        f.write("      default: inv_x_count_next = '0; // Default case\n")
        f.write("    endcase\n")
        f.write("  end\n")
        f.write("endmodule\n") 
    print(f"SystemVerilog LUT saved to {output_file}")

if __name__ == "__main__":
    generate_inv_lut()
