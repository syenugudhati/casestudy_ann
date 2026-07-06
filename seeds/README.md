## Approach & Assumptions
 
**Goal:** Given a customer-typed business name, match it against the national Business Names Register (data.gov.au) despite formatting inconsistencies (case, whitespace, legal suffixes, punctuation).
 
**Assumptions made during EDA:**
 
- Every business registered **after 28/05/2012** (national ABN register launch) must carry a valid 11-digit ABN. Rows with `status = Registered` and no valid ABN before this cut-off are treated as legitimate historical records, not data errors.
- Records with the same `BN_NAME` but different `BN_STATE_NUM`/dates (pre-2012) are **not duplicates** — they reflect state-by-state registration before the federal register existed (confirmed via `BOOK A BAY` x8, `CENTREPAY` x7, `ADBRI`, `UNIQUE FLOORS` x3). Full duplicate check across `BN_NAME + BN_STATUS + BN_REG_DT + BN_CANCEL_DT + BN_STATE_OF_REG + BN_ABN` confirmed **zero true duplicates**.
- `BN_REG_DT = 01/01/1753` is a system default for missing exact dates, not a data quality issue. 
- Matching is done on a **normalized `search_key`**, not raw `business_name`, to absorb formatting differences.
## How to Run and Review
 
**1. Environment setup**
 
```bash
python3 -m venv ~/dbt_env   # outside conda base — avoids `dbt init` crash
source ~/dbt_env/bin/activate
pip install dbt-duckdb
```
 
**2. Load raw data into DuckDB**
 
```python
import duckdb, pandas as pd
df_raw = pd.read_csv('local_path', sep='\t') (please replace the "local_path" with your own local filepath)
con = duckdb.connect("register.duckdb")
con.execute("CREATE OR REPLACE TABLE raw_business_names AS SELECT * FROM df_raw")
con.close()  # always close — open connections lock the dbt run
```
 
**3. Build the dbt pipeline**
 
```bash
dbt debug        # confirm connection
dbt run          # staging → intermediate → marts
dbt seed         # loads seeds/search_requests.csv (test inputs)
dbt test         # runs schema tests (not_null, accepted_values)
```
 
**Pipeline layers:**
 
| Layer | Model | Purpose |
|---|---|---|
| staging | `stg_business_names` | trim, normalize raw columns |
| intermediate | `int_business_names_flagged` | flag invalid ABN / registered-without-ABN |
| intermediate | `int_business_names_valid` | dedup after filtering (not before) |
| marts | `business_names_matching` | final table + `search_key` column |
| seed | 'search_requests.csv" | 
| analyses | 'test_search_matching' | check that the matching algorithm works
 
**4. Validate matching**
 
```bash
dbt compile --select test_search_matching
```
 
Run the compiled SQL (`analyses/test_search_matching.sql`) in DuckDB/Jupyter — it joins normalized `search_requests` seed data against `business_names_matching.search_key`.
 
 
## Key Findings
 
- Raw dataset: 3,281,259 rows, 8 columns; 35,505 rows were name repeats, all explained by pre-2012 state-based re-registration, not real duplicates.
- 659,822 `Registered` rows have no ABN — excluded from the mart under the post-28/05/2012 ABN rule.
- Leading whitespace and quotation marks found in a subset of `BN_NAME` values — stripped on both the data side and the customer-input side for consistency.
- **search_key normalization pipeline:** lowercase → strip legal suffix (`pty ltd` / `ltd` / `p/l`) → remove non-alphanumeric characters → collapse/remove whitespace.
- **Bug found during testing:** `"Coastal Earth Works"` failed to match `"COASTAL  EARTH WORKS"` (double space in source data). Root-caused via `length(search_key)` comparison between input and mart — fixed by adding a whitespace-normalization step before suffix stripping.
## Limitations
 
- **Exact match only** on normalized `search_key` — no typo tolerance. Fuzzy matching (`jaro_winkler_similarity`) exists only as a separate, optional demo, not integrated into the core pipeline.
- **Suffix list is narrow** — only handles `pty ltd`, `ltd`, `p/l`. Does not cover `inc`, `co`, `corp`, `pl`, or state-specific variants.
- **Normalization logic is duplicated** in two places (`marts/business_names_matching.sql` for the register data, and the input-side query for customer search terms) since no shared dbt macro was used — any future change must be applied in both places or matching silently breaks.
- **No labeled ground-truth set** — match quality (precision/recall) was spot-checked on a handful of test names, not statistically validated.
