# Final Capstone Submission

## What changed

- Added the final Task 4 SQL scripts for transaction normalization, settlement and chargeback aggregation, profitability modeling, KPI reporting, and validation.
- Added the final Task 5 SQL scripts for April/May baseline comparison, segment deterioration, and mix-versus-performance analysis.
- Added the supporting data contract, data-quality report, problem framing, operational/commercial diagnosis, and final presentation artefacts.

## Why

This submission packages the completed payment-profitability model and root-cause analysis into one reproducible handoff for review.

## What was tested

- Reviewed all SQL files for expected Snowflake object references and query structure.
- Scanned text-sized submission files for likely credentials or private-key material; none were found.
- Confirmed the final artefact inventory and repository status before publishing.

## How to verify

1. Open `Task4_SQL_Scripts/00_task4_setup.sql` and run the Task 4 scripts in numeric order in a Snowflake session with the required `ASTRAPAY_DB.RAW` source tables.
2. Run `Task4_SQL_Scripts/06_task4_validation.sql` and confirm the documented duplicate, reconciliation, and integrity checks pass.
3. Run the Task 5 scripts in numeric order after the Task 4 profitability view exists.
4. Review the PDF and spreadsheet deliverables against the SQL outputs.

## Peer review evidence

- Automated pre-submission review completed locally: artefact inventory, SQL header review, staged diff whitespace check, and secret scan.
- Human peer approval is intentionally not claimed here; the GitHub Pull Request is the review record and should be approved by a repository collaborator before merge.