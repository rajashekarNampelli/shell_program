# CSV Comparison Toolkit

Bash toolkit to export employee data from CockroachDB and compare CSV files for discrepancies.

## Prerequisites

Install the [CockroachDB CLI](https://www.cockroachlabs.com/docs/stable/install-cockroachdb.html):

```bash
# macOS (Homebrew)
brew install cockroachdb/tap/cockroach

# Verify
cockroach version
```

## Setup

1. Copy the config template and fill in your credentials:

```bash
cd Shell_Script_For_CSV_COMPARISION
cp config/db.env.example config/db.env
# Edit config/db.env with your cluster host, port, database, user, and password
```

2. Make scripts executable:

```bash
chmod +x scripts/export_employee.sh scripts/compare_csv.sh
```

## Task 1: Export employee table to CSV

Validate config without connecting to the database:

```bash
./scripts/export_employee.sh --validate
```

Export all rows from the `employee` table:

```bash
./scripts/export_employee.sh
```

Custom table or output path:

```bash
./scripts/export_employee.sh --table employee --out output/employee_baseline.csv
```

Output is written to `output/employee_export_<timestamp>.csv` by default. The CockroachDB CSV format includes a header row.

## Task 2: Incoming CSV from another team

Place files from the other team in the `data/` directory (git-ignored).

## Task 3: Compare CSV files (coming soon)

```bash
./scripts/compare_csv.sh output/employee_export_<timestamp>.csv data/teammate_file.csv
```

This script is a stub; comparison logic will be implemented in a follow-up.

## Project structure

```
Shell_Script_For_CSV_COMPARISION/
├── README.md
├── .gitignore
├── config/
│   ├── db.env.example    # committed template
│   └── db.env            # your credentials (git-ignored)
├── lib/
│   ├── common.sh         # logging, error handling
│   └── db.sh             # connection URL + export helpers
├── scripts/
│   ├── export_employee.sh
│   └── compare_csv.sh
├── data/                 # incoming CSVs (git-ignored)
└── output/               # generated exports (git-ignored)
```

## Standards

- Scripts use `set -euo pipefail` and shared helpers from `lib/`
- Credentials live only in `config/db.env` (never committed)
- Passwords are URL-encoded for the connection string
- Exports are timestamped and non-destructive

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Config file not found` | Copy `config/db.env.example` to `config/db.env` |
| `Required command 'cockroach' not found` | Install the CockroachDB CLI |
| Connection errors | Verify host, port, credentials, and network access to the cluster |
| Empty export file | Check table name and that the table has data |
