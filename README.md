# SAMOSA ZMW Selector Script

Pulls the raw PacBio reads (ZMWs) that overlap a set of genomic sites of interest — for
example, predicted transcription factor binding motifs — out of an aligned BAM file, so they
can be fed into downstream single-molecule methylation/footprinting analysis.

The original `zmw_selector.py` is credited to the [Ramani Lab's SAMOSA
project](https://github.com/RamaniLab/SAMOSA). This repo refactors that script and adds a
batch runner for processing many BAM files at once on an HPC cluster. It was built for the
EBF2 transcription-factor-binding project at the [Ramani Lab, Gladstone Institutes and
UCSF](https://github.com/RamaniLab), part of a research project on EBF2 binding site
accessibility across brown fat cell differentiation.

## What's in this repo

- **`zmw_selector_updated.py`** — the ZMW-selection script, refactored from the lab's original
  with automatic BAM re-indexing added.
- **`run_zmw_selector.sh`** — a batch job script that loops the selector across every BAM file
  in a folder, written for a PBS/`qsub`-based HPC cluster (UCSF's Wynton).

## How it works

1. **`generate_index(bamfile)`** checks whether a `.bai` index exists next to the BAM file
   (either `<name>.bai` or `<name>.bam.bai`) and whether it's older than the BAM file itself,
   comparing file modification times. If the index is missing or stale, it runs
   `samtools index` before anything reads from the file. This is the main enhancement over the
   original script — without it, a regenerated or newly-transferred BAM file with a stale index
   silently returns wrong or incomplete reads instead of failing loudly.
2. **`readIterator`** wraps `pysam.AlignmentFile.fetch`, calling `generate_index` first, so any
   caller reading a region always gets a validated index.
3. **`calculatePerBase`** is where the actual selection happens. For each site in the input
   sites file:
   - Skip it if its chromosome isn't in the allowed set.
   - Build a window of `[position - window_size, position + window_size]` (skipping sites too
     close to the start of the chromosome for the window to be valid).
   - Fetch every read overlapping that window and pull the ZMW hole number out of the read name
     (PacBio read names are `movie/holeNumber/qStart_qEnd`; splitting on `/` and taking index 1
     gives the hole number).
   - Emit one row per (read, site) pair: hole number, chromosome, read start, read end, site
     position, an optional label, the read's strand, and the site's strand.
4. **`main`** just wires up the CLI: reads the sites file and the valid-chromosomes file into
   memory, calls `calculatePerBase`, and prints each output row to stdout.

## Usage

### Requirements

- Python 3 with `pysam` and `intervaltree` (`pip install -r requirements.txt`). Note:
  `intervaltree` is imported but not currently used by the selection logic in this version —
  harmless, but worth knowing before you go looking for interval-tree logic that isn't there.
- `samtools` available on `PATH` (used for index generation).

### Input files

- **Sites file** (tab-separated, no header): `chrom  position  strand  [label]`. The optional
  4th column is carried straight through into the output — this is how the EBF2 project tagged
  each row with which motif set it came from.
- **Chrom-sizes / valid-chromosomes file**: any whitespace-separated file where the first column
  is a chromosome name (a standard UCSC `.chrom.sizes` file works). Only that first column is
  read; everything else on each line is ignored.
- **BAM file**: does not need to be pre-indexed — `zmw_selector_updated.py` handles that.

### Run directly

```bash
python zmw_selector_updated.py <sites.tsv> <chrom_sizes> <in.bam> <window_size> > out.zmw.tsv
```

All 4 arguments are positional and required. If any of the three file paths don't exist, the
script currently exits with status 1 and **no printed message** — this is a real gap (the shell
wrapper below is much more explicit about what went wrong), so if it exits with nothing printed,
double-check your three file paths first.

### Output format

One tab-separated row per read that overlaps a site's window:

```
zmw_hole_number  chrom  read_start  read_end  site_position  [label]  read_strand  site_strand
```

## Batch processing on an HPC cluster (`run_zmw_selector.sh`)

This is a PBS batch-job script tailored to the EBF2 project's layout on UCSF's Wynton cluster,
not a general-purpose CLI tool — it takes no command-line arguments. To reuse it, edit the
variables at the top of the script:

- `BASE_PATH`, `PEAK_SETS`, `WINDOW_SIZE`, `OUTPUT_PREFIX`, `INITIALS` — project-specific paths
  and labels.
- The Conda environment name (`SAMOSA.zmw`) and the `conda.sh` path on line 8, which is specific
  to this project's account on Wynton.

What it actually does, given those variables: for each peak set, it finds every `.bam` file
under `$BASE_PATH/BA_EBF2.bam/aligned/`, and for each one runs `zmw_selector_updated.py`
against the matching motif file and chrom-sizes file, writing one `.zmw` output file per BAM.
Every step (Conda activation, folder/file existence, the Python call itself) is checked and
reported with an explicit `echo` before continuing or exiting — this is what let non-engineer
labmates re-run it themselves and see exactly what went wrong from the terminal output, rather
than a bare Python traceback.

**Note:** this script originally referenced a script named `zmw_selector_per_BAM.py`, which
doesn't exist in this repo — only `zmw_selector_updated.py` does, so the batch job would have
failed on that line. Fixed to reference the correct filename.

## Attribution

`zmw_selector.py` originates from the [Ramani Lab's SAMOSA
project](https://github.com/RamaniLab/SAMOSA). This repository's contributions are the
automatic re-indexing logic, the general refactor, and the `run_zmw_selector.sh` batch wrapper.
