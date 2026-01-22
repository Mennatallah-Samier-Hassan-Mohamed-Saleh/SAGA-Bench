module load gcc cmake perl python libGl libx11 fontconfig mesa
cd /scratch/ms13779/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench
mkdir -p bin obj
make clean
make
