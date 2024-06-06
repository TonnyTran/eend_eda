# EEND-EDA (End-to-End Neural Diarization)

## Install tools

### Install kaldi and python environment
```bash
cd tools
make
```
- This command builds kaldi at `tools/kaldi`
  - if you want to use pre-build kaldi
    ```bash
    cd tools
    make KALDI=<existing_kaldi_root>
    ```
    This option make a symlink at `tools/kaldi`
- This command extracts miniconda3 at `tools/miniconda3`, and creates conda envirionment named 'eend'
- Then, installs Chainer and cupy into 'eend' environment
  - use CUDA in `/usr/local/cuda/`
    - if you need to specify your CUDA path
      ```bash
      cd tools
      make CUDA_PATH=/opt/ohpc/pub/cuda/11.1
      ```

Install dscore
```bash
./install_dscore.sh
```

## CALLHOME + DIHARD3 experiment
### Configuraition
- Modify `egs/callhome/v1/cmd.sh` according to your job schedular.
If you use your local machine, use "run.pl".
If you use Grid Engine, use "queue.pl"
If you use SLURM, use "slurm.pl".
For more information about cmd.sh see http://kaldi-asr.org/doc/queue.html.
- Modify `egs/callhome/v1/run_prepare_shared.sh` according to storage paths of your corpora.

### Data preparation
```bash
cd egs/callhome/v1
./run_prepare_shared.sh
# If you want to conduct 1-4 speaker experiments, run below.
# You also have to set paths to your corpora properly.
./run_prepare_shared_eda.sh
```
### Self-attention-based model using 2-speaker mixtures
```bash
./run.sh
```
### BLSTM-based model using 2-speaker mixtures
```bash
local/run_blstm.sh
```
### Self-attention-based model with EDA using 1-4-speaker mixtures
```bash
./run_eda.sh
```

