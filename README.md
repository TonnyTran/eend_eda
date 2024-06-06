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

<!-- Install dscore
```bash
./install_dscore.sh
``` -->

## DIHARD3 experiment
### Configuraition
- Modify `egs/DIHARD3_callhome/v2/cmd.sh` according to your job schedular.
If you use your local machine, use "run.pl".
If you use Grid Engine, use "queue.pl"
If you use SLURM, use "slurm.pl".
For more information about cmd.sh see http://kaldi-asr.org/doc/queue.html.

### 1. Data preparation
```bash
cd egs/DIHARD3_callhome/v2
# Prepare DIHARD3 data in Kaldi format
./run_prepare_DIHARD.sh
# NOTE: change parameter DIHARD_DEV_DIR, DIHARD_EVAL_DIR according to your location of DIHARD3 Dev and Eval sets

# Prepare simulated training dataset (from 1 to 4 speakers)
./run_prepare_simulated_data.sh
# NOTE: You also have to set paths to your corpora properly including: data_root, musan_root, simu_actual_dirs.
```
### 2. Train EEND-EDA model
```bash
./run_eda_8k.sh
```
### 3. Inference EEND-EDA model on DIHARD3 using trained model
```bash
./infer_eda.sh
# Note: the EEND_EDA trained model is saved in folder trained_model
```



