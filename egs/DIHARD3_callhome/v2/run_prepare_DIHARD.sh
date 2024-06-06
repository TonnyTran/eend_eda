#!/bin/bash

stage=0

# Modify corpus directories

DIHARD_DEV_DIR=/home3/theanhtran/corpus/DIHARD/DIHARD3/third_dihard_challenge_dev
DIHARD_EVAL_DIR=/home3/theanhtran/corpus/DIHARD/DIHARD3/third_dihard_challenge_eval

. path.sh
. cmd.sh
. parse_options.sh || exit


################################################################################
# Prepare data directories - DIHARD3
################################################################################
if [ $stage -le 1 ]; then
    echo "$0: Preparing data directories..."

    # dev
    local/make_data_dir2.py \
    --rttm-dir $DIHARD_DEV_DIR/data/rttm \
        data/dihard3_dev \
        $DIHARD_DEV_DIR/data/flac \
        $DIHARD_DEV_DIR/data/sad
    utils/utt2spk_to_spk2utt.pl \
        data/dihard3_dev/utt2spk > data/dihard3_dev/spk2utt
    ./utils/validate_data_dir.sh \
        --no-text --no-feats data/dihard3_dev/
    utils/data/get_reco2dur.sh data/dihard3_dev


    # eval
    local/make_data_dir2.py \
        --rttm-dir $DIHARD_EVAL_DIR/data/rttm \
        data/dihard3_eval \
        $DIHARD_EVAL_DIR/data/flac \
        $DIHARD_EVAL_DIR/data/sad
    utils/utt2spk_to_spk2utt.pl \
        data/dihard3_eval/utt2spk > data/dihard3_eval/spk2utt
    ./utils/validate_data_dir.sh \
        --no-text --no-feats data/dihard3_eval/
    utils/data/get_reco2dur.sh data/dihard3_eval
fi



#####################################
# Prepare 8kHz data DIHARD3
#####################################
if [ $stage -le 2 ]; then
    echo "$0: Prepare 8kHz data"
    for dset in dihard3_dev dihard3_eval; do
        mkdir -p data/${dset}_8k
        mkdir -p data/wav_8k/$dset
        local/convert_8kHz.py \
            data/$dset \
            $PWD/data/wav_8k/$dset \
            data/${dset}_8k
        ./utils/validate_data_dir.sh \
            --no-text --no-feats data/${dset}_8k/

    
        awk '{printf "%s_%s_%07d_%07d %s %.2f %.2f\n", \
                $2, $8, $4*100, ($4+$5)*100, $2, $4, $4+$5}' \
            data/${dset}/rttm | sort > data/${dset}_8k/segments
        utils/fix_data_dir.sh data/${dset}_8k
        # Speaker ID is '[recid]_[speakerid]
        awk '{split($1,A,"_"); printf "%s %s_%s_%s_%s\n", $1, A[1], A[2], A[3], A[4]}' \
            data/${dset}_8k/segments > data/${dset}_8k/utt2spk
        utils/fix_data_dir.sh data/${dset}_8k
        # Generate rttm files for scoring
        steps/segmentation/convert_utt2spk_and_segments_to_rttm.py \
            data/${dset}_8k/utt2spk data/${dset}_8k/segments \
            data/${dset}_8k/rttm
        utils/data/get_reco2dur.sh data/${dset}_8k
    done
fi

if [ $stage -le 3 ]; then
    # compose eval/dihard3_eval_8k
    eval_set=data/eval/dihard3_eval_8k
    if ! validate_data_dir.sh --no-text --no-feats $eval_set; then
        utils/copy_data_dir.sh data/dihard3_eval_8k $eval_set
        cp data/dihard3_eval_8k/rttm $eval_set/rttm
        awk -v dstdir=wav/eval/dihard3_eval_8k '{print $1, dstdir"/"$1".wav"}' data/dihard3_eval_8k/wav.scp > $eval_set/wav.scp
        mkdir -p wav/eval/dihard3_eval_8k
        wav-copy scp:data/dihard3_eval_8k/wav.scp scp:$eval_set/wav.scp
        utils/data/get_reco2dur.sh $eval_set
    fi

    # compose eval/dihard3_dev_8k
    adapt_set=data/eval/dihard3_dev_8k
    if ! validate_data_dir.sh --no-text --no-feats $adapt_set; then
        utils/copy_data_dir.sh data/dihard3_dev_8k $adapt_set
        cp data/dihard3_dev_8k/rttm $adapt_set/rttm
        awk -v dstdir=wav/eval/dihard3_dev_8k '{print $1, dstdir"/"$1".wav"}' data/dihard3_dev_8k/wav.scp > $adapt_set/wav.scp
        mkdir -p wav/eval/dihard3_dev_8k
        wav-copy scp:data/dihard3_dev_8k/wav.scp scp:$adapt_set/wav.scp
        utils/data/get_reco2dur.sh $adapt_set
    fi
fi

sampling_rate=8000
if [ $stage -le 4 ]; then
    for dset in eval_1_4_spk eval_5_10_spk; do
        local/make_data_dir2.py \
            --rttm-dir $DIHARD_EVAL_DIR/data/rttm \
            --rec-ids local/dihard_modified/${dset}.list \
            --target-sr $sampling_rate \
            data/dihard3_${dset} \
            $DIHARD_EVAL_DIR/data/flac \
            $DIHARD_EVAL_DIR/data/sad
        utils/utt2spk_to_spk2utt.pl \
            data/dihard3_${dset}/utt2spk > data/dihard3_${dset}/spk2utt
        ./utils/validate_data_dir.sh \
            --no-text --no-feats data/dihard3_${dset}/
        utils/data/get_reco2dur.sh data/dihard3_${dset}
    done

    for dset in dev_1_4_spk dev_5_10_spk; do
        local/make_data_dir2.py \
            --rttm-dir $DIHARD_DEV_DIR/data/rttm \
            --rec-ids local/dihard_modified/${dset}.list \
            --target-sr $sampling_rate \
            data/dihard3_${dset} \
            $DIHARD_DEV_DIR/data/flac \
            $DIHARD_DEV_DIR/data/sad
        utils/utt2spk_to_spk2utt.pl \
            data/dihard3_${dset}/utt2spk > data/dihard3_${dset}/spk2utt
        ./utils/validate_data_dir.sh \
            --no-text --no-feats data/dihard3_${dset}/
        utils/data/get_reco2dur.sh data/dihard3_${dset}
    done
fi

if [ $stage -le 5 ]; then
    echo "$0: Prepare 8kHz data"
    for dset in dihard3_eval_1_4_spk dihard3_eval_5_10_spk dihard3_dev_1_4_spk dihard3_dev_5_10_spk; do

        copy_data_dir.sh data/${dset} data/${dset}_8k
        cp data/${dset}/rttm data/${dset}_8k/rttm
        awk '{printf "%s_%s_%07d_%07d %s %.2f %.2f\n", \
                $2, $8, $4*100, ($4+$5)*100, $2, $4, $4+$5}' \
            data/${dset}_8k/rttm | sort > data/${dset}_8k/segments
        utils/fix_data_dir.sh data/${dset}_8k
        # Speaker ID is '[recid]_[speakerid]
        awk '{split($1,A,"_"); printf "%s %s_%s_%s_%s\n", $1, A[1], A[2], A[3], A[4]}' \
            data/${dset}_8k/segments > data/${dset}_8k/utt2spk
        utils/fix_data_dir.sh data/${dset}_8k
        # Generate rttm files for scoring
        steps/segmentation/convert_utt2spk_and_segments_to_rttm.py \
            data/${dset}_8k/utt2spk data/${dset}_8k/segments \
            data/${dset}_8k/rttm
        utils/data/get_reco2dur.sh data/${dset}_8k
    done
fi

if [ $stage -le 6 ]; then
    # compose eval/dihard3_eval_8k
    for dset in dihard3_eval_1_4_spk_8k dihard3_eval_5_10_spk_8k dihard3_dev_1_4_spk_8k dihard3_dev_5_10_spk_8k; do
        eval_set=data/eval/${dset}
        if ! validate_data_dir.sh --no-text --no-feats $eval_set; then
            utils/copy_data_dir.sh data/${dset} $eval_set
            cp data/${dset}/rttm $eval_set/rttm
            awk -v dstdir=wav/eval/${dset} '{print $1, dstdir"/"$1".wav"}' data/${dset}/wav.scp > $eval_set/wav.scp
            mkdir -p wav/eval/${dset}
            wav-copy scp:data/${dset}/wav.scp scp:$eval_set/wav.scp
            utils/data/get_reco2dur.sh $eval_set
        fi
    done
fi