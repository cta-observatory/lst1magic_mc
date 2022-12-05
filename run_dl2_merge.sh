#!/bin/bash

here=$(pwd)

configbase=${here}/config_base.yaml
mcpdir=/home/julian.sitarek/prog/magic-cta-pipe

#nsbnoises="0.5 1.0 1.5 2.0 2.5 3.0"
#nsbnoises="0.5 1.0"
nsbnoises="1.5 2.0 2.5 3.0"


#decs0="dec_6166 dec_min_2924"
decs0="All" # special keyword
#decs0="dec_min_1802"

indir0="/fefs/aswg/LST1MAGIC/mc/DL2"

period="ST0316A"
version="v01.2"
batchA=dpps
#batchA=aswg
joblogdir=${here}/dl2merge/joblog
ssubdir0=${here}/dl2merge/ssub
# -----------------------
mkdir -p $joblogdir $ssubdir0
script=$mcpdir/magicctapipe/scripts/lst1_magic/merge_hdf_files.py


indir0=$indir0/$period/

particle=GammaTest

for noisedim in $nsbnoises; do
    echo "Processing noisedim: "$noisedim
    indir1=$indir0/NSB${noisedim}/$particle/$version/
    if [ "$decs0" = "All" ]; then
	decs=$(basename -a $(ls -d $indir1/dec*))
    else
	decs=$decs0
    fi
    for dec in $decs; do
	echo " processing "$dec

	tag0=NSB${noisedim}_${dec}
	
	startlog=$joblogdir/start_${tag0}.log
	stoplog=$joblogdir/stop_${tag0}.log
	failedlog=$joblogdir/failed_${tag0}.log
	ssubdir=${ssubdir0}/${tag0}
	mkdir -p $ssubdir
	echo -n "" >$startlog
	echo -n "" >$stoplog
	echo -n "" >$failedlog

	for nodedir in $(ls -d $indir1/$dec/node*); do
	    node=$(basename $nodedir)
	    echo "  processing "$node
	    tag1=${tag0}_${node}

	    outputdir=$indir1/$dec
	    logdir=$outputdir/logs
	    mkdir -p $outputdir $logdir 
	    echo $outputdir
 	    ssub=$ssubdir/ssub_${node}.sh
	    echo $ssub >> $startlog

	    cat<<EOF > $ssub
#!/bin/sh
#SBATCH -p short
#SBATCH -A $batchA
#SBATCH -J dl2merge_${tag1}
#SBATCH --mem=3g
#SBATCH -n 1
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a


time python $script --input-dir $nodedir --output-dir $outputdir 
rc=\$?
if [ "\$rc" -ne "0" ]; then
  echo $ssub \$rc >> $failedlog
fi
echo $ssub \$rc >> $stoplog

EOF

            chmod +x $ssub
	    cd $logdir
	    sbatch $ssub
	    cd $here
	done
    done
done




