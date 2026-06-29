#!/usr/bin/env bash
# Compare two CSV files and report discrepancies (Task 3 - not yet implemented).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") CSV_A CSV_B [OPTIONS]

Compare two CSV files and report records with discrepancies.

Arguments:
  CSV_A   First CSV file (e.g. DB export from export_employee.sh)
  CSV_B   Second CSV file (e.g. file from another team in data/)

Options:
  --key COLUMN   Primary key column for row matching (default: TBD)
  --out PATH     Output discrepancies CSV (default: output/discrepancies_<timestamp>.csv)
  -h, --help     Show this help message

Status: NOT YET IMPLEMENTED

Planned behavior:
  - Normalize and sort both CSVs
  - Match rows by primary key column (likely employee id)
  - Report rows only in CSV_A, only in CSV_B, and field-level differences
  - Write results to output/discrepancies_<timestamp>.csv
EOF
}

main() {
  if [[ $# -eq 0 ]] || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  die "compare_csv.sh is not yet implemented. See --help for planned behavior."
}

main "$@"
