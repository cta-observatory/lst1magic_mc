# lst1magic_mc
MC processing scripts for LST-1+MAGIC joint analysis

## Basic chain (in the sequence as they are run):

* `run_dl0_to_dl1.sh`
* `run_dl1_stereo.sh`
* `run_dl2.sh`
* `run_dl2_merge.sh`
* `run_rfs_train.sh`

## Helping scripts:

* `countjobtime.sh` - for accounting of how much resources were used
* `checkprogress.sh` - for tracking the status of the running processing
* `trimmc.sh` - special macro to remove some of the MCs with excessively large statistics
