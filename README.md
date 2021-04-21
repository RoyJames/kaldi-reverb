REVERB
================================

The `egs/reverb/s5` contains the modified recipe. The original script uses a fixed set of 24 room impulse responses to create reverberant data using Matlab. This script replaces this step by letting Matlab use external impulse responses. 

## Inctructions to run REVERB Kaldi recipe for custom impulse responses:
0) remove `s5/data` to prevent previous data from interferring with your new run
1) go to folder `egs/reverb/s5`, run the recipe by providing your folder path <path_to_rir> that contains custom impulse responses:

        ./run.sh --rirdir <path_to_rir>
   the script will stop running shortly because it expects you to manually run Matlab outside this script
2) run the Matlab script for generating reverberant data:
        
        cd egs/reverb/s5/data/local/reverb_tools/reverb_tools_for_Generate_mcTrainData
        cat run_mat.m | matlab -nodisplay        
3) go back to `egs/reverb/s5` and run the recipe again 

        ./run.sh 
   this time it will skip the augmentation step
4) run `local/get_results.sh` to see WERs

***The original recipe calls Matlab from inside the recipe, which may be more straightforward if you have Matlab installed system-wide. I made this modification for it to be able to run on servers inside a virtual container (e.g., Docker, Singularity) where Matlab may not be available. So the process will be to run Kaldi in the container for step 1, run the Matlab script for step 2 in an environment that has it, and finish the remaining steps in the container again.***
