#!/bin/bash

here=$(pwd)

configbase=${here}/config_base.yaml
mcpdir=/home/julian.sitarek/prog/magic-cta-pipe

nsbnoises="0.5 1.0 1.5 2.0 2.5 3.0"
#nsbnoises="0.5 1.0"


#particles="GammaDiffuse Protons"
particles="GammaTest"  # GammaTest is special names used in ifs later on !!

indir0="/fefs/aswg/LST1MAGIC/mc/DL1"
outdir0="/fefs/aswg/LST1MAGIC/mc/DL1Stereo"

period="ST0316A"
version="v01.2"
batchA=dpps
#batchA=aswg
joblogdir=${here}/dl1stereo/joblog
ssubdir0=${here}/dl1stereo/ssub
# -----------------------
mkdir -p $outdir0 $joblogdir $ssubdir0
script=$mcpdir/magicctapipe/scripts/lst1_magic/lst1_magic_stereo_reco.py


indir0=$indir0/$period/

for noisedim in $nsbnoises; do
    echo "Processing noisedim: "$noisedim
    for particle in $particles; do
	echo "   processing "$particle
	indir1=$indir0/NSB${noisedim}/$particle/$version/
	
	if [ $particle = "GammaTest" ]; then
	    decs="Grid"
	else 
	    decs=$(basename -a $(ls -d $indir1/dec*))
	fi
	for dec in $decs; do
	    echo "   processing "$dec
	    indir2=$indir1
	    if [ $particle = "GammaTest" ]; then
		dec=""
	    else
		indir2=$indir1/$dec
	    fi
	    tag0=NSB${noisedim}_${dec}_${particle}
	    
	    startlog=$joblogdir/start_${tag0}.log
	    stoplog=$joblogdir/stop_${tag0}.log
	    failedlog=$joblogdir/failed_${tag0}.log
	    ssubdir=${ssubdir0}/${tag0}
	    mkdir -p $ssubdir
	    echo -n "" >>$startlog
	    echo -n "" >>$stoplog
	    echo -n "" >>$failedlog
	    for nodedir in $(ls -d $indir2/node*); do
		node=$(basename $nodedir)
		echo "      processing "$node
		tag1=${tag0}_${node}

		outputdir=$outdir0/$period/NSB$noisedim/$particle/$version/$dec/$node
		logdir=$outputdir/logs
		mkdir -p $outputdir $logdir 
		echo $outputdir
		for infile in $(ls $nodedir/dl1_*h5); do
		    runs=( $(basename $infile | awk -F"_run" '{print $2}' | cut -d'.' -f 1) )
 		    ssub=$ssubdir/ssub_${node}_runs${runs}.sh
		    echo $ssub >> $startlog

		    cat<<EOF > $ssub
#!/bin/sh
#SBATCH -p long
#SBATCH -A $batchA
#SBATCH -J st_${tag0}_${node}_${runs}
#SBATCH --mem=2g
#SBATCH -n 1
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a

time python $script --input-file $infile --output-dir $outputdir --config-file $configbase
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
done




