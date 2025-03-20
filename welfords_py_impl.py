import numpy as np

class WelfordMatrixTracker:
  def __init__(self, matrix_shape):
    self.n = 0  
    self.matrix_shape = matrix_shape
    self.mean = np.zeros(matrix_shape, dtype=float)
    self.M2 = np.zeros(matrix_shape, dtype=float)  
    self.overall_mean = 0.0
    self.overall_M2 = 0.0
    self.total_elements = 0
  
  def update(self, matrix):
    if matrix.shape != self.matrix_shape:
      raise ValueError(f"Expected matrix of shape {self.matrix_shape}, got {matrix.shape}")
    self.n += 1
    delta = matrix - self.mean
    self.mean += delta / self.n
    delta2 = matrix - self.mean
    self.M2 += delta * delta2
    flat_matrix = matrix.flatten()
    for val in flat_matrix:
      self.total_elements += 1
      delta = val - self.overall_mean
      self.overall_mean += delta / self.total_elements
      delta2 = val - self.overall_mean
      self.overall_M2 += delta * delta2
    element_variance = self.M2 / self.n if self.n > 1 else np.zeros(self.matrix_shape)
    overall_variance = self.overall_M2 / self.total_elements if self.total_elements > 1 else 0.0
    return self.mean, element_variance, overall_variance
  
  def get_stats(self):
    element_variance = self.M2 / self.n if self.n > 1 else np.zeros(self.matrix_shape)
    overall_variance = self.overall_M2 / self.total_elements if self.total_elements > 1 else 0.0
    return self.mean, element_variance, overall_variance

if __name__ == "__main__":
  n = 4
  tracker = WelfordMatrixTracker((n, 1))
  matrices = [
    np.array([[1.0], [2.0], [3.0], [10.1]]),
    np.array([[4.0], [5.0], [6.0], [9.1]]),
    np.array([[7.0], [8.0], [9.0], [10.2]]),
    np.array([[10.0], [11.0], [12.0], [10.2]])
  ]
  print("Processing matrices one by one:")
  for i, matrix in enumerate(matrices):
    mean, element_var, overall_var = tracker.update(matrix)
    print(f"\nAfter processing matrix {i+1}:")
    print(f"Matrix: \n{matrix}")
    print(f"Current mean: \n{mean}")
    print(f"Element-wise variance: \n{element_var}")
    print(f"Overall variance: {overall_var}")
