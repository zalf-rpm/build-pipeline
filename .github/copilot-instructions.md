# HPC Cluster Documentation - AI Agent Guide

## Project Overview
This repository documents an HPC (High Performance Computing) cluster infrastructure with detailed specifications for compute resources, storage systems, SLURM job scheduling, and best practices for users. The documentation serves both as reference material for cluster users and as a source of truth for cluster capabilities.

## Key Architecture & Concepts

### Compute Resources
- **Partitions**: compute (100 nodes), gpu (5 nodes), highmem (25 nodes), fat (2 nodes)
- **Critical Pattern**: GPU partition uses **exclusive node access** - users get ALL GPUs on a node (cannot request specific GPU count via `--gres=gpu:1`)
- **Hardware Heterogeneity**: GPU nodes vary significantly (V100 vs H100). H100 node (gpu005) requires `#SBATCH --nodelist=gpu005` to target specifically
- See `cluster_specs.md` for precise specs: CPU count, memory, scratch space per node type

### Storage Hierarchy (Non-backed up - users responsible for backups)
1. **Home** (`/home/user`): For scripts, configs, source code only - slow NFS for small files
2. **Scratch** (`/scratch`): Local SSD, per-node, **must clean up after jobs** 
3. **BeeGFS** (`/beegfs/user`): 160TB parallel filesystem, **recommended for data/packages** (10 Gbps), fast I/O for many files
4. **Archive** (`/data01/department/user`): Long-term storage, 25TB per user limit, request-based access
5. **Common** (`/beegfs/common`): Shared Singularity images and datasets (climate, MIC) - read metadata for details

**Critical Rule**: Install Python/R environments in BeeGFS, NOT home directory (NFS performance penalty)

### SLURM Job Submission
- **Version**: 24.11
- **Default Partition**: compute
- **Memory Warning**: Must specify `--mem` - otherwise receives ALL node memory, blocking other jobs
- **Standard Headers**: Use provided template in `cluster_specs.md` with proper logging to `logs/` directory

## Developer Workflows

### Common Task: Creating Job Scripts
1. Use `#SBATCH` standard header from `cluster_specs.md` section "Standard Job Template"
2. Always specify: `--mem`, `--cpus-per-task`, `--time`
3. For multi-GPU work: either code supports multiple GPUs (V100/H100 mixed), or document GPU requirements
4. Version outputs: use `SLURM_JOB_ID` and/or timestamps to prevent overwrites in parallel job scenarios
5. Implement cleanup traps: `trap 'rm -rf "${TMPDIR:?}"' EXIT` for scratch cleanup

### GPU Job Strategy
- If targeting **H100 only**: add `#SBATCH --nodelist=gpu005`
- If targeting **any V100**: job will run on gpu001-gpu004 (4 nodes, 2x V100 each)
- Document GPU utilization requirements - exclusive node access means paying for all GPUs

### Array Jobs (Multiple Similar Tasks)
Use `#SBATCH --array=0-3` with indexed input arrays - see example in `cluster_specs.md`

## Project-Specific Conventions

### Documentation Structure
- `README.md`: Entry point - currently contains minimal content, points to `cluster_specs.md`
- `cluster_specs.md`: Single source of truth - organized by sections: login nodes, partitions, storage, SLURM, modules, containerization, recommendations, policies, GPU details, examples

### Cluster Access Restrictions
- Login nodes only (login01-02): NO compute jobs, no heavy IDEs like VSCode
- Compute nodes: Only reachable via SSH through login nodes during job runtime
- Requires valid Linux account (UID/GID from LDAP)

### Key Policies to Reference When Adding Content
- **Fair Use**: No quotas, but usage tracked; allocate only needed resources
- **Backups**: User responsibility - cluster storage unbackedup
- **Scratch Cleanup**: Mandatory after job completion
- **No Installation**: No root/system-wide package installation allowed

## Integration Points & External Systems

### Software Management
- **Modules**: Environment Modules system (minimal pre-installation)
- **Containerization**: Singularity/Apptainer supported, `.sif` files preferred
- **Shared Images**: `/beegfs/common/singularity` - coordinate with team before adding

### Support & Contact
- Support: MAS workgroup (see intranet)
- Data Management: FDM workgroup (for publishing datasets)
- User Groups: HPC support team manages

### Common Shared Data
- `/beegfs/common/data/climate`: Climate datasets
- `/beegfs/common/data/MIC`: MIC datasets
- Always check metadata files in shared directories

## When Updating Documentation

1. **GPU Hardware Changes**: Update the GPU nodes table and exclusivity note if hardware varies
2. **Storage Recommendations**: BeeGFS is primary recommendation for performance - highlight in relevant sections
3. **Job Examples**: Include output file versioning patterns - essential for batch workflows
4. **Partition Selection Guide**: Map use cases (CPU-intensive → compute, memory → highmem/fat)
5. **New Features**: Always document memory/scratch tradeoffs and cleanup requirements

## Avoid These Common Mistakes (Reference from cluster_specs.md)
- Not specifying `--mem` in SLURM scripts
- Storing Python environments in home directory (use BeeGFS)
- Not cleaning up /tmp and /scratch after jobs
- Running heavy processes on login nodes
- Creating many small files instead of larger batches
- Not versioning output files in parallel job scenarios
