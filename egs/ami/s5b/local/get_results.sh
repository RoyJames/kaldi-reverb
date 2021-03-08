for d in exp/*/chain_cleaned/tdnn*/decode*; do grep Sum $d/*sc*/*ys | utils/best_wer.sh; done
