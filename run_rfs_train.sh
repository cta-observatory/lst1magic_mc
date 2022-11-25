#!/bin/bash

here=$(pwd)

configbase=${here}/config_base.yaml
mcpdir=/home/julian.sitarek/prog/magic-cta-pipe

#nsbnoises="0.5 1.0 1.5 2.0 2.5 3.0"
nsbnoises="0.5 1.0"

decs0="dec_2276"
#decs0="All"

particles="GammaDiffuse Protons"


indir0="/fefs/aswg/LST1MAGIC/mc/DL1Stereo"
outdir0="/fefs/aswg/LST1MAGIC/mc/models"

period="ST0316A"
version="v01.2"
batchA=dpps
#batchA=aswg
joblogdir=${here}/models/joblog
ssubdir0=${here}/models/ssub
# -----------------------
mkdir -p $outdir0 $joblogdir $ssubdir0
script=$mcpdir/magicctapipe/scripts/lst1_magic/lst1_magic_train_rfs.py

indir0=$indir0/$period/


nodeerrors=$joblogdir/node_errors.txt
startlog=$joblogdir/start.log
stoplog=$joblogdir/stop.log
failedlog=$joblogdir/failed.log
echo -n "" > $nodeerrors
echo -n "" >$startlog
echo -n "" >$stoplog
echo -n "" >$failedlog


for noisedim in $nsbnoises; do
    echo "Processing noisedim: "$noisedim
    indir1p=$indir0/NSB${noisedim}/Protons/$version/
    indir1g=$indir0/NSB${noisedim}/GammaDiffuse/$version/

    if [ $decs0 = "All" ]; then
	decs=$(basename -a $(ls -d $indir1p/dec*))
    else
	decs=$decs0
    fi

    for dec in $decs; do
	echo " processing "$dec
	tag0=NSB${noisedim}_${dec}

	outputdir=$outdir0/$period/NSB$noisedim/$version/$dec/
	logdir=$outputdir/logs
	traingdir=$outputdir/train_gamma
	trainpdir=$outputdir/train_proton
	mkdir -p $outputdir $logdir $traingdir $trainpdir

	ssubdir=${ssubdir0}
	mkdir -p $ssubdir

 	ssub_gh=$ssubdir/ssub_${tag0}_gh.sh
 	ssub_en=$ssubdir/ssub_${tag0}_en.sh
 	ssub_dir=$ssubdir/ssub_${tag0}_dir.sh

	for nodedirp in $(ls -d $indir1p/$dec/node*); do
	    node=$(basename $nodedirp)
	    nodedirg=$indir1g/$dec/$node
	    ngamma=$(ls $nodedirg/dl1_stereo*.h5 | wc -l)
	    nproton=$(ls $nodedirp/dl1_stereo*.h5 | wc -l)

	    echo $node $ngamma $nproton
	    if [ $ngamma -eq 0 ] || [ $nproton -eq 0 ]; then 
		echo "EMPTY/MISSING  NODE, skipping the other one"
		echo $nodedirg $ngamma $nodedirp $nproton >> $nodeerrors		
	    else
		echo "FINE"
		ln -s $nodedirg/dl1_stereo*.h5 $traingdir/
		ln -s $nodedirp/dl1_stereo*.h5 $trainpdir/
	    fi
	done

	echo $ssub_gh >> $startlog
	echo $ssub_en >> $startlog
	echo $ssub_dir >> $startlog

	cat<<EOF > $ssub_gh
#!/bin/sh
#SBATCH -p long
#SBATCH -A $batchA
#SBATCH -J RF_gh_${tag0}
#SBATCH --mem=46g
#SBATCH -n 1
#SBATCH -c 5
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a

time python $script \
--input-dir-gamma $traingdir \
--input-dir-proton $trainpdir \
--output-dir $outputdir \
--config-file  $configbase \
--train-classifier 

rc=\$?
if [ "\$rc" -ne "0" ]; then
  echo $ssub_gh \$rc >> $failedlog
fi
echo $ssub_gh \$rc >> $stoplog

EOF

	cat<<EOF > $ssub_en
#!/bin/sh
#SBATCH -p long
#SBATCH -A $batchA
#SBATCH -J RF_en_${tag0}
#SBATCH --mem=46g
#SBATCH -n 1
#SBATCH -c 5
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a

time python $script \
--input-dir-gamma $traingdir \
--output-dir $outputdir \
--config-file  $configbase \
--train-energy

rc=\$?
if [ "\$rc" -ne "0" ]; then
  echo $ssub_en \$rc >> $failedlog
fi
echo $ssub_en \$rc >> $stoplog

EOF

	cat<<EOF > $ssub_dir
#!/bin/sh
#SBATCH -p long
#SBATCH -A $batchA
#SBATCH -J RF_dir_${tag0}
#SBATCH --mem=46g
#SBATCH -n 1
#SBATCH -c 5
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a

time python $script \
--input-dir-gamma $traingdir \
--output-dir $outputdir \
--config-file  $configbase \
--train-disp

rc=\$?
if [ "\$rc" -ne "0" ]; then
  echo $ssub_dir \$rc >> $failedlog
fi
echo $ssub_dir \$rc >> $stoplog

EOF

        chmod +x $ssub_gh $ssub_en $ssub_dir
	cd $logdir
	sbatch $ssub_gh
	sbatch $ssub_en
	sbatch $ssub_dir
	cd $here
    done
done



echo "Are there errors ?"
cat $nodeerrors
