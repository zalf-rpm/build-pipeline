
# from https://github.com/ipython/ipyparallel
# Interactive Parallel Computing with IPython
import os
import ipyparallel as ipp

cluster = ipp.Cluster(n=4)
with cluster as rc:
    ar = rc[:].apply_async(os.getpid)
    pid_map = ar.get_dict()