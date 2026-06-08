from __future__ import annotations

import csv
from pathlib import Path

import psycopg


DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "stock_data"
DB_USER = "admin"
DB_PASSWORD = "admin"

EXCHANGE = "ALL"
PERIOD_TYPE = "quarterly"
MIN_REPORT_DATE = "2009-01-01"
MAX_INSTRUMENTS = 10000
ENTRY_LAG_DAYS = 60
TARGET_HORIZON = 252
MIN_MARKET_CAP = 10_000_000_000.0
MIN_PRICE = 1.0

OUTPUT_RELATIVE_PATH = Path("datasets") / "dataset_growth_1y_10b.csv"


def ensure_core_ready(conn: psycopg.Connection) -> None:
    checks = {
        "core.instrument": "select count(*) from core.instrument",
        "core.reporting_period": "select count(*) from core.reporting_period",
        "core.price_daily": "select count(*) from core.price_daily",
        "core.income_statement": "select count(*) from core.income_statement",
        "core.multiples": "select count(*) from core.multiples",
    }

    with conn.cursor() as cur:
        for table_name, sql in checks.items():
            cur.execute(sql)
            row_count = cur.fetchone()[0]
            if row_count == 0:
                raise RuntimeError(
                    f"{table_name} is empty"
                )


def build_dataset_sql() -> str:
    exchange_filter = "i.exchange_code in ('NASDAQ', 'NYSE')"

    return f"""
with instrument_scope as (
    select
        i.instrument_id,
        i.exchange_code,
        i.ticker
    from core.instrument i
    where {exchange_filter}
      and exists (
          select 1
          from core.reporting_period rp
          where rp.instrument_id = i.instrument_id
            and rp.period_type = %(period_type)s
            and rp.report_date >= %(min_report_date)s
      )
    order by i.ticker
    limit {MAX_INSTRUMENTS}
),
base_periods as (
    select
        rp.reporting_period_id,
        rp.instrument_id,
        rp.report_date,
        rp.period_type,
        rp.period_label,
        rp.fiscal_year,
        rp.currency
    from core.reporting_period rp
    join instrument_scope s
      on s.instrument_id = rp.instrument_id
    where rp.period_type = %(period_type)s
      and rp.report_date >= %(min_report_date)s
),
assembled as (
    select
        s.exchange_code,
        s.ticker,
        cp.sector,
        cp.industry,
        bp.report_date,
        bp.period_type,
        bp.period_label,
        bp.fiscal_year,
        bp.currency,
        growth_features.revenue_growth_qoq,
        growth_features.revenue_growth_yoy,
        growth_features.revenue_growing_qoq_flag,
        growth_features.revenue_growing_yoy_flag,
        valuation_features.pe_ratio,
        valuation_features.price_to_sales,
        valuation_features.price_to_book,
        valuation_features.ev_to_ttm_sales,
        valuation_features.price_to_free_cash_flow,
        valuation_features.earnings_yield,
        valuation_features.sales_yield,
        valuation_features.book_yield,
        valuation_features.free_cash_flow_yield,
        valuation_features.ev_sales_yield,
        valuation_features.pe_reasonable_flag,
        valuation_features.price_to_sales_reasonable_flag,
        valuation_features.price_to_book_reasonable_flag,
        valuation_features.ev_to_sales_reasonable_flag,
        valuation_features.price_to_fcf_reasonable_flag,
        valuation_features.not_overvalued_score,
        quality_features.return_on_assets,
        quality_features.return_on_common_equity,
        quality_features.return_on_invested_capital,
        quality_features.current_ratio,
        quality_features.cash_ratio,
        quality_features.quick_ratio,
        quality_features.net_debt_to_shareholder_equity,
        quality_features.total_debt_to_ebitda,
        quality_features.market_cap,
        quality_features.market_cap_log,
        entry_price.trade_date as entry_trade_date,
        entry_price.adj_close as entry_adj_close,
        exit_price.trade_date as target_trade_date,
        exit_price.adj_close as target_adj_close,
        case
            when entry_price.adj_close is not null
             and entry_price.adj_close <> 0
             and exit_price.adj_close is not null
            then (exit_price.adj_close / entry_price.adj_close) - 1
            else null
        end as target_return
    from base_periods bp
    join instrument_scope s
      on s.instrument_id = bp.instrument_id
    left join core.company_profile cp
      on cp.instrument_id = bp.instrument_id
    left join lateral (
        with revenue_series as (
            select
                rp2.reporting_period_id,
                rp2.report_date,
                inc2.revenue,
                lag(inc2.revenue, 1) over (
                    partition by rp2.instrument_id, rp2.period_type
                    order by rp2.report_date
                ) as revenue_prev_quarter,
                lag(inc2.revenue, 4) over (
                    partition by rp2.instrument_id, rp2.period_type
                    order by rp2.report_date
                ) as revenue_prev_year
            from core.reporting_period rp2
            join core.income_statement inc2
              on inc2.reporting_period_id = rp2.reporting_period_id
            where rp2.instrument_id = bp.instrument_id
              and rp2.period_type = bp.period_type
        )
        select
            case
                when rs.revenue_prev_quarter is not null and rs.revenue_prev_quarter <> 0
                then (rs.revenue / rs.revenue_prev_quarter) - 1
                else null
            end as revenue_growth_qoq,
            case
                when rs.revenue_prev_year is not null and rs.revenue_prev_year <> 0
                then (rs.revenue / rs.revenue_prev_year) - 1
                else null
            end as revenue_growth_yoy,
            case
                when rs.revenue_prev_quarter is not null and rs.revenue > rs.revenue_prev_quarter then 1
                when rs.revenue_prev_quarter is not null then 0
                else null
            end as revenue_growing_qoq_flag,
            case
                when rs.revenue_prev_year is not null and rs.revenue > rs.revenue_prev_year then 1
                when rs.revenue_prev_year is not null then 0
                else null
            end as revenue_growing_yoy_flag
        from revenue_series rs
        where rs.reporting_period_id = bp.reporting_period_id
    ) growth_features on true
    left join lateral (
        select
            mul.pe_ratio,
            mul.price_to_sales,
            mul.price_to_book,
            mul.ev_to_ttm_sales,
            mul.price_to_free_cash_flow,
            case when mul.pe_ratio > 0 then 1.0 / mul.pe_ratio else null end as earnings_yield,
            case when mul.price_to_sales > 0 then 1.0 / mul.price_to_sales else null end as sales_yield,
            case when mul.price_to_book > 0 then 1.0 / mul.price_to_book else null end as book_yield,
            case when mul.price_to_free_cash_flow > 0 then 1.0 / mul.price_to_free_cash_flow else null end as free_cash_flow_yield,
            case when mul.ev_to_ttm_sales > 0 then 1.0 / mul.ev_to_ttm_sales else null end as ev_sales_yield,
            case when mul.pe_ratio between 0 and 25 then 1 else 0 end as pe_reasonable_flag,
            case when mul.price_to_sales between 0 and 8 then 1 else 0 end as price_to_sales_reasonable_flag,
            case when mul.price_to_book between 0 and 8 then 1 else 0 end as price_to_book_reasonable_flag,
            case when mul.ev_to_ttm_sales between 0 and 8 then 1 else 0 end as ev_to_sales_reasonable_flag,
            case when mul.price_to_free_cash_flow between 0 and 30 then 1 else 0 end as price_to_fcf_reasonable_flag,
            (
                (case when mul.pe_ratio between 0 and 25 then 1 else 0 end) +
                (case when mul.price_to_sales between 0 and 8 then 1 else 0 end) +
                (case when mul.price_to_book between 0 and 8 then 1 else 0 end) +
                (case when mul.ev_to_ttm_sales between 0 and 8 then 1 else 0 end) +
                (case when mul.price_to_free_cash_flow between 0 and 30 then 1 else 0 end)
            ) / 5.0 as not_overvalued_score
        from core.multiples mul
        where mul.reporting_period_id = bp.reporting_period_id
    ) valuation_features on true
    left join lateral (
        select
            rpft.return_on_assets,
            rpft.return_on_common_equity,
            rpft.return_on_invested_capital,
            rl.current_ratio,
            rl.cash_ratio,
            rl.quick_ratio,
            rc.net_debt_to_shareholder_equity,
            rc.total_debt_to_ebitda,
            ev.market_cap,
            case when ev.market_cap > 0 then ln(ev.market_cap) else null end as market_cap_log
        from core.ratios_profitability rpft
        left join core.ratios_liquidity rl
          on rl.reporting_period_id = rpft.reporting_period_id
        left join core.ratios_credit rc
          on rc.reporting_period_id = rpft.reporting_period_id
        left join core.enterprise_value ev
          on ev.reporting_period_id = rpft.reporting_period_id
        where rpft.reporting_period_id = bp.reporting_period_id
    ) quality_features on true
    join lateral (
        select
            pd.trade_date,
            pd.adj_close
        from core.price_daily pd
        where pd.instrument_id = bp.instrument_id
          and pd.trade_date >= (bp.report_date + (%(entry_lag_days)s * interval '1 day'))
          and pd.adj_close is not null
        order by pd.trade_date asc
        limit 1
    ) entry_price on true
    left join lateral (
        select
            pd.trade_date,
            pd.adj_close
        from core.price_daily pd
        where pd.instrument_id = bp.instrument_id
          and pd.trade_date >= entry_price.trade_date
          and pd.adj_close is not null
        order by pd.trade_date asc
        offset {TARGET_HORIZON}
        limit 1
    ) exit_price on true
),
labeled as (
    select
        a.*,
        date_trunc('quarter', a.entry_trade_date)::date as entry_quarter
    from assembled a
    where a.target_return is not null
      and a.market_cap is not null
      and a.market_cap >= %(min_market_cap)s
      and a.entry_adj_close is not null
      and a.entry_adj_close >= %(min_price)s
)
select *
from labeled
where report_date >= '2010-01-01'
order by exchange_code, ticker, report_date
"""


def export_dataset() -> tuple[Path, int]:
    output_path = OUTPUT_RELATIVE_PATH.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    params = {
        "period_type": PERIOD_TYPE,
        "min_report_date": MIN_REPORT_DATE,
        "entry_lag_days": ENTRY_LAG_DAYS,
        "min_market_cap": MIN_MARKET_CAP,
        "min_price": MIN_PRICE,
    }

    row_count = 0
    with psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    ) as conn:
        ensure_core_ready(conn)

        with conn.cursor() as cur, output_path.open("w", encoding="utf-8", newline="") as handle:
            cur.execute(build_dataset_sql(), params)
            writer = csv.writer(handle)
            writer.writerow([column.name for column in cur.description])

            while True:
                rows = cur.fetchmany(2000)
                if not rows:
                    break
                writer.writerows(rows)
                row_count += len(rows)

    return output_path, row_count


def main() -> int:
    _, row_count = export_dataset()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
