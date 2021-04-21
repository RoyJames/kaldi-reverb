AMI
================================

The `egs/ami/s5b.reverb` contains the modified recipe, which are created according to the documents of [BUT ReverbDB](https://speech.fit.vutbr.cz/software/but-speech-fit-reverb-database).

## Inctructions to run AMI Kaldi recipe for reverberated data:
1) run the baseline s5b recipe for AMI with ihm data:

        s5b/run.sh --mic ihm
   the script in s5b.reverb will later look for trained models under `s5b/exp/ihm`
2) run the baseline s5b recipe for AMI with sdm data, and you may stop before training the network to save time:

        s5b/run.sh --mic sdm1
   copy `s5b/data/sdm1/dev_hires` and `s5b/data/sdm1/eval_hires` to `s5b.reverb/data/sdm1/`, which will be used for testing
4) externally convolve/reverberate the AMI speech using your custom impulse responses and store the new reverberant AMI directory at <path_to_dir>
5) swithc to folder `s5b.reverb`, in `run.reverb.sh`, set the location of the directory where reverberated AMI data are stored:

        run.reverb.sh --nj 32 --mic ihm --ami <path_to_dir>
5) run `local/get_results.sh` to see WERs
