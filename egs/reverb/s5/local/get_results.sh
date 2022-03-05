#!/usr/bin/env bash

echo "TDNN RESULTs:"
echo "exp/chain_$1/tdnn1a_sp/decode_test_tg_5k_dt*"
cat exp/chain_$1/tdnn1a_sp/decode_test_tg_5k_dt*/scoring_kaldi/best_wer_*
echo ""
echo "exp/chain_$1/tdnn1a_sp/decode_test_tg_5k_et*"
cat exp/chain_$1/tdnn1a_sp/decode_test_tg_5k_et*/scoring_kaldi/best_wer_*
