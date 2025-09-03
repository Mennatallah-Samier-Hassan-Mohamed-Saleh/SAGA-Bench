module load gcc cmake perl python libGl libx11 fontconfig mesa
cd /scratch/ms13779/Masters_thesis/Thesis/SAGA-Bench
mkdir -p bin obj
make clean
make
