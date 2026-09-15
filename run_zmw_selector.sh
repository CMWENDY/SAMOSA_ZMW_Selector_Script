#!/bin/bash
#PBS -N zmw_selector_job
#PBS -l mem_free=32G
#PBS -l scratch=500G
#PBS -l h_rt=4:00:00

# Initialize Conda
source /wynton/home/ramani/wendycm/miniconda3/etc/profile.d/conda.sh
if [ $? -ne 0 ]; then
    echo "Error: Conda initialization failed."
    exit 1
fi

echo "Activating Conda environment..."
conda activate SAMOSA.zmw
if [ $? -ne 0 ]; then
    echo "Error: Conda environment activation failed."
    exit 1
fi
echo "Conda environment activated."

# Define variables
BASE_PATH="$HOME/HR_EBF2/zmw_selector_reqs"
PEAK_SETS=("D7_UniquePeaks" "D2_UniquePeaks")
WINDOW_SIZE=1000
OUTPUT_PREFIX="output_EBF2"
INITIALS="WCM"

echo "Base path: $BASE_PATH"
echo "Output prefix: $OUTPUT_PREFIX"
echo "Window size: $WINDOW_SIZE"

# Loop through each peak set and run zmw_selector_official.py
for PEAK_SET in "${PEAK_SETS[@]}"; do
    BAM_FILE_FOLDER="$BASE_PATH/BA_EBF2.bam/aligned/"
    
    if [ ! -d "$BAM_FILE_FOLDER" ]; then
        echo "Error: BAM file folder ${BAM_FILE_FOLDER} not found."
        exit 1
    else
        echo "BAM file folder: $BAM_FILE_FOLDER"
    fi
    
    # Get the list of BAM files
    BAM_FILES=($(find "$BAM_FILE_FOLDER" -name "*.bam"))
    if [ ${#BAM_FILES[@]} -eq 0 ]; then
        echo "Error: No BAM files found in ${BAM_FILE_FOLDER}."
        exit 1
    fi
    # Loops through BAM file list; Outputting zmw file per BAM 
    for BAM_FILE in "${BAM_FILES[@]}"; do
        SITES_FILE="$BASE_PATH/BA_EBF2_motif.tsv/Midpoint_Extraction/${PEAK_SET}_Motif_Processed.tsv"
        CHROM_SIZES_FILE="$BASE_PATH/mm10.genome"
        OUTPUT_FILE="$BASE_PATH/outputted_zmws/${INITIALS}_${OUTPUT_PREFIX}_${PEAK_SET}_$(basename ${BAM_FILE}).1kb.zmw"

        if [ ! -f "$SITES_FILE" ]; then
            echo "Error: Sites file ${SITES_FILE} not found."
            exit 1
        else
            echo "Sites file: $SITES_FILE"
        fi

        if [ ! -f "$CHROM_SIZES_FILE" ]; then
            echo "Error: Chrom sizes file ${CHROM_SIZES_FILE} not found."
            exit 1
        else
            echo "Chrom sizes file: $CHROM_SIZES_FILE"
        fi

        # Run zmw_selector_per_BAM.py
        CMD="python $BASE_PATH/zmw_selector_updated.py $SITES_FILE $CHROM_SIZES_FILE $BAM_FILE $WINDOW_SIZE > $OUTPUT_FILE"
        echo "Running command: $CMD"
        eval "$CMD"
        if [ $? -ne 0 ]; then
            echo "Error: zmw_selector_per_BAM.py failed for ${PEAK_SET}."
        else
            echo "Completed: zmw_selector_per_BAM.py for ${PEAK_SET}."
        fi
    done
done

echo "Script completed."

