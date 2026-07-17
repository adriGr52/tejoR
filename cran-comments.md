## Resubmission
This is a resubmission addressing the review by Konstanze Lauseker
(2026-07-09). Changes:

1. English title and description added, keeping the Spanish description
   as well (English first; Spanish after "Descripcion en espanol:").
2. All software, package and API names are in single quotes in Title and
   Description ('Python', 'tejo', 'sf', 'sha256', 'crosswalks',
   'tejo-crosswalk/0.2'). The previously unquoted "Python" was fixed.
3. Method references added to the Description field in the requested
   format: Tobler (1979) <doi:10.1080/01621459.1979.10481647>;
   Mennis (2003) <doi:10.1111/0033-0124.10042>.

No code changes. Version bumped 0.2.1 -> 0.2.2.

## Test environments
* win-builder: R-devel re-run for 0.2.2 (0.2.1 previously checked on
  R-devel, R-release 4.6.1 and R-oldrelease 4.5.3: 1 NOTE each)
* GitHub Actions: ubuntu-latest (R release + devel), windows-latest,
  macos-latest
* local: Ubuntu 24.04, R 4.3.3

## R CMD check results
0 errors | 0 warnings | 1 note
* The only NOTE is "New submission". Words flagged as possibly misspelled
  are intentional Spanish terms and proper nouns (bilingual Description).

## Comments
* Tests (34 expectations) run in ~10s; examples in ~1s.
* Implements the 'tejo-crosswalk/0.2' specification, interoperable with
  the 'Python' package 'tejo' (equivalence verified to 1e-12 on the full
  Bogota use case).
