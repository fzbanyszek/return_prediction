begin;

with period_candidates as (
    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_income_statement_id::bigint as source_rank
    from raw.income_statement

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_balance_sheet_id::bigint as source_rank
    from raw.balance_sheet

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_cash_flow_id::bigint as source_rank
    from raw.cash_flow

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, null::text as currency, raw_enterprise_value_id::bigint as source_rank
    from raw.enterprise_value

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, null::text as currency, raw_multiples_id::bigint as source_rank
    from raw.multiples

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, null::text as currency, raw_per_share_id::bigint as source_rank
    from raw.per_share

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_ratios_credit_id::bigint as source_rank
    from raw.ratios_credit

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_ratios_liquidity_id::bigint as source_rank
    from raw.ratios_liquidity

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_ratios_profitability_id::bigint as source_rank
    from raw.ratios_profitability

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_ratios_working_capital_id::bigint as source_rank
    from raw.ratios_working_capital

    union all

    select exchange_code, ticker, report_date, period as period_type, period_label, fiscal_year, currency, raw_ratios_yield_analysis_id::bigint as source_rank
    from raw.ratios_yield_analysis
),
latest_period as (
    select distinct on (exchange_code, ticker, report_date, period_type)
        exchange_code,
        ticker,
        report_date,
        lower(period_type) as period_type,
        period_label,
        fiscal_year,
        currency
    from period_candidates
    where report_date is not null
      and lower(period_type) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period_type, source_rank desc
)
insert into core.reporting_period (
    instrument_id,
    report_date,
    period_type,
    period_label,
    fiscal_year,
    currency
)
select
    i.instrument_id,
    lp.report_date,
    lp.period_type,
    lp.period_label,
    lp.fiscal_year,
    lp.currency
from latest_period lp
join core.instrument i
    on i.exchange_code = lp.exchange_code
   and i.ticker = lp.ticker;

commit;
