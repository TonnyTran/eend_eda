#!/bin/bash

stage=0

# The datasets for training must be formatted as kaldi data directory.
# Also, make sure the audio files in wav.scp are 'regular' wav files.
# Including piped commands in wav.scp makes training very slow
train_2spk_set=data/simu/data/swb_sre_tr_ns2_beta2_100000
valid_2spk_set=data/simu/data/swb_sre_cv_ns2_beta2_500
train_set=data/simu/data/swb_sre_tr_ns1n2n3n4_beta2n2n5n9_100000
valid_set=data/simu/data/swb_sre_cv_ns1n2n3n4_beta2n2n5n9_500
adapt_set=data/eval/dihard3_dev_8k
adapt_valid_set=data/eval/dihard3_eval_8k

# Base config files for {train,infer}.py
train_2spk_config=conf/eda/train_2spk.yaml
train_config=conf/eda/train.yaml
infer_config=conf/eda/infer.yaml
adapt_config=conf/eda/adapt.yaml

# Additional arguments passed to {train,infer}.py.
# You need not edit the base config files above
train_2spk_args=
train_args=
infer_args=
adapt_args=

# 2-speaker model averaging options
average_2spk_start=91
average_2spk_end=100

# Model averaging options
average_start=16
average_end=25

# Adapted model averaging options
adapt_average_start=91
adapt_average_end=100

# Resume training from snapshot at this epoch
# TODO: not tested
resume=-1

# Debug purpose
debug=

. path.sh
. cmd.sh
. parse_options.sh || exit

set -eu

if [ "$debug" != "" ]; then
    # debug mode
    train_set=data/simu/data/swb_sre_tr_ns2_beta2_1000
    train_config=conf/debug/train.yaml
    average_start=3
    average_end=5
    adapt_config=conf/debug/adapt.yaml
    adapt_average_start=6
    adapt_average_end=10
fi

# Parse the config file to set bash variables like: $train_frame_shift, $infer_gpu
eval `yaml2bash.py --prefix train $train_config`
eval `yaml2bash.py --prefix infer $infer_config`

# Append gpu reservation flag to the queuing command
if [ $train_gpu -le 0 ]; then
    train_cmd+=" --gpu 1"
fi
if [ $infer_gpu -le 0 ]; then
    infer_cmd+=" --gpu 1"
fi

train_2spk_id=$(basename $train_2spk_set)
valid_2spk_id=$(basename $valid_2spk_set)
train_id=$(basename $train_set)
valid_id=$(basename $valid_set)
train_2spk_config_id=$(echo $train_2spk_config | sed -e 's%conf/%%' -e 's%/%_%' -e 's%\.yaml$%%')
train_config_id=$(echo $train_config | sed -e 's%conf/%%' -e 's%/%_%' -e 's%\.yaml$%%')
infer_config_id=$(echo $infer_config | sed -e 's%conf/%%' -e 's%/%_%' -e 's%\.yaml$%%')
adapt_config_id=$(echo $adapt_config | sed -e 's%conf/%%' -e 's%/%_%' -e 's%\.yaml$%%')

# Additional arguments are added to config_id
train_2spk_config_id+=$(echo $train_2spk_args | sed -e 's/\-\-/_/g' -e 's/=//g' -e 's/ \+//g')
train_config_id+=$(echo $train_args | sed -e 's/\-\-/_/g' -e 's/=//g' -e 's/ \+//g')
infer_config_id+=$(echo $infer_args | sed -e 's/\-\-/_/g' -e 's/=//g' -e 's/ \+//g')
adapt_config_id+=$(echo $adapt_args | sed -e 's/\-\-/_/g' -e 's/=//g' -e 's/ \+//g')

model_2spk_id=$train_2spk_id.$valid_2spk_id.$train_2spk_config_id
model_2spk_dir=exp/diarize/model/$model_2spk_id

########################################
# Infer
########################################

ave_2spk_id=avg${average_2spk_start}-${average_2spk_end}
# Train on 4 speakers dataset without model init from 2_spk model 
model_id=DH.$train_id.$valid_id.$train_config_id
model_dir=exp/diarize/model/$model_id
ave_id=avg${average_start}-${average_end}
adapt_model_dir=exp/diarize/model/$model_id.$ave_id.$adapt_config_id
adapt_ave_id=avg${adapt_average_start}-${adapt_average_end}

# # Use adapt model
# model=$adapt_model_dir/$adapt_ave_id.nnet.npz
# infer_dir=exp/diarize/infer/$model_id.$ave_id.$adapt_config_id.$adapt_ave_id.$infer_config_id
# scoring_dir=exp/diarize/scoring2/$model_id.$ave_id.$adapt_config_id.$adapt_ave_id.$infer_config_id

# Use trained model
model=trained_model/DH.swb_sre_tr_ns1n2n3n4_beta2n2n5n9_100000.swb_sre_cv_ns1n2n3n4_beta2n2n5n9_500.eda_train.avg16-25.eda_adapt/avg91-100.nnet.npz
infer_dir=trained_model/exp/diarize/infer/$model_id.$ave_id.$adapt_config_id.$adapt_ave_id.$infer_config_id
scoring_dir=trained_model/exp/diarize/scoring2/$model_id.$ave_id.$adapt_config_id.$adapt_ave_id.$infer_config_id

if [ $stage -le 7 ]; then
    echo "inference at $infer_dir"
    # if [ -d $infer_dir ]; then
    #     echo "$infer_dir already exists. "
    #     echo " if you want to retry, please remove it."
    #     exit 1
    # fi
    for dset in dihard3_eval_8k; do
        work=$infer_dir/$dset/.work
        mkdir -p $work
        $train_cmd $work/infer.log \
            infer.py -c $infer_config \
            data/eval/${dset} \
            $model \
            $infer_dir/$dset \
            || exit 1
    done
fi


echo "Process evaluation on DIHARD3 dataset!"

if [ $stage -le 8 ]; then
    echo "scoring at $scoring_dir"
    # if [ -d $scoring_dir ]; then
    #     echo "$scoring_dir already exists. "
    #     echo " if you want to retry, please remove it."
    #     exit 1
    # fi
    for dset in dihard3_eval_8k; do
        work=$scoring_dir/$dset/.work
        mkdir -p $work
        find $infer_dir/$dset -iname "*.h5" > $work/file_list_$dset
        for med in 11; do
            for th in 0.5 0.7; do
                echo "th = $th"
                make_rttm.py --median=$med --threshold=$th \
                    --frame_shift=$infer_frame_shift --subsampling=$infer_subsampling --sampling_rate=$infer_sampling_rate \
                    $work/file_list_$dset $scoring_dir/$dset/hyp_${th}_$med.rttm
                
                # Score using tools/DERscore/score_dihard.sh
                score_dihard.sh \
                    --collar 0.00 --scores-dir $scoring_dir/$dset/scoring \
                    data/eval/$dset/rttm $scoring_dir/$dset/hyp_${th}_$med.rttm
            done
        done
    done
fi
