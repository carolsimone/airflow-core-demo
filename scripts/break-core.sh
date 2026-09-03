#!/usr/bin/env bash
# The cross-team break. Renames revenue_per_user's OUTPUT column revenue_eur ->
# net_revenue_eur. core stays fully green: the model output alias, its schema.yml
# column, and assert_revenue_non_negative are updated together. finance is NOT
# touched and still does `SELECT revenue_eur FROM analytics.revenue_per_user`,
# so finance_daily fails with: column "revenue_eur" does not exist.
set -euo pipefail
cd "$(dirname "$0")/../dbt"

# 1) model OUTPUT alias only (anchored on COALESCE so the CTE alias on line 31 is untouched)
sed -i.bak -E 's/(COALESCE\(a\.revenue_eur, 0\)[[:space:]]+AS )revenue_eur,/\1net_revenue_eur,/' models/revenue_per_user.sql
# 2) schema.yml column name (anchored on "- name:", so descriptions are untouched)
sed -i.bak -E 's/^([[:space:]]*-[[:space:]]*name:[[:space:]]*)revenue_eur[[:space:]]*$/\1net_revenue_eur/' models/schema.yml
# 3) custom test: both revenue_eur refs (gross_volume_eur does not contain the substring, so global is safe)
sed -i.bak 's/revenue_eur/net_revenue_eur/g' tests/assert_revenue_non_negative.sql
find . -name '*.bak' -delete

# guard: confirm the OUTPUT alias actually flipped
if ! grep -qE '\)[[:space:]]+AS net_revenue_eur,' models/revenue_per_user.sql; then
  echo "PATTERN MISS: output alias not renamed — vendored spacing differs; fix the sed pattern" >&2
  exit 1
fi
echo "break applied: revenue_per_user output column revenue_eur -> net_revenue_eur"
