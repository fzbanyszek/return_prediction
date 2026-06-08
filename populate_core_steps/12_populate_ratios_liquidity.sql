begin;

with latest_ratios_liquidity as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.ratios_liquidity
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_ratios_liquidity_id desc
)
insert into core.ratios_liquidity (
    reporting_period_id,
    cash_ratio,
    current_ratio,
    quick_ratio,
    common_equity_to_total_assets,
    long_term_debt_to_total_equity,
    long_term_debt_to_total_capital,
    long_term_debt_to_total_assets,
    total_debt_to_total_equity,
    total_debt_to_total_capital,
    total_debt_to_total_assets,
    altman_z_score,
    cfo_to_avg_current_liabilities,
    cash_flow_to_total_liabilities
)
select
    rp.reporting_period_id,
    core.try_numeric(lr.payload ->> 'cash_ratio'),
    core.try_numeric(lr.payload ->> 'cur_ratio'),
    core.try_numeric(lr.payload ->> 'quick_ratio'),
    core.try_numeric(lr.payload ->> 'com_eqy_to_tot_asset'),
    core.try_numeric(lr.payload ->> 'lt_debt_to_tot_eqy'),
    core.try_numeric(lr.payload ->> 'lt_debt_to_tot_cap'),
    core.try_numeric(lr.payload ->> 'lt_debt_to_tot_asset'),
    core.try_numeric(lr.payload ->> 'tot_debt_to_tot_eqy'),
    core.try_numeric(lr.payload ->> 'tot_debt_to_tot_cap'),
    core.try_numeric(lr.payload ->> 'tot_debt_to_tot_asset'),
    core.try_numeric(lr.payload ->> 'altman_z_score'),
    core.try_numeric(lr.payload ->> 'cfo_to_avg_current_liabilities'),
    core.try_numeric(lr.payload ->> 'cash_flow_to_tot_liab')
from latest_ratios_liquidity lr
join core.instrument i
    on i.exchange_code = lr.exchange_code
   and i.ticker = lr.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lr.report_date
   and rp.period_type = lr.period_type;

commit;
