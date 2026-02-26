"""
build-db.py — FinOps Data Pipeline
===================================
Reads raw Cost Management JSON → builds SQLite → runs data science analysis.

Tables created:
    raw_daily_service      daily cost × MeterCategory
    raw_daily_rg           daily cost × ResourceGroup
    raw_daily_meter        daily cost × ServiceName
    raw_monthly_service_rg monthly cost × MeterCategory × ResourceGroup

Analysis tables:
    v_service_monthly      monthly pivot by service
    analysis_cv            CV%, trend, RI eligibility per service
    analysis_rg_monthly    monthly cost per RG
    analysis_anomalies     daily anomaly flags (z-score + IQR methods)
    analysis_ri            RI/Savings Plan sizing recommendations
    analysis_shutdown      estimate of shutdown savings (nights + weekends)

Output: tools/finops/dev-costs.db
        tools/finops/analysis-summary.txt  (human-readable findings)
"""

import sqlite3, json, re, sys, os
from pathlib import Path
from datetime import datetime, timedelta

import numpy  as np
import pandas as pd

BASE   = Path(__file__).parent
RAW    = BASE / "raw"
DB     = BASE / "dev-costs.db"
REPORT = BASE / "analysis-summary.txt"

# ─────────────────────────────────────────────────────────────────────────────
# 1.  PARSE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def load_json(fname: str) -> dict:
    p = RAW / fname
    if not p.exists():
        sys.exit(f"[ERROR] {p} not found. Run extract-costs.ps1 first.")
    return json.loads(p.read_text(encoding="utf-8"))


def parse_rows(raw: dict, col_map: dict) -> pd.DataFrame:
    """
    Cost Management API response:
        properties.columns = [{name, type}, ...]
        properties.rows    = [[val, val, ...], ...]
    col_map maps API column names → desired DataFrame column names.
    """
    props   = raw["properties"]
    cols    = [c["name"] for c in props["columns"]]
    rows    = props.get("rows", [])
    df      = pd.DataFrame(rows, columns=cols)
    df      = df.rename(columns=col_map)
    # parse UsageDate (YYYYMMDD int or str)
    if "date" in df.columns:
        df["date"] = pd.to_datetime(df["date"].astype(str), format="%Y%m%d")
    if "month" in df.columns:
        df["month"] = pd.to_datetime(df["month"].astype(str), format="%Y%m%d")
        df["month"] = df["month"].dt.to_period("M").dt.to_timestamp()
    # ensure cost is float
    if "cost" in df.columns:
        df["cost"] = df["cost"].astype(float)
    return df


def env_tier(name: str) -> str:
    n = str(name).lower()
    if re.search(r"[-_]dev\d*$|[-_]dev[-_]|infoasst-dev|evadev|evachdev", n): return "Dev"
    if re.search(r"[-_]stg\d*$|[-_]stg[-_]|infoasst-stg|evachatstg|staging", n): return "Stg"
    if re.search(r"[-_]prd|[-_]prod|evachatprd|evachatprd", n):                   return "Prod"
    if re.search(r"hccld2", n):                                                    return "Dev"
    return "Shared"


# ─────────────────────────────────────────────────────────────────────────────
# 2.  LOAD + INGEST
# ─────────────────────────────────────────────────────────────────────────────

print("Loading raw JSON files...")

svc  = parse_rows(load_json("daily_by_service.json"),
                  {"Cost": "cost", "MeterCategory": "service", "UsageDate": "date"})
rg   = parse_rows(load_json("daily_by_rg.json"),
                  {"Cost": "cost", "ResourceGroupName": "rg", "UsageDate": "date"})
mtr  = parse_rows(load_json("daily_by_meter.json"),
                  {"Cost": "cost", "ServiceName": "service_name", "UsageDate": "date"})
msr  = parse_rows(load_json("monthly_by_service_rg.json"),
                  {"Cost": "cost", "MeterCategory": "service",
                   "ResourceGroupName": "rg", "UsageDate": "month"})

rg["tier"] = rg["rg"].apply(env_tier)

print(f"  daily_by_service   : {len(svc):>5} rows  "
      f"({svc['date'].min().date()} → {svc['date'].max().date()})")
print(f"  daily_by_rg        : {len(rg):>5} rows")
print(f"  daily_by_meter     : {len(mtr):>5} rows")
print(f"  monthly_service_rg : {len(msr):>5} rows")

# ─────────────────────────────────────────────────────────────────────────────
# 3.  WRITE TO SQLITE
# ─────────────────────────────────────────────────────────────────────────────

print(f"\nBuilding SQLite → {DB}")
DB.unlink(missing_ok=True)
con = sqlite3.connect(DB)

svc.to_sql("raw_daily_service",      con, if_exists="replace", index=False)
rg .to_sql("raw_daily_rg",           con, if_exists="replace", index=False)
mtr.to_sql("raw_daily_meter",        con, if_exists="replace", index=False)
msr.to_sql("raw_monthly_service_rg", con, if_exists="replace", index=False)

con.execute("""
    CREATE INDEX IF NOT EXISTS idx_svc_date    ON raw_daily_service(date, service);
""")
con.execute("""
    CREATE INDEX IF NOT EXISTS idx_rg_date     ON raw_daily_rg(date, rg);
""")
con.commit()
print("  Raw tables written.")

# ─────────────────────────────────────────────────────────────────────────────
# 4.  ANALYSIS — CV%, TREND, RI CANDIDACY
# ─────────────────────────────────────────────────────────────────────────────
print("\nRunning data science analysis...")

# --- 4a. Monthly totals per service ------------------------------------------
svc_monthly = (
    svc.assign(month=svc["date"].dt.to_period("M").dt.to_timestamp())
       .groupby(["month", "service"])["cost"]
       .sum()
       .reset_index()
)

# Pivot: rows=service, cols=month
pivot = svc_monthly.pivot(index="service", columns="month", values="cost").fillna(0)

# Annualise: multiply 3-month average × 4
months_in_data = len(pivot.columns)
annual_factor  = 12 / months_in_data

cv_rows = []
for svc_name, row in pivot.iterrows():
    vals        = row.values.astype(float)
    mean_monthly= vals.mean()
    std_monthly = vals.std(ddof=1) if len(vals) > 1 else 0
    cv_pct      = (std_monthly / mean_monthly * 100) if mean_monthly > 0 else 999
    annual_cad  = mean_monthly * 12

    # Trend: simple linear regression slope (CAD/month)
    if len(vals) >= 2:
        x     = np.arange(len(vals))
        slope = np.polyfit(x, vals, 1)[0]
    else:
        slope = 0

    # RI eligibility (Azure Savings Plan ~17% / RI 1yr ~35%)
    eligible_sp = cv_pct < 60 and annual_cad > 500
    eligible_ri = cv_pct < 40 and annual_cad > 1000
    ri_saving_sp = annual_cad * 0.17 if eligible_sp else 0
    ri_saving_ri = annual_cad * 0.35 if eligible_ri else 0

    # Rating
    if   cv_pct < 20:  rating = "EXCELLENT"
    elif cv_pct < 35:  rating = "GOOD"
    elif cv_pct < 60:  rating = "FAIR"
    else:              rating = "INELIGIBLE"

    cv_rows.append({
        "service":        svc_name,
        "mean_monthly":   round(mean_monthly, 2),
        "annual_cad":     round(annual_cad, 2),
        "cv_pct":         round(cv_pct, 1),
        "trend_per_month":round(slope, 2),
        "ri_eligible_sp": int(eligible_sp),
        "ri_eligible_ri": int(eligible_ri),
        "saving_sp_17pct":round(ri_saving_sp, 2),
        "saving_ri_35pct":round(ri_saving_ri, 2),
        "ri_rating":      rating,
    })

cv_df = pd.DataFrame(cv_rows).sort_values("annual_cad", ascending=False)
cv_df.to_sql("analysis_cv", con, if_exists="replace", index=False)

# Monthly pivot by service → useful for Excel
svc_monthly.to_sql("v_service_monthly", con, if_exists="replace", index=False)
print(f"  analysis_cv        : {len(cv_df)} services")

# --- 4b. Monthly cost per RG -------------------------------------------------
rg_monthly = (
    rg.assign(month=rg["date"].dt.to_period("M").dt.to_timestamp())
      .groupby(["month", "rg", "tier"])["cost"]
      .sum()
      .reset_index()
)
rg_monthly.to_sql("analysis_rg_monthly", con, if_exists="replace", index=False)
print(f"  analysis_rg_monthly: {len(rg_monthly)} rows")

# --- 4c. Anomaly detection on daily totals -----------------------------------
daily_total = svc.groupby("date")["cost"].sum().reset_index().sort_values("date")
daily_total = daily_total.set_index("date")

# Rolling 30-day baseline + z-score
roll          = daily_total["cost"].rolling(30, min_periods=7)
rolling_mean  = roll.mean()
rolling_std   = roll.std()
z_score       = (daily_total["cost"] - rolling_mean) / rolling_std.replace(0, np.nan)

# IQR method (robust)
q1, q3 = daily_total["cost"].quantile([0.25, 0.75])
iqr     = q3 - q1
iqr_hi  = q3 + 3 * iqr

anom = daily_total.copy()
anom["rolling_mean"] = rolling_mean.values
anom["rolling_std"]  = rolling_std.values
anom["z_score"]      = z_score.values
anom["iqr_upper"]    = iqr_hi
anom["is_anomaly_z"] = (z_score.abs() > 3).astype(int)
anom["is_anomaly_iqr"]= (daily_total["cost"] > iqr_hi).astype(int)
anom["is_anomaly"]   = ((anom["is_anomaly_z"] == 1) | (anom["is_anomaly_iqr"] == 1)).astype(int)
anom = anom.reset_index()
anom.to_sql("analysis_anomalies", con, if_exists="replace", index=False)

anomaly_days = anom[anom["is_anomaly"] == 1]
print(f"  analysis_anomalies : {len(anomaly_days)} anomaly days detected")

# --- 4d. RI sizing table (top candidates) ------------------------------------
ri_cands = cv_df[cv_df["ri_eligible_sp"] == 1].copy()
ri_cands = ri_cands.sort_values("saving_ri_35pct", ascending=False)
ri_cands.to_sql("analysis_ri", con, if_exists="replace", index=False)
print(f"  analysis_ri        : {len(ri_cands)} RI candidates")

# --- 4e. Shutdown savings estimate -------------------------------------------
#  Night off-hours: 8h/24h = 33%  |  Nights+weekends: ~47%
#  Applicable services: App Service, Container Apps, Virtual Machines, Dev Box
STOPPABLE = {
    "Azure App Service",
    "Container Apps",
    "Azure Container Apps",   # alt name
    "Virtual Machines",
    "Microsoft Dev Box",
}

stop_df = cv_df[cv_df["service"].isin(STOPPABLE)].copy()
stop_df["saving_nights_33pct"]    = (stop_df["annual_cad"] * 0.33).round(2)
stop_df["saving_nights_wknd_47pct"]= (stop_df["annual_cad"] * 0.47).round(2)
stop_df.to_sql("analysis_shutdown", con, if_exists="replace", index=False)

con.commit()

# ─────────────────────────────────────────────────────────────────────────────
# 5.  SUMMARY REPORT
# ─────────────────────────────────────────────────────────────────────────────

lines = []
SEP   = "=" * 68

def h(title):
    lines.append("")
    lines.append(SEP)
    lines.append(f"  {title}")
    lines.append(SEP)

# Date range
date_min = svc["date"].min().strftime("%Y-%m-%d")
date_max = svc["date"].max().strftime("%Y-%m-%d")
total_90d = svc["cost"].sum()
avg_month = total_90d / months_in_data
annual_run = avg_month * 12

lines.append(f"FinOps Analysis — EsDAICoESub (Dev)")
lines.append(f"Generated : {datetime.now().strftime('%Y-%m-%d %H:%M')}")
lines.append(f"Period    : {date_min} → {date_max}  ({months_in_data} months)")
lines.append(f"Total {months_in_data}mo : CAD {total_90d:,.2f}")
lines.append(f"Avg/month : CAD {avg_month:,.2f}")
lines.append(f"Run-rate  : CAD {annual_run:,.2f}/year")

# Top 15 services by annual run-rate
h("TOP 15 SERVICES — Annual Run-Rate")
top15 = cv_df.head(15)
for _, r in top15.iterrows():
    lines.append(
        f"  {r['annual_cad']:>12,.2f} CAD/yr  "
        f"CV={r['cv_pct']:>5.1f}%  "
        f"{r['ri_rating']:<12}  "
        f"trend {r['trend_per_month']:>+8.2f}/mo  "
        f"{r['service']}"
    )

# Monthly breakdown
h("MONTHLY COST BREAKDOWN BY SERVICE")
monthly_pivot = (
    svc_monthly.pivot(index="service", columns="month", values="cost")
               .fillna(0)
               .sort_values(svc_monthly["month"].max(), ascending=False)
               .head(15)
)
hdr = " " * 35 + "".join(f"  {str(c.date())[:7]:>10}" for c in monthly_pivot.columns)
lines.append(hdr)
for svc_name, row in monthly_pivot.iterrows():
    row_str = "".join(f"  {v:>10,.0f}" for v in row.values)
    lines.append(f"  {svc_name[:33]:<33}{row_str}")

# RG monthly (top 20)
h("TOP 20 RESOURCE GROUPS — Monthly Cost")
rg_pivot = (
    rg_monthly.pivot_table(index=["rg","tier"], columns="month", values="cost", aggfunc="sum")
              .fillna(0)
)
rg_pivot["total"] = rg_pivot.sum(axis=1)
rg_pivot = rg_pivot.sort_values("total", ascending=False).head(20)
for idx, row in rg_pivot.iterrows():
    rg_name, tier = idx
    monthly_vals = "".join(f"  {v:>10,.0f}" for v in row.values[:-1])
    lines.append(f"  [{tier:<6}]  {rg_name[:35]:<35}  total={row['total']:>10,.0f}{monthly_vals}")

# RI candidates
h("RI / SAVINGS PLAN CANDIDATES")
lines.append(f"  {'Service':<35} {'Annual CAD':>12}  {'CV%':>5}  {'Rating':<12}  "
             f"{'SP@17%':>10}  {'RI@35%':>10}")
lines.append("  " + "-" * 95)
for _, r in ri_cands.iterrows():
    lines.append(
        f"  {r['service'][:35]:<35} {r['annual_cad']:>12,.2f}  "
        f"{r['cv_pct']:>5.1f}  {r['ri_rating']:<12}  "
        f"{r['saving_sp_17pct']:>10,.2f}  {r['saving_ri_35pct']:>10,.2f}"
    )

ri_sp_total = ri_cands["saving_sp_17pct"].sum()
ri_ri_total = ri_cands["saving_ri_35pct"].sum()
lines.append(f"\n  TOTAL potential saving — Savings Plan @17% : CAD {ri_sp_total:>10,.2f}/yr")
lines.append(f"  TOTAL potential saving — Reserved 1yr @35%  : CAD {ri_ri_total:>10,.2f}/yr")

# Shutdown savings
h("SHUTDOWN SAVING ESTIMATE (Stoppable Compute)")
lines.append(f"  {'Service':<35} {'Annual CAD':>12}  {'Nights 33%':>12}  {'N+Wknd 47%':>12}")
lines.append("  " + "-" * 75)
for _, r in stop_df.iterrows():
    lines.append(
        f"  {r['service'][:35]:<35} {r['annual_cad']:>12,.2f}  "
        f"{r['saving_nights_33pct']:>12,.2f}  "
        f"{r['saving_nights_wknd_47pct']:>12,.2f}"
    )
stop_total = stop_df["annual_cad"].sum()
lines.append(f"\n  {'TOTAL stoppable compute':<35} {stop_total:>12,.2f}")
lines.append(f"  {'Saving — nights only (33%)':<35} {stop_df['saving_nights_33pct'].sum():>12,.2f}")
lines.append(f"  {'Saving — nights + weekends (47%)':<35} {stop_df['saving_nights_wknd_47pct'].sum():>12,.2f}")

# Anomalies
h("ANOMALY DETECTION — Daily Total Spend")
lines.append(f"  Method: Z-score (>3σ on 30-day rolling baseline) + IQR (>Q3+3×IQR)")
lines.append(f"  Anomaly days detected: {len(anomaly_days)}")
if len(anomaly_days) > 0:
    lines.append(f"\n  {'Date':<12}  {'Cost CAD':>12}  {'Baseline':>12}  {'Z-score':>8}  IQR flag")
    lines.append("  " + "-" * 60)
    for _, r in anomaly_days.iterrows():
        d   = pd.to_datetime(r["date"]).strftime("%Y-%m-%d")
        zs  = r["z_score"] if not np.isnan(r["z_score"]) else 0
        lines.append(
            f"  {d:<12}  {r['cost']:>12,.2f}  {r['rolling_mean']:>12,.2f}  "
            f"{zs:>8.2f}  {'YES' if r['is_anomaly_iqr'] else ''}"
        )

# DB schema
h("DATABASE TABLES")
for tbl in ["raw_daily_service","raw_daily_rg","raw_daily_meter",
            "raw_monthly_service_rg","v_service_monthly",
            "analysis_cv","analysis_rg_monthly","analysis_anomalies",
            "analysis_ri","analysis_shutdown"]:
    cnt = con.execute(f"SELECT COUNT(*) FROM {tbl}").fetchone()[0]
    lines.append(f"  {tbl:<35} {cnt:>6} rows")

lines.append("")
lines.append(f"DB path: {DB}")

report_text = "\n".join(lines)
REPORT.write_text(report_text, encoding="utf-8")
print(report_text)

con.close()
print(f"\n✓ Database : {DB}")
print(f"✓ Report   : {REPORT}")
