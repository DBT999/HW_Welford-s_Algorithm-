import numpy as np

# Fixed-point parameters
FRAC_BITS = 16
VALUE_WIDTH = 32

# Test vectors from testbench (in fixed-point format)
test_vectors = [
    [0x00010000, 0x00020000, 0x00030000, 0x000A199A],  # Vector 1
    [0x00040000, 0x00050000, 0x00060000, 0x0009199A],  # Vector 2
    [0x00070000, 0x00080000, 0x00090000, 0x000A3333],  # Vector 3
    [0x000A0000, 0x000B0000, 0x000C0000, 0x000A3333]   # Vector 4
]

# Convert fixed-point to float
def fixed_to_float(fixed_val):
    if fixed_val & (1 << (VALUE_WIDTH - 1)):  # If negative
        fixed_val = fixed_val - (1 << VALUE_WIDTH)
    return fixed_val / (2 ** FRAC_BITS)

# Convert test vectors to floating point
float_vectors = []
for vec in test_vectors:
    float_vec = [fixed_to_float(val) for val in vec]
    float_vectors.append(float_vec)
    print(f"Vector as float: {float_vec}")

# Welford's online algorithm for mean and covariance
def welford_covariance(data):
    n = 0
    mean = np.zeros(len(data[0]))
    M2 = np.zeros((len(data[0]), len(data[0])))  # For covariance matrix
    
    for x in data:
        n += 1
        delta = np.array(x) - mean
        mean += delta / n
        delta2 = np.array(x) - mean
        
        # Update M2 matrix for all i,j pairs
        for i in range(len(x)):
            for j in range(len(x)):
                M2[i, j] += delta[i] * delta2[j]
    
    if n < 2:
        return np.zeros((len(data[0]), len(data[0])))
    else:
        # Convert M2 to covariance matrix
        covariance = M2 / (n - 1)
        return covariance

# Calculate covariance with Welford's method
cov_matrix = welford_covariance(float_vectors)
print("\nCovariance Matrix:")
print(cov_matrix)

# Calculate variance (diagonal of covariance matrix)
variance = np.diagonal(cov_matrix)
print("\nVariance Vector (diagonal of covariance):")
print(variance)

# Calculate total variance
total_variance = np.sum(variance)
print("\nTotal Variance:")
print(total_variance)

# Convert floating point to fixed-point
def float_to_fixed(float_val):
    fixed_val = int(float_val * (2 ** FRAC_BITS))
    if fixed_val < 0:
        fixed_val = fixed_val & ((1 << VALUE_WIDTH) - 1)  # Mask to VALUE_WIDTH bits
    return fixed_val

# Format as hex string
def format_fixed_hex(val):
    return f"0x{val:08X}"

# Convert covariance matrix to fixed-point
print("\nCovariance Matrix in Fixed-Point Hex Format:")
for row in cov_matrix:
    fixed_row = [float_to_fixed(val) for val in row]
    hex_row = [format_fixed_hex(val) for val in fixed_row]
    print(hex_row)

print("\nVariance Vector in Fixed-Point Hex Format:")
fixed_variance = [float_to_fixed(val) for val in variance]
hex_variance = [format_fixed_hex(val) for val in fixed_variance]
print(hex_variance)

print("\nTotal Variance in Fixed-Point Hex Format:")
fixed_total = float_to_fixed(total_variance)
print(format_fixed_hex(fixed_total))