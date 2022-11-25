#!/bin/bash

dir=$1

type="real"
grep ^$type $dir/node*/logs/slurm* | sed -e 's/.*'$type'//' -e 's/m/ /' -e 's/s//' | awk 'BEGIN{totals=0}{totals+=$1*60 + $2}END{print("Total time=",totals/3600,"h")}'
n=$(grep ^$type $dir/node*/logs/slurm* |wc -l)
echo "Number of processed files: $n"

du -hcs $dir/node*
