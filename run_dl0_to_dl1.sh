#!/bin/bash

here=$(pwd)

configdir=${here}/config/
configbase=${here}/config_base.yaml
mcpdir=/home/julian.sitarek/prog/magic-cta-pipe

nsbnoises="0.5 1.0 1.5 2.0 2.5 3.0"
#nsbnoises="0.5 1.0"


# TRAIN SAMPLES
# e.g. /fefs/aswg/workspace/georgios.voutsinas/AllSky/TrainingDataset/GammaDiffuse/dec_2276/sim_telarray/node_corsika_theta_16.087_az_108.090_/output_v1.4
#indir0="/fefs/aswg/workspace/georgios.voutsinas/AllSky/TrainingDataset/"
#particles="GammaDiffuse Protons"

# TEST SAMPLES
# e.g. /fefs/aswg/workspace/georgios.voutsinas/AllSky/TestDataset/sim_telarray/node_theta_10.0_az_102.199_/output_v1.4 
indir0="/fefs/aswg/workspace/georgios.voutsinas/AllSky/TestDataset/"
particles="GammaTest"  # GammaTest is special names used in ifs later on !!

#indir0="/fefs/aswg/mc/LSTProd2/TrainingDataset"
outdir0="/fefs/aswg/LST1MAGIC/mc/DL1"

#simtel="simtel_v1.4"
simtel="sim_telarray"
period="ST0316A"
version="v01.2"
batchA=dpps
#batchA=aswg
runsperjob=100

joblogdir=${here}/joblog
ssubdir0=${here}/ssub
# -----------------------
mkdir -p $outdir0 $joblogdir $ssubdir0 $configdir
script=$mcpdir/magicctapipe/scripts/lst1_magic/lst1_magic_mc_dl0_to_dl1.py
script2=$mcpdir/magicctapipe/scripts/lst1_magic/merge_hdf_files.py

for noisedim in $nsbnoises; do
    echo "Processing noisedim: "$noisedim
    confignsb=$configdir/config_nsb${noisedim}.yaml
    noisebright=$(echo $noisedim | awk '{print 1.15*$1^1.115}')
    biasdim=$(echo $noisedim | awk '{print 0.358*$1^0.805}')
    sed -e 's/extra_noise_in_dim_pixels.*/extra_noise_in_dim_pixels: '$noisedim'/g' \
	-e 's/extra_bias_in_dim_pixels.*/extra_bias_in_dim_pixels: '$biasdim'/g' \
	-e 's/extra_noise_in_bright_pixels.*/extra_noise_in_bright_pixels: '$noisebright'/g' $configbase > $confignsb

    for particle in $particles; do
	echo "   processing "$particle
	if [ $particle = "GammaTest" ]; then
	    decs="Grid"
	else 
	    decs=$(basename -a $(ls -d $indir0/$particle/dec*))
	fi
	for dec in $decs; do
	    echo "   processing "$dec
	    if [ $particle = "GammaTest" ]; then
		indir1=$indir0/$simtel
		dec=""
	    else
		indir1=$indir0/$particle/$dec/$simtel	
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
	    for nodedir in $(ls -d $indir1/node*); do
		indir=$nodedir/output_v1.4
		node=$(basename $nodedir)
		echo "      processing "$node
		tag1=${tag0}_${node}
		echo $tag

		outputdir=$outdir0/$period/NSB$noisedim/$particle/$version/$dec/$node
		logdir=$outputdir/logs
		bunchdir0=$outputdir/bunchit
		mkdir -p $outputdir $logdir $bunchdir0
		echo $outputdir
		runs=( $(ls $indir/simtel*.simtel.gz | awk -F"_run" '{print $2}' | cut -d'.' -f 1 | sort -n) )
		lastrun=${runs[-1]}
		nruns=${#runs[@]}
		echo "Runs: "${runs[0]} $lastrun", in total:"$nruns
		thisruns=" "
		i=0
		ii=0
		ibunch=0
		while (( $i < nruns ))
		do
		    thisruns="$thisruns${runs[i]} "
		    ii=$(( ii + 1 ))
		    i=$(( i + 1 ))
		    if [ "$ii" -eq "$runsperjob" ] || [ "$i" -eq "$nruns" ]; then
			echo "bunch $ibunch runs: "$thisruns
			bunchdir=$bunchdir0/bunch$ibunch
			first=$(echo $thisruns|cut -f1 -d' ')
 			ssub=$ssubdir/ssub_${node}_runs${first}.sh
			echo $ssub >> $startlog

			cat<<EOF > $ssub
#!/bin/sh
#SBATCH -p long
#SBATCH -A $batchA
#SBATCH -J dl0_${tag0}_${node}_${first}
#SBATCH --mem=2g
#SBATCH -n 1
 
ulimit -l unlimited
ulimit -s unlimited
ulimit -a
#cd $logdir
mkdir -p $bunchdir
for run in $thisruns; do
  plik=\$(ls $indir/simtel*_run\${run}.simtel.gz)
  time python $script  --input-file \$plik  --output-dir $bunchdir --config-file $confignsb
  rc=\$?
if [ "\$rc" -ne "0" ]; then
  echo \$plik \$rc >> $failedlog
fi

done
time python $script2  --input-dir $bunchdir  --output-dir $outputdir/
rc=\$?
echo $ssub \$rc >> $stoplog

EOF

                        chmod +x $ssub
			cd $logdir
			sbatch $ssub
			cd $here

			thisruns=""
			ibunch=$(( ibunch + 1 ))
			ii=0
		    fi
#
		done


	    done
	done
    done
done




