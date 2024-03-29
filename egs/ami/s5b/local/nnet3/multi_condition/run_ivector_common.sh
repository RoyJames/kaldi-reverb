#!/usr/bin/env bash

set -e -o pipefail


# This script is called from local/chain/multi_condition/run_tdnn.sh.
# It contains the common feature preparation and iVector-related parts
# of the script.  See those scripts for examples of usage.

stage=1
mic=ihm
nj=30
train_set=train_cleaned   # you might set this to e.g. train_cleaned.
norvb_datadir=data/ihm/train_cleaned_sp

num_threads_ubm=32
rvb_affix=_rvb
nnet3_affix=_cleaned     # affix for exp/$mic/nnet3 directory to put iVector stuff in, so it
                         # becomes exp/$mic/nnet3_cleaned or whatever.
num_data_reps=1
sample_rate=16000

max_jobs_run=64

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

nnet3_affix=${nnet3_affix}$rvb_affix

for f in data/${mic}/${train_set}/feats.scp; do
  if [ ! -f $f ]; then
    echo "$0: expected file $f to exist"
    exit 1
  fi
done



if [ $stage -le 1 ] && [ -f data/$mic/${train_set}_sp_hires/feats.scp ]; then
  echo "$0: data/$mic/${train_set}_sp_hires/feats.scp already exists."
  echo " ... Please either remove it, or rerun this script with stage > 2."
  exit 1
fi

if [ $stage -le 1 ]; then
  echo "$0: preparing directory for speed-perturbed data"
  utils/data/perturb_data_dir_speed_3way.sh data/${mic}/${train_set} data/${mic}/${train_set}_sp

  echo "$0: creating high-resolution MFCC features"

  # this shows how you can split across multiple file-systems.  we'll split the
  # MFCC dir across multiple locations.  You might want to be careful here, if you
  # have multiple copies of Kaldi checked out and run the same recipe, not to let
  # them overwrite each other.
  mfccdir=data/$mic/${train_set}_sp_hires/data
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $mfccdir/storage ]; then
    utils/create_split_dir.pl /export/b0{5,6,7,8}/$USER/kaldi-data/egs/ami-$mic-$(date +'%m_%d_%H_%M')/s5/$mfccdir/storage $mfccdir/storage
  fi

  for datadir in ${train_set}_sp dev eval; do
    utils/copy_data_dir.sh data/$mic/$datadir data/$mic/${datadir}_hires
  done

  # do volume-perturbation on the training data prior to extracting hires
  # features; this helps make trained nnets more invariant to test data volume.
  utils/data/perturb_data_dir_volume.sh data/$mic/${train_set}_sp_hires

  for datadir in ${train_set}_sp dev eval; do
    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd --max-jobs-run $max_jobs_run" data/$mic/${datadir}_hires
    steps/compute_cmvn_stats.sh data/$mic/${datadir}_hires
    utils/fix_data_dir.sh data/$mic/${datadir}_hires
  done
fi


if [ $stage -le 3 ]; then
  echo "$0: creating reverberated MFCC features"

  mfccdir=${norvb_datadir}${rvb_affix}${num_data_reps}_hires/data
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $mfccdir/storage ]; then
    utils/create_split_dir.pl /export/b0{5,6,7,8}/$USER/kaldi-data/egs/ami-$mic-$(date +'%m_%d_%H_%M')/s5/$mfccdir/storage $mfccdir/storage
  fi

  if [ ! -f ${norvb_datadir}${rvb_affix}${num_data_reps}_hires/feats.scp ]; then
    if [ ! -d "RIRS_NOISES/" ]; then
      # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
      wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
      unzip rirs_noises.zip
    fi

    rvb_opts=()
    rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
    rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")
    rvb_opts+=(--noise-set-parameters RIRS_NOISES/pointsource_noises/noise_list)

    python3 steps/data/reverberate_data_dir.py \
      "${rvb_opts[@]}" \
      --prefix "rev" \
      --foreground-snrs "20:10:15:5:0" \
      --background-snrs "20:10:15:5:0" \
      --speech-rvb-probability 1 \
      --pointsource-noise-addition-probability 1 \
      --isotropic-noise-addition-probability 1 \
      --num-replications ${num_data_reps} \
      --max-noises-per-minute 1 \
      --source-sampling-rate $sample_rate \
      ${norvb_datadir} ${norvb_datadir}${rvb_affix}${num_data_reps}

    utils/copy_data_dir.sh ${norvb_datadir}${rvb_affix}${num_data_reps} ${norvb_datadir}${rvb_affix}${num_data_reps}_hires
    utils/data/perturb_data_dir_volume.sh ${norvb_datadir}${rvb_affix}${num_data_reps}_hires

    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd --max-jobs-run $max_jobs_run" ${norvb_datadir}${rvb_affix}${num_data_reps}_hires
    steps/compute_cmvn_stats.sh ${norvb_datadir}${rvb_affix}${num_data_reps}_hires
    utils/fix_data_dir.sh ${norvb_datadir}${rvb_affix}${num_data_reps}_hires
  fi

  utils/combine_data.sh data/${mic}/${train_set}_sp${rvb_affix}_hires data/${mic}/${train_set}_sp_hires ${norvb_datadir}${rvb_affix}${num_data_reps}_hires
fi

if [ $stage -le 4 ]; then
  utils/combine_data.sh data/${mic}/${train_set}_sp${rvb_affix}_hires data/${mic}/${train_set}_sp_hires ${norvb_datadir}${rvb_affix}${num_data_reps}_hires

  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --max-utts 30000 --subsample 2 \
    data/${mic}/${train_set}_sp${rvb_affix}_hires \
    exp/$mic/nnet3${nnet3_affix}/pca_transform
fi


if [ $stage -le 5 ]; then
  echo "$0: computing a subset of data to train the diagonal UBM."

  mkdir -p exp/$mic/nnet3${nnet3_affix}/diag_ubm
  temp_data_root=exp/$mic/nnet3${nnet3_affix}/diag_ubm

  # train a diagonal UBM using a subset of about a quarter of the data,
  # and using the non-combined data is more efficient for I/O
  # (no messing about with piped commands).
  num_utts_total=$(wc -l <data/$mic/${train_set}_sp${rvb_affix}_hires/utt2spk)
  num_utts=$[$num_utts_total/4]
  utils/data/subset_data_dir.sh data/$mic/${train_set}_sp${rvb_affix}_hires \
      $num_utts ${temp_data_root}/${train_set}_sp${rvb_affix}_hires_subset

  echo "$0: training the diagonal UBM."
  # Use 512 Gaussians in the UBM.
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 30 \
    --num-frames 700000 \
    --num-threads $num_threads_ubm \
    ${temp_data_root}/${train_set}_sp${rvb_affix}_hires_subset 512 \
    exp/$mic/nnet3${nnet3_affix}/pca_transform exp/$mic/nnet3${nnet3_affix}/diag_ubm
fi

if [ $stage -le 6 ]; then
  # Train the iVector extractor.  Use all of the speed-perturbed data since iVector extractors
  # can be sensitive to the amount of data.  The script defaults to an iVector dimension of
  # 100.
  echo "$0: training the iVector extractor"
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 10 \
    data/$mic/${train_set}_sp${rvb_affix}_hires exp/$mic/nnet3${nnet3_affix}/diag_ubm exp/$mic/nnet3${nnet3_affix}/extractor || exit 1;
fi

if [ $stage -le 7 ]; then
  # note, we don't encode the 'max2' in the name of the ivectordir even though
  # that's the data we extract the ivectors from, as it's still going to be
  # valid for the non-'max2' data, the utterance list is the same.
  ivectordir=exp/$mic/nnet3${nnet3_affix}/ivectors_${train_set}_sp${rvb_affix}_hires
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $ivectordir/storage ]; then
    utils/create_split_dir.pl /export/b0{5,6,7,8}/$USER/kaldi-data/egs/ami-$mic-$(date +'%m_%d_%H_%M')/s5/$ivectordir/storage $ivectordir/storage
  fi
  # We extract iVectors on the speed-perturbed training data after combining
  # short segments, which will be what we train the system on.  With
  # --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
  # each of these pairs as one speaker; this gives more diversity in iVectors..
  # Note that these are extracted 'online'.

  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  temp_data_root=${ivectordir}
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    data/${mic}/${train_set}_sp${rvb_affix}_hires ${temp_data_root}/${train_set}_sp${rvb_affix}_hires_max2

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    ${temp_data_root}/${train_set}_sp${rvb_affix}_hires_max2 \
    exp/$mic/nnet3${nnet3_affix}/extractor $ivectordir

  # Also extract iVectors for the test data, but in this case we don't need the speed
  # perturbation (sp) or small-segment concatenation (comb).
  for data in dev eval; do
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "$nj" \
      data/${mic}/${data}_hires exp/$mic/nnet3${nnet3_affix}/extractor \
      exp/$mic/nnet3${nnet3_affix}/ivectors_${data}_hires
  done
fi

exit 0;
