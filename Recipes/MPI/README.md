```bash
export FI_PROVIDER=cxi
srun --mpi=pmi2 -p debug -N 1 -n 2 -A <account> singularity exec -B $PWD,/opt/cray/libfabric/1.15.2.0/lib64:/opt/libfabric/lib,/usr/lib64/libcxi.so.1 openmpi_4.1.6.sif <command>
```
