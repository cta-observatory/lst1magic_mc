#!/bin/bash

here=$(pwd)

configbase=${here}/config_base.yaml
mcpdir=/home/julian.sitarek/prog/magic-cta-pipe

#nsbnoises="0.5 1.0 1.5 2.0 2.5 3.0"
#nsbnoises="0.5 1.0"
nsbnoises="1.5 2.0 2.5 3.0"

#decs0="dec_min_1802"
#decs0="All"
#decs0="dec_3476 dec_4822 dec_6166 dec_6676 dec_931 dec_min_2924  dec_min_413"
decs0="dec_2276"

indir0="/fefs/aswg/LST1MAGIC/mc/DL1Stereo"
outdir0="/fefs/aswg/LST1MAGIC/mc/DL2"
rfdir0="/fefs/aswg/LST1MAGIC/mc/models"

period="ST0316A"
version="v01.2"
batchA=dpps
#batchA=aswg
joblogdir=${here}/dl2/joblog
ssubdir0=${here}/dl2/ssub
# -----------------------
mkdir -p $outdir0 $joblogdir $ssubdir0
script=$mcpdir/magicctapipe/scripts/lst1_magic/lst1_magic_dl1_stereo_to_dl2.py


indir0=$indir0/$period/
rfdir0=$rfdir0/$period/

particle=GammaTest

for noisedim in $nsbnoises; do
    echo "Processing noisedim: "$noisedim
    rfdir1=$rfdir0/NSB${noisedim}/$version/
    if [ "$decs0" = "All" ]; then
	decs=$(basename -a $(ls -d $rfdir1/dec*))
    else
	decs=$decs0
    fi
    for dec in $decs; do
	echo " processing "$dec

	rfdir=$rfdir1/$dec

	tag0=NSB${noisedim}_${dec}
	
	startlog=$joblogdir/start_${tag0}.log
	stoplog=$joblogdir/stop_${tag0}.log
	failedlog=$joblogdir/failed_${tag0}.log
	ssubdir=${ssubdir0}/${tag0}
	mkdir -p $ssubdir
	echo -n "" >$startlog
	echo -n "" >$stoplog
	echo -n "" >$failedlog
	indir1=$indir0/NSB${noisedim}/$particle/$version/

	for nodedir in $(ls -d $indir1/node*); do
	    node=$(basename $nodedir)
	    echo "  processing "$node
	    tag1=${tag0}_${node}

	    outputdir=$outdir0/$period/NSB$noisedim/$particle/$version/$dec/$node
	    logdir=$outputdir/logs
	    mkdir -p $outputdir $logdir 
	    echo $outputdir
	    for infile in $(ls $nodedir/dl1_*h5); do
		runs=( $(basename $infile | awk -F"_run" '{print $2}' | cut -d'.' -f 1) )
 		ssub=$ssubdir/ssub_${node}_runs${runs}.sh
		echo $ssub >> $startlog

#SBATCH --mem=48g
		cat<<EOF > $ssub
#!/bin/sh
#SBATCH -p short
#SBATCH -A $batchA
#SBATCH -J dl2_${tag1}_${runs}
#SBATCH --mem=63g
#SBATCH -n 1
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a


time python $script --input-file-dl1 $infile --input-dir-rfs $rfdir --output-dir $outputdir
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




