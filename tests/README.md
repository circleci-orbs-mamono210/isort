# Test fixtures

Fixtures used by `.circleci/test-deploy.yml`. isort exits 0 when it finds no
Python files, so the tests need real sources to be meaningful.

- `clean/sorted.py` is already sorted under isort's defaults, so the default
  parameters must exit 0 on it.
- `clean/single_line.py` keeps two names on one `from` import. It is clean by
  default and stops being clean under `force-single-line-imports`, which is
  what proves that parameter reached isort.
- `clean/long_import.py` has a `from` import that fits in 79 columns but not
  in 40. It is clean by default and stops being clean at
  `line-length: "40"`, which is what proves that parameter reached isort. The
  `line-length` test greps for this filename, so keep the name in mind when
  editing the fixture.
- `unsorted/order.py` has its imports in the wrong order under every
  configuration. It backs the `output-file`, `tee`, report-truncation and
  `filter-files` tests, which grep for `+import os` in the diff.
- `unsorted/black_style.py` is wrapped the way the black profile wraps a long
  `from` import. It fails under the defaults and passes under
  `profile: black`, which is what proves the profile reached isort.

Both directories carry an invariant. Everything under `clean/` must stay
clean under the defaults, and everything under `unsorted/` must stay
unsorted, because several tests assert on the absence of a failure as well as
its presence. Adding a violation to `clean/`, or a correctly sorted file to
`unsorted/`, would make those tests pass or fail for the wrong reason.

The write mode test sorts `unsorted/` in place and then restores it with
`git checkout`, so the fixtures have to be committed rather than generated.
