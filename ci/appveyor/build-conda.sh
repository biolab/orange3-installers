#!/usr/bin/env bash

set -ve

[ -d orange3/setup.py ] || { echo wrong cwd; exit 1; }
[ which conda > /dev/null ] || { echo conda not on PATH; exit 2; }

mkdir -p dist/pkgs
conda config --append channels conda-forge

conda build --output-folder=dist/pkgs orange3/conda-recipe || exit 1

shopt -s failglob
PKG=( dist/pkgs/orange3-*.tar.bz2 )
shopt -u failglob

version=$(python setup.py --version)

md4 -DORANGE_PKG="${PKG}" conda-env.txt.in > conda-env.txt
conda create -n _env --yes --use-local orange3=$version --file conda-env.txt

./scripts/windows/build-conda-installer.sh --spec=conda-env.txt

