#!/bin/bash

. ./cmd.sh
. ./path.sh


# You may set 'mic' to:
#  ihm [individual headset mic- the default which gives best results]
#  sdm1 [single distant microphone- the current script allows you only to select
#        the 1st of 8 microphones]
#  mdm8 [multiple distant microphones-- currently we only support averaging over
#       the 8 source microphones].
# ... by calling this script as, for example,
# ./run.sh --mic sdm1
# ./run.sh --mic mdm8
mic=ihm

# Train systems,
nj=60 # number of parallel jobs,
stage=10
. utils/parse_options.sh

base_mic=$(echo $mic | sed 's/[0-9]//g') # sdm, ihm or mdm
nmics=$(echo $mic | sed 's/[a-z]//g') # e.g. 8 for mdm8.

set -euo pipefail

# Path where AMI gets downloaded (or where locally available):
AMI_DIR=/scratch/zhy/ASR_Data/AMI # Default,
case $(hostname -d) in
  fit.vutbr.cz) AMI_DIR=/mnt/matylda5/iveselyk/KALDI_AMI_WAV ;; # BUT,
  clsp.jhu.edu) AMI_DIR=/export/corpora4/ami/amicorpus ;; # JHU,
  cstr.ed.ac.uk) AMI_DIR= ;; # Edinburgh,
esac
AMI_DIR_DEVEV=/mnt/matylda5/iveselyk/KALDI_AMI_WAV
AMI_DIR_TRAIN=---  ### set path here to your reverberated data ###

[ ! -r data/local/lm/final_lm ] && echo "Please, run 'run_prepare_shared.sh' first!" && exit 1
final_lm=`cat data/local/lm/final_lm`
LM=$final_lm.pr1-7

if [ $stage -le 10 ]; then
  echo "== Stage 10 =="
  # The following script cleans the data and produces cleaned data
  # in data/$mic/train_cleaned, and a corresponding system
  # in exp/$mic/tri3_cleaned.  It also decodes.
  #
  # Note: local/run_cleanup_segmentation.sh defaults to using 50 jobs,
  # you can reduce it using the --nj option if you want.
  local/run_cleanup_segmentation.sh --mic $mic || exit 1
  #local/run_cleanup_segmentation.sh --mic $mic --cleanup_stage 9 || exit 1
fi

if [ $stage -le 11 ]; then
  echo "== Stage 11 =="
  ali_opt=
  [ "$mic" != "ihm" ] && ali_opt="--use-ihm-ali true"
  local/chain/run_tdnn.sh $ali_opt --mic $mic --stage 0 --train_stage -10 || exit 1
fi

if [ $stage -le 12 ]; then
  echo "== Stage 12 =="
  local/test_ihm_on_sdm1_DNN.sh --stage 0 --nj $nj || exit 1
fi

exit 0
