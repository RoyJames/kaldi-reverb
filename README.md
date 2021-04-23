Kaldi Speech Recognition Toolkit (Modified)
================================

This repo is a modified version of Kaldi to use custom room impulse responses for testing artificial reverberation strategies.
The `master` branch is not very useful here. Please check out individual branches below for detailed usage instructions.

We assume you have moderate knowledge of how Kaldi works (i.e., building and debugging). For getting the normal version of Kaldi please visit the [original project site](http://kaldi-asr.org/).

Speech corpus
------------
No matter which recipe you use, you need to obtain the base data needed by that recipe legally. And we can not provide all datasets involved. Please read about individual benchmarks/challenges to learn what data you will need.

Branches available
------------

- ami
- reverb

Finding room impulse responses
------------
We have compiled a list of publically available RIRs in [this repo](https://github.com/RoyJames/room-impulse-responses). You may also generate synthetic RIRs using simulators such as [pygsound](https://github.com/RoyJames/pygsound).


Citations
------------
If you use this testing framework, you may cite
```
@misc{tang2021scene,
      title={Scene-aware Far-field Automatic Speech Recognition}, 
      author={Zhenyu Tang and Dinesh Manocha},
      year={2021},
      eprint={2104.10757},
      archivePrefix={arXiv},
      primaryClass={eess.AS}
}
```

