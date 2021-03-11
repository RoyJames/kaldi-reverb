#!/bin/bash

set -e -o pipefail

stage=0
mic=ihm # system mic
nj=30

. ./cmd.sh
. ./path.sh

nnet3_affix=_cleaned
final_lm=`cat data/local/lm/final_lm`
LM=$final_lm.pr1-7
tdnn_affix=1j

. utils/parse_options.sh

# extract iVectors for sdm1 dev evak with ihm extractor
tmic=sdm1 # test mic
if [ $stage -le 0 ]; then
  for data in dev eval; do
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "$nj" \
    data/${tmic}/${data}_hires exp/${mic}/nnet3${nnet3_affix}/extractor \
    exp/${tmic}/nnet3${nnet3_affix}/ivectors_${data}_hires
  done
fi

# decode and score tdnn system
dir=exp/${mic}/chain${nnet3_affix}/tdnn${tdnn_affix}_sp_bi
#dir=exp/sdm1/chain${nnet3_affix}/tdnn${tdnn_affix}_sp_bi_ihmali
graph_dir=$dir/graph_${LM}
if [ $stage -le 1 ]; then
  rm $dir/.error 2>/dev/null || true
  for decode_set in dev eval; do  # dev eval
      (
      steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
          --nj $nj --cmd "$decode_cmd" \
          --online-ivector-dir exp/${tmic}/nnet3${nnet3_affix}/ivectors_${decode_set}_hires \
          --scoring-opts "--min-lmwt 5 " \
         $graph_dir data/${tmic}/${decode_set}_hires $dir/decode_${tmic}_${decode_set} || exit 1;
      ) || touch $dir/.error &
  done
  wait
  if [ -f $dir/.error ]; then
    echo "$0: something went wrong in decoding"
    exit 1
  fi
fi
echo "$0: testing IHM model on SDM1 test set done."
exit 0
