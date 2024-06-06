#!/usr/bin/env bash

set -e -u -o pipefail

################################################################################
# Configuration
################################################################################

# Use a no scoring collar of +/ "collar" seconds around each boundary.
collar=0.00
scores_dir=

################################################################################
# Parse options, etc.
################################################################################
if [ -f path.sh ]; then
    . ./path.sh;
fi
if [ -f cmd.sh ]; then
    . ./cmd.sh;
fi
. utils/parse_options.sh || exit 1;
# if [ $# != 2 ]; then
#   echo "usage: $0 <release-dir> <rttm-dir>"
#   echo "e.g.: $0 /data/corpora/LDC2020E12 exp/diarization_dev/rttms"
#   exit 1;
# fi

# Refer RTTM - Groundtruth
refer_rttm=$1

# Directory containing RTTMs to be scored.
sys_rttm=$2

currentDir=$(dirname $0)
UEM_dir=$currentDir/DIHARD3_uem

################################################################################
# Score.
################################################################################
# Create temp directory for dscore outputs.
tmpdir=$(mktemp -d -t dh3-dscore-XXXXXXXX)

echo "usage: $0"
echo "Score DIHARD 3 set - Collar size = $collar s"
echo "***** RESULTS Core set*****         DER        MISS     FA        ERR      |  Overlap |   MISS_1    MISS_ov   FA_0    FA_n    ERROR_1   ERROR_ov|  Overlap |"

# Score CORE test set.
for domain in all audiobooks broadcast_interview clinical court cts maptask meeting restaurant socio_field socio_lab webvideo \
one_spk two_spk three_spk four_spk five_spk six_spk seven_spk eight_spk nine_to_ten_spk \
one_to_four_spk five_to_ten_spk \
one_to_six_spk seven_to_ten_spk ; do
    if [ $domain = "audiobooks" ] || [ $domain = "one_spk" ] || [ $domain = "one_to_four_spk" ]  || [ $domain = "one_to_six_spk" ]; then
        echo "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    fi

    $currentDir/local/rttm_from_uem.py $refer_rttm $UEM_dir/core/$domain.uem $tmpdir ref
    $currentDir/local/rttm_from_uem.py $sys_rttm $UEM_dir/core/$domain.uem $tmpdir sys

    $currentDir/local/md-eval.pl -c $collar\
      -r $tmpdir/ref_$domain.rttm \
      -s $tmpdir/sys_$domain.rttm \
      >  $tmpdir/$domain.der

    der=$(grep OVERALL $tmpdir/$domain.der | awk '{print $6}')
    miss=$(grep 'MISSED SPEAKER' $tmpdir/$domain.der | cut -c 39-43)
    fa=$(grep 'FALARM SPEAKER' $tmpdir/$domain.der | cut -c 39-43)
    err=$(grep 'SPEAKER ERROR TIME' $tmpdir/$domain.der | cut -c 39-43)
    scored_speaker_time=$(grep 'SCORED SPEAKER TIME' $tmpdir/$domain.der | awk '{print $5}')
    missed_speaker_time=$(grep 'MISSED SPEAKER TIME' $tmpdir/$domain.der | awk '{print $5}')
    falarm_speaker_time=$(grep 'FALARM SPEAKER TIME' $tmpdir/$domain.der | awk '{print $5}')
    speaker_error_time=$(grep 'SPEAKER ERROR TIME' $tmpdir/$domain.der | awk '{print $5}')
    falarm_speaker_time_0=$(grep 'FALARM SPEECH' $tmpdir/$domain.der | awk '{print $4}')

    $currentDir/local/md-eval.pl -1 -c $collar\
      -r $tmpdir/ref_$domain.rttm \
      -s $tmpdir/sys_$domain.rttm \
      >  $tmpdir/${domain}_1.der
      
    eval_speech_1=$(grep 'EVAL SPEECH' $tmpdir/${domain}_1.der | awk '{print $4}')
    scored_speaker_time_1=$(grep 'SCORED SPEAKER TIME' $tmpdir/${domain}_1.der | awk '{print $5}')
    missed_speaker_time_1=$(grep 'MISSED SPEAKER TIME' $tmpdir/${domain}_1.der | awk '{print $5}')
    falarm_speaker_time_1=$(grep 'FALARM SPEAKER TIME' $tmpdir/${domain}_1.der | awk '{print $5}')
    speaker_error_time_1=$(grep 'SPEAKER ERROR TIME' $tmpdir/${domain}_1.der | awk '{print $5}')

    overlap_time=$(echo "$scored_speaker_time-$scored_speaker_time_1" |bc -l)
    overlap_ratio=$(echo "scale=5; $overlap_time / $scored_speaker_time * 100" |bc -l)

    overlap_time2=$(echo "$eval_speech_1-$scored_speaker_time_1" |bc -l)
    overlap_ratio2=$(echo "scale=5; $overlap_time2 / $eval_speech_1 * 100" |bc -l)

    missed_speaker_time_2=$(echo "$missed_speaker_time-$missed_speaker_time_1" |bc -l)
    miss_1=$(echo "scale=5; $missed_speaker_time_1 / $scored_speaker_time * 100" |bc -l)
    miss_2=$(echo "scale=5; $missed_speaker_time_2 / $scored_speaker_time * 100" |bc -l)

    falarm_speaker_time_n=$(echo "$falarm_speaker_time-$falarm_speaker_time_0" |bc -l)
    falarm_0=$(echo "scale=5; $falarm_speaker_time_0 / $scored_speaker_time * 100" |bc -l)
    falarm_n=$(echo "scale=5; $falarm_speaker_time_n / $scored_speaker_time * 100" |bc -l)
    
    speaker_error_time_2=$(echo "$speaker_error_time-$speaker_error_time_1" |bc -l)
    error_1=$(echo "scale=5; $speaker_error_time_1 / $scored_speaker_time * 100" |bc -l)
    error_2=$(echo "scale=5; $speaker_error_time_2 / $scored_speaker_time * 100" |bc -l)

    printf "DER (core) - %-20s : %-8s  %-8s  %-8s  %-8s | %8.2f | %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f   | %8.2f |\n"  ${domain} ${der} $miss $fa $err $overlap_ratio $miss_1 $miss_2 $falarm_0 $falarm_n $error_1 $error_2 $overlap_ratio2
done

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "***** RESULTS Full set*****         DER        MISS     FA        ERR      |  Overlap |   MISS_1    MISS_ov   FA_0    FA_n    ERROR_1   ERROR_ov|  Overlap |"

# Score Full test set.
for domain in all audiobooks broadcast_interview clinical court cts maptask meeting restaurant socio_field socio_lab webvideo \
one_spk two_spk three_spk four_spk five_spk six_spk seven_spk eight_spk nine_to_ten_spk \
one_to_four_spk five_to_ten_spk \
one_to_six_spk seven_to_ten_spk ; do
    if [ $domain = "audiobooks" ] || [ $domain = "one_spk" ] || [ $domain = "one_to_four_spk" ]  || [ $domain = "one_to_six_spk" ]; then
        echo "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    fi

    $currentDir/local/rttm_from_uem.py $refer_rttm $UEM_dir/full/$domain.uem $tmpdir ref
    $currentDir/local/rttm_from_uem.py $sys_rttm $UEM_dir/full/$domain.uem $tmpdir sys

    $currentDir/local/md-eval.pl -c $collar\
      -r $tmpdir/ref_$domain.rttm \
      -s $tmpdir/sys_$domain.rttm \
      >  $tmpdir/$domain.der

    der=$(grep OVERALL $tmpdir/$domain.der | awk '{print $6}')
    miss=$(grep 'MISSED SPEAKER' $tmpdir/$domain.der | cut -c 39-43)
    fa=$(grep 'FALARM SPEAKER' $tmpdir/$domain.der | cut -c 39-43)
    err=$(grep 'SPEAKER ERROR TIME' $tmpdir/$domain.der | cut -c 39-43)
    scored_speaker_time=$(grep 'SCORED SPEAKER TIME' $tmpdir/$domain.der | awk '{print $5}')
    missed_speaker_time=$(grep 'MISSED SPEAKER TIME' $tmpdir/$domain.der | awk '{print $5}')
    falarm_speaker_time=$(grep 'FALARM SPEAKER TIME' $tmpdir/$domain.der | awk '{print $5}')
    speaker_error_time=$(grep 'SPEAKER ERROR TIME' $tmpdir/$domain.der | awk '{print $5}')

    $currentDir/local/md-eval.pl -1 -c $collar\
      -r $tmpdir/ref_$domain.rttm \
      -s $tmpdir/sys_$domain.rttm \
      >  $tmpdir/${domain}_1.der
      
    eval_speech_1=$(grep 'EVAL SPEECH' $tmpdir/${domain}_1.der | awk '{print $4}')
    scored_speaker_time_1=$(grep 'SCORED SPEAKER TIME' $tmpdir/${domain}_1.der | awk '{print $5}')
    missed_speaker_time_1=$(grep 'MISSED SPEAKER TIME' $tmpdir/${domain}_1.der | awk '{print $5}')
    falarm_speaker_time_1=$(grep 'FALARM SPEAKER TIME' $tmpdir/${domain}_1.der | awk '{print $5}')
    speaker_error_time_1=$(grep 'SPEAKER ERROR TIME' $tmpdir/${domain}_1.der | awk '{print $5}')

    overlap_time=$(echo "$scored_speaker_time-$scored_speaker_time_1" |bc -l)
    overlap_ratio=$(echo "scale=5; $overlap_time / $scored_speaker_time * 100" |bc -l)

    overlap_time2=$(echo "$eval_speech_1-$scored_speaker_time_1" |bc -l)
    overlap_ratio2=$(echo "scale=5; $overlap_time2 / $eval_speech_1 * 100" |bc -l)

    missed_speaker_time_2=$(echo "$missed_speaker_time-$missed_speaker_time_1" |bc -l)
    miss_1=$(echo "scale=5; $missed_speaker_time_1 / $scored_speaker_time * 100" |bc -l)
    miss_2=$(echo "scale=5; $missed_speaker_time_2 / $scored_speaker_time * 100" |bc -l)

    falarm_speaker_time_2=$(echo "$falarm_speaker_time-$falarm_speaker_time_1" |bc -l)
    falarm_1=$(echo "scale=5; $falarm_speaker_time_1 / $scored_speaker_time * 100" |bc -l)
    falarm_2=$(echo "scale=5; $falarm_speaker_time_2 / $scored_speaker_time * 100" |bc -l)
    
    speaker_error_time_2=$(echo "$speaker_error_time-$speaker_error_time_1" |bc -l)
    error_1=$(echo "scale=5; $speaker_error_time_1 / $scored_speaker_time * 100" |bc -l)
    error_2=$(echo "scale=5; $speaker_error_time_2 / $scored_speaker_time * 100" |bc -l)

    printf "DER (full) - %-20s : %-8s  %-8s  %-8s  %-8s | %8.2f | %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f   | %8.2f |\n"  ${domain} ${der} $miss $fa $err $overlap_ratio $miss_1 $miss_2 $falarm_1 $falarm_2 $error_1 $error_2 $overlap_ratio2
done

if [ ! -z "scores_dir" ]; then
 echo "$0: ***"
 echo "$0: *** Full results are located at: ${scores_dir}"
fi

# Clean up.
if [ ! -z "scores_dir" ]; then
  mkdir -p $scores_dir
  cp $tmpdir/* $scores_dir
fi
rm -fr $tmpdir
