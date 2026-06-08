begin;

with latest_enterprise_value as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.enterprise_value
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_enterprise_value_id desc
)
insert into core.enterprise_value (
    reporting_period_id,
    market_cap,
    cash_and_near_cash,
    minority_interest,
    short_and_long_term_debt,
    enterprise_value,
    total_capital,
    total_debt_to_total_capital,
    total_debt_to_enterprise_value,
    ev_to_ttm_sales,
    diluted_market_cap,
    diluted_enterprise_value,
    ev_to_shares_outstanding,
    ttm_sales,
    ttm_ebitda,
    ttm_operating_income,
    ttm_cash_flow_firm,
    ttm_free_cash_flow_firm,
    preferred_equity_and_hybrid_capital
)
select
    rp.reporting_period_id,
    core.try_numeric(le.payload ->> 'market_cap'),
    core.try_numeric(le.payload ->> 'bs_cash_near_cash_item'),
    core.try_numeric(le.payload ->> 'bs_minority_noncontrolling_interest'),
    core.try_numeric(le.payload ->> 'short_and_long_term_debt'),
    core.try_numeric(le.payload ->> 'enterprise_value'),
    core.try_numeric(le.payload ->> 'bs_tot_cap'),
    core.try_numeric(le.payload ->> 'tot_debt_to_tot_cap'),
    core.try_numeric(le.payload ->> 'total_debt_to_ev'),
    core.try_numeric(le.payload ->> 'ev_to_ttm_sales'),
    core.try_numeric(le.payload ->> 'diluted_mkt_cap'),
    core.try_numeric(le.payload ->> 'diluted_ev'),
    core.try_numeric(le.payload ->> 'ev_to_sh_out'),
    core.try_numeric(le.payload ->> 'ttm_net_sales'),
    core.try_numeric(le.payload ->> 'ttm_ebitda'),
    core.try_numeric(le.payload ->> 'ttm_oper_inc'),
    core.try_numeric(le.payload ->> 'ttm_cash_flow_firm'),
    core.try_numeric(le.payload ->> 'ttm_free_cash_flow_firm'),
    core.try_numeric(le.payload ->> 'bs_pfd_eqty_and_hybrid_cptl')
from latest_enterprise_value le
join core.instrument i
    on i.exchange_code = le.exchange_code
   and i.ticker = le.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = le.report_date
   and rp.period_type = le.period_type;

commit;
