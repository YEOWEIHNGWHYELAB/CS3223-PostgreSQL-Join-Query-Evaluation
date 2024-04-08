#!/usr/bin/env bash

# script for batch job on Slurm
# IMPORTANT: replace YOURUSERID before running!

#SBATCH --job-name=cs3223-assign3
#SBATCH --partition=long
#SBATCH --time 720
#SBATCH --exclusive
#SBATCH --output=./logs_%j.out
#SBATCH --error=./logs_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=YOURUSERID@u.nus.sg

bash $HOME/cs3223-assign3/expt.sh 

