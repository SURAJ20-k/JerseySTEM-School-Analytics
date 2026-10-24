# JerseySTEM — School Analytics

## Project Overview
A school CRM data-quality and analytics assessment using MySQL 8 and Google Looker Studio. The project analyzes schools, contacts, STEM clubs, and deliverables to identify operational trends, student participation, and overdue work.

## Tools
MySQL, SQLTools, VS Code, Google Sheets, and Google Looker Studio.

## Dataset
Four source datasets:
- School: 100 records
- Contact: 305 raw records
- Club: 200 records
- Deliverable: 404 records

After cleaning, the final working tables contain 100 schools, 298 contacts, 200 clubs, and 404 deliverables.

## Data Quality and Cleaning
- Performed 25 diagnostic checks.
- Standardized categories, dates, ZIP codes, phone numbers, and invalid values.
- Removed five confirmed duplicate contact records from the working table.
- Quarantined two contacts without matching schools.
- Validated four foreign-key relationships.
- Preserved unresolved exceptions rather than inventing missing data.

Remaining limitations include eight schools without contacts, three clubs without assigned lead contacts, four completed deliverables without completion dates, and one duplicate-contact case requiring review.

## SQL Reporting
Seven reporting views support:
- School and club performance
- Overdue deliverables
- Participation by school type
- Top schools by students served
- Schools with contacts but no clubs
- Deliverable workload and status summaries

## Dashboard
Two-page Looker Studio report containing school KPIs, school-type comparisons, overdue-work analysis, deliverable-status analysis, student participation, and primary-contact details.

**Looker Studio report:** [Insert public report URL here]

## Key Findings
- 100 schools and 200 clubs.
- 42 confirmed clubs.
- 404 deliverables across four statuses.
- 213 overdue deliverables as of October 23, 2026, based on the reporting snapshot.
- Student participation totals represent known reported counts and may not represent unique individual students.

## Repository Structure
- `data/` — source datasets
- `docs/` — data dictionary and ER diagram
- `sql/` — schema, diagnostics, cleanup, and reporting views
- `report/` — dashboard export and reporting datasets

## Notes
The overdue-deliverable analysis uses the current date in SQL, so results can change when queries are rerun. Some missing or ambiguous values were intentionally left unresolved and documented.

This project was completed as a JerseySTEM School Analytics assessment.
