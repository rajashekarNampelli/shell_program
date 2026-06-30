# CSV Comparison Toolkit

Bash toolkit to export employee data from CockroachDB and compare CSV files for discrepancies.

## Prerequisites

### macOS

```bash
brew install cockroachdb/tap/cockroach
cockroach version
```

### Windows

Bash scripts require one of the following environments on Windows:

#### Option 1: WSL — Windows Subsystem for Linux (Recommended)

1. Open PowerShell as Administrator and run:
   ```powershell
   wsl --install
   ```
2. Restart your PC. Ubuntu installs by default.
3. Open the **Ubuntu** app from the Start menu.
4. Inside WSL, install the CockroachDB CLI:
   ```bash
   curl https://binaries.cockroachdb.com/cockroach-latest.linux-amd64.tgz | tar -xz
   sudo cp cockroach-*/cockroach /usr/local/bin/
   cockroach version
   ```
5. Navigate to your project (Windows files are under `/mnt/c/`):
   ```bash
   cd /mnt/c/Users/YourName/path/to/Shell_Script_For_CSV_COMPARISION
   chmod +x scripts/export_employee.sh
   ./scripts/export_employee.sh
   ```

#### Option 2: Git Bash (Lighter alternative)

1. Download and install [Git for Windows](https://git-scm.com/download/win) — choose the **"Git Bash Here"** option during install.
2. Open **Git Bash** from the Start menu and navigate to the project folder.

> Note: Git Bash has limitations installing the `cockroach` CLI. You would need to manually download the Windows binary and add it to your PATH.

#### Windows software checklist

| Software | Purpose | Where to get |
|----------|---------|--------------|
| WSL + Ubuntu | Run bash scripts natively | Built into Windows 10/11 — `wsl --install` |
| CockroachDB CLI | Connect and export data | Install inside WSL (see above) |
| Git for Windows | Version control + Git Bash | [git-scm.com](https://git-scm.com/download/win) |

---

## Setup

1. Copy the config template and fill in your credentials:

```bash
cp config/db.env.example config/db.env
# Edit config/db.env with your connection details
```

2. Make scripts executable (macOS / WSL):

```bash
chmod +x scripts/export_employee.sh scripts/compare_csv.sh
```

## Authentication

Set `AUTH_MODE` in `config/db.env` to choose the auth method:

**Standard password auth** (port 26257):
```bash
DB_HOST=your-host
DB_PORT=26257
DB_USER=your_username
DB_PASSWORD=your_password
AUTH_MODE=password
```

**JWT token auth** (AWS-hosted CockroachDB, port 443):
```bash
DB_HOST=your-aws-host
DB_PORT=443
DB_USER=your_username
DB_PASSWORD=your_jwt_token
AUTH_MODE=JWT
```

## Export employee table to CSV

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

Output is written to `output/employee_export_<timestamp>.csv`. A log file is saved to `logs/export_<timestamp>.log`.

## Incoming CSV from another team

Place files from the other team in the `data/` directory (git-ignored).

## Compare CSV files (coming soon)

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
├── scripts/
│   ├── export_employee.sh
│   └── compare_csv.sh
├── data/                 # incoming CSVs (git-ignored)
├── logs/                 # run logs (git-ignored)
└── output/               # generated exports (git-ignored)
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Config not found` | Copy `config/db.env.example` to `config/db.env` |
| `cockroach not found` | Install CockroachDB CLI (see Prerequisites) |
| Connection errors | Verify host, port, credentials, and network access |
| Empty export file | Check table name and that the table has data |
