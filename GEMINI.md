# WGS-Bact

**WGS-Bact** is a nextflow pipeline for processing Bacterial whole genome sequencing (WGS) data. The pipeline is built on top of [fetchngs](https://github.com/nf-core/fetchngs).

## Overview of pipeline (development in progress)

1. Downloads a set of WGS data from NCBI or ENA, using SRA / ENA / DDBJ / GEO ids (via [fetchngs](https://github.com/nf-core/fetchngs)).
2. Trims adaptors from reads (using [fastp](https://github.com/OpenGene/fastp)).
3. Calls variants in each trimmed sample against a reference genome with [snippy](https://github.com/tseemann/snippy).

## TODO list

The pipeline is a fork of fetchngs and there are still some changes we need to make to reflect the fact that it's a new pipeline.
We are in the process of implementing the following changes, after having forked the fetchngs repo:

- GitHub Workflows: Simplify and update the GitHub Actions workflows in .github/workflows/ to reflect
  the new project name and purpose and run a basic test of the full pipeline.
- Add variant calling with snippy on fastp output (requires user to supply a reference genome genbank or fasta file)
- Add snippy to testing and actions workflow

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`ids.csv`:

```csv
SRR9984183
SRR13191702
ERR1160846
ERR1109373
DRR028935
DRR026872
```

Each line represents a database id. Please see next section for supported ids.

Now, you can run the pipeline using:

```bash
nextflow run nf-core/fetchngs \
   -profile <docker/singularity/.../institute> \
   --input ids.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/fetchngs/usage) and the [parameter documentation](https://nf-co.re/fetchngs/parameters).

## Supported ids

Via a single file of ids, provided one-per-line (see [example input file](https://raw.githubusercontent.com/nf-core/test-datasets/fetchngs/sra_ids_test.csv)) the pipeline performs the following steps:

### SRA / ENA / DDBJ / GEO ids

1. Resolve database ids back to appropriate experiment-level ids and to be compatible with the [ENA API](https://ena-docs.readthedocs.io/en/latest/retrieval/programmatic-access.html)
2. Fetch extensive id metadata via ENA API
3. Download FastQ files:
   - If direct download links are available from the ENA API:
     - Fetch in parallel via `wget` and perform `md5sum` check (`--download_method ftp`; default).
     - Fetch in parallel via `aspera-cli` and perform `md5sum` check. Use `--download_method aspera` to force this behaviour.
   - Otherwise use [`sra-tools`](https://github.com/ncbi/sra-tools) to download `.sra` files and convert them to FastQ. Use `--download_method sratools` to force this behaviour.
4. Collate id metadata and paths to FastQ files in a single samplesheet
