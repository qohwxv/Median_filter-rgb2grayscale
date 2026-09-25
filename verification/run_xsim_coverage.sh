#!/usr/bin/env bash
# Run both self-checking unit testbenches with the XSim tools shipped in Vivado.
#
# Usage from the repository root:
#   source /path/to/Vivado/2023.2/settings64.sh
#   bash verification/run_xsim_coverage.sh

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
run_id="$(date +%Y%m%d_%H%M%S)"
run_dir="$repo_root/build/xsim_coverage/$run_id"

for required_tool in xvlog xelab xcrg; do
    if ! command -v "$required_tool" >/dev/null 2>&1; then
        printf 'ERROR: %s is not on PATH. Source Vivado settings64.sh first.\n' "$required_tool" >&2
        exit 127
    fi
done

mkdir -p "$run_dir"
cd "$run_dir"

run_test() {
    local dut_file="$1"
    local tb_file="$2"
    local top_name="$3"
    local db_name="$4"

    local functional_dir="$run_dir/functional/$db_name"
    local code_dir="$run_dir/code/$db_name"
    local report_dir="$run_dir/reports/$db_name"

    mkdir -p "$functional_dir" "$code_dir" "$report_dir"

    printf '\n=== Compiling %s ===\n' "$top_name"
    xvlog -sv "$repo_root/lab2_process/$dut_file" "$repo_root/verification/$tb_file"

    printf '\n=== Simulating %s ===\n' "$top_name"
    xelab "work.$top_name" \
        -s "${db_name}_snapshot" \
        -debug typical \
        -cc_type sbct \
        -cc_db "$db_name" \
        -cc_dir "$code_dir" \
        -cov_db_name "$db_name" \
        -cov_db_dir "$functional_dir" \
        -R

    printf '\n=== Reporting functional coverage: %s ===\n' "$top_name"
    xcrg -dir "$functional_dir" \
         -db_name "$db_name" \
         -report_dir "$report_dir/functional" \
         -report_format all

    printf '\n=== Reporting code coverage: %s ===\n' "$top_name"
    xcrg -cc_db "$db_name" \
         -cc_dir "$code_dir" \
         -cc_report "$report_dir/code"
}

run_test "rgb2gray.v" "tb_rgb2gray_selfcheck.sv" \
         "tb_rgb2gray_selfcheck" "rgb2gray_unit"
run_test "median_filter.v" "tb_median_filter_selfcheck.sv" \
         "tb_median_filter_selfcheck" "median_filter_unit"

printf '\nPASS: all unit tests completed. Reports are under:\n  %s\n' "$run_dir/reports"
