#!/bin/bash

here=$(pwd)

configdir=${here}/irf_config
mcpdir=/home/julian.sitarek/prog/magic-cta-pipe

#nsbnoises="0.5 1.0 1.5 2.0 2.5 3.0"
#nsbnoises="0.5 1.0"
nsbnoises="1.5 2.0 2.5 3.0"


#decs0="dec_6166 dec_min_2924"
decs0="All" # special keyword
#decs0="dec_min_1802"

indir0="/fefs/aswg/LST1MAGIC/mc/DL2"
outdir0="/fefs/aswg/LST1MAGIC/mc/IRF"

period="ST0316A"
version="v01.2"
batchA=dpps
#batchA=aswg
joblogdir=${here}/irf/joblog
ssubdir0=${here}/irf/ssub
# -----------------------
mkdir -p $joblogdir $ssubdir0
script=$mcpdir/magicctapipe/scripts/lst1_magic/lst1_magic_create_irf.py


indir0=$indir0/$period/
outdir0=$outdir0/$period/

particle=GammaTest

configs=$(ls $configdir/config*.yaml)

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

	for config in $configs; do
	    cuts=$(basename $config | sed -e 's/config_//' -e 's/\.yaml//')
	    outputdir=$outdir0/NSB${noisedim}/$particle/$version/$cuts/$dec
	    logdir=$outputdir/logs
	    mkdir -p $outputdir $logdir 

	    tag0=NSB${noisedim}_${cuts}_${dec}
	    
	    startlog=$joblogdir/start_${tag0}.log
	    stoplog=$joblogdir/stop_${tag0}.log
	    failedlog=$joblogdir/failed_${tag0}.log
	    ssubdir=${ssubdir0}/${tag0}
	    mkdir -p $ssubdir
	    echo -n "" >$startlog
	    echo -n "" >$stoplog
	    echo -n "" >$failedlog


	    for nodefile in $(ls -d $indir1/$dec/dl2_*h5); do
		node=$(basename $nodefile | sed -e 's/dl2_gamma_//' -e 's/_LST-1_MAGIC_run.*//')
		echo "  processing "$node, $cuts
		tag1=${tag0}_${node}
 		ssub=$ssubdir/ssub_${node}.sh
		echo $ssub >> $startlog

#SBATCH --mem=3g
		cat<<EOF > $ssub
#!/bin/sh
#SBATCH -p short
#SBATCH -A $batchA
#SBATCH -J IRF_${tag1}
#SBATCH --mem=4500m
#SBATCH -n 1
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a


time python $script \\
--input-file-gamma $nodefile \\
--output-dir $outputdir \\
--config-file $config

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
done




