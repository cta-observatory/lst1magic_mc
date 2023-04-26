#!/bin/bash

here=$(pwd)

configdir=${here}/config/
configbase=${here}/config_base.yaml
mcpdir=/home/julian.sitarek/prog/magic-cta-pipe

nsbnoises="2.124"
noisebright="2.766"
biasdim="0.738"

#decs0="dec_6166"
#decs0="dec_2276"
decs0="All"  # special keyword

#nodes0="All"
nodes0=$(cat nodes_test.txt)

#file with previous iteration of processing, to rerun only the jobs that failed or were not finished
#previous_rcs=/home/julian.sitarek/ws/mc_proc/lstprod2/20230425_process_dec_6166_Franca/v1.3/dl0/joblog/stop_*

# TRAIN SAMPLES
# e.g. /fefs/aswg/workspace/georgios.voutsinas/AllSky/TrainingDataset/GammaDiffuse/dec_2276/sim_telarray/node_corsika_theta_16.087_az_108.090_/output_v1.4
#indir0="/fefs/aswg/workspace/georgios.voutsinas/AllSky/TrainingDataset/"
indir0="/fefs/aswg/data/mc/DL0/LSTProd2/TrainingDataset"
particles="GammaDiffuse Protons"

# TEST SAMPLES
# e.g. /fefs/aswg/workspace/georgios.voutsinas/AllSky/TestDataset/sim_telarray/node_theta_10.0_az_102.199_/output_v1.4 
#indir0="/fefs/aswg/workspace/georgios.voutsinas/AllSky/TestDataset/"
#e.g. /fefs/aswg/data/mc/DL0/LSTProd2/TestDataset/sim_telarray/node_theta_10.0_az_102.199_/output_v1.4
indir0="/fefs/aswg/data/mc/DL0/LSTProd2/TestDataset"
particles="GammaTest"  # GammaTest is special names used in ifs later on !!

#outdir0="/fefs/aswg/LST1MAGIC/mc/DL1"
outdir0="/fefs/aswg/LST1MAGIC/mc/special/20230425/DL1"

#simtel="simtel_v1.4"
simtel="sim_telarray"
period="ST0316A"
version="v01.3"
batchA=dpps
#batchA=aswg
runsperjob=100

joblogdir=${here}/dl0/joblog
ssubdir0=${here}/dl0/ssub
# -----------------------
mkdir -p $outdir0 $joblogdir $ssubdir0 $configdir
script=$mcpdir/magicctapipe/scripts/lst1_magic/lst1_magic_mc_dl0_to_dl1.py
script2=$mcpdir/magicctapipe/scripts/lst1_magic/merge_hdf_files.py

for noisedim in $nsbnoises; do
    echo "Processing noisedim: "$noisedim
    confignsb=$configdir/config_nsb${noisedim}.yaml
    #noisebright=$(echo $noisedim | awk '{print 1.15*$1^1.115}')
    #biasdim=$(echo $noisedim | awk '{print 0.358*$1^0.805}')
    sed -e 's/extra_noise_in_dim_pixels.*/extra_noise_in_dim_pixels: '$noisedim'/g' \
	-e 's/extra_bias_in_dim_pixels.*/extra_bias_in_dim_pixels: '$biasdim'/g' \
	-e 's/extra_noise_in_bright_pixels.*/extra_noise_in_bright_pixels: '$noisebright'/g' $configbase > $confignsb

    for particle in $particles; do
	echo "   processing "$particle
	if [ $particle = "GammaTest" ]; then
	    decs="Grid"
	elif [ "$decs0" = "All" ]; then
	    decs=$(basename -a $(ls -d $indir0/$particle/dec*))
	else
	    decs=$decs0
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

	    if [ "$nodes0" = "All" ]; then
		nodes=$(basename -a $(ls -d $indir1/node*))
	    else
		nodes=$nodes0
	    fi

#	    for nodedir in $(ls -d $indir1/node*); do
#		indir=$nodedir/output_v1.4
#		node=$(basename $nodedir)
	    for node in $nodes; do
		nodedir=$indir1/$node
		indir=$nodedir/output_v1.4
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
			bunchdir=$bunchdir0/bunch$ibunch
			first=$(echo $thisruns|cut -f1 -d' ')
 			ssub=$ssubdir/ssub_${node}_runs${first}.sh
			if [[ ! -z $previous_rcs ]]; then
			    old_rc=$(grep $ssub $previous_rcs| awk '{print $2}' | tail -n 1)
			    echo "oldrc='"$old_rc"'"
			fi

			if [ "$old_rc" = "0" ]; then
			    echo "$ssub already processed skipping"
			else
			    
			    echo "bunch $ibunch runs: "$thisruns			    
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
			fi
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




