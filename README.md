This calculates a rolling variance over all arriving elements. The elements are MATRIX_SIZEx1 vectors. The mean is computed with each arriving element. The variance of each element is computed when compute_variance goes high. The total variance is also computed at the same time. A valid and up to date variance, total variance, and mean are available on valid out. 

AXIMM interface in progress.

This includes the LUT generator script, the SV LUT, and a python Welford's.

I have also included the stats_accum_cov_seq.sv which computes the covariance as intended but in a sequential manner. Also have included the testbench and the welford's for covariance in python.
