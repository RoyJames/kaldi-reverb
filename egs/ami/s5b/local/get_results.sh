for d in exp/*/chain_cleaned/tdnn1j_sp_bi/decode*; do grep Sum $d/*sc*/*ys | utils/best_wer.sh; done
