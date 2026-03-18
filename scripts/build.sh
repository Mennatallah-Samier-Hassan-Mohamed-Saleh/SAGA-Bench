module load gcc cmake perl python libGl libx11 fontconfig mesa
# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

# 3. Move into it
cd "$PROJECT_ROOT" || exit
echo "Successfully moved to PROJECT_ROOT: $PWD"

mkdir -p bin obj
make clean
make
