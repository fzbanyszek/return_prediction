begin;

with latest_ratios_yield_analysis as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.ratios_yield_analysis
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_ratios_yield_analysis_id desc
)
insert into core.ratios_yield_analysis (
    reporting_period_id,
    enterprise_value,
    ttm_after_tax_interest_expense,
    ttm_free_cash_flow_to_firm_yield,
    free_cash_flow_firm,
    ttm_cash_from_operations,
    ttm_free_cash_flow,
    free_cash_flow_yield,
    ttm_cash_from_financing,
    shareholder_yield_cash_from_financing,
    other_financing_activities,
    cash_from_operations,
    capital_yield
)
select
    rp.reporting_period_id,
    core.try_numeric(lr.payload ->> 'enterprise_value'),
    core.try_numeric(lr.payload ->> 'ttm_after_tax_interest_expense'),
    core.try_numeric(lr.payload ->> 'ttm_fcf_to_firm_yield'),
    core.try_numeric(lr.payload ->> 'cf_free_cash_flow_firm'),
    core.try_numeric(lr.payload ->> 'ttm_cash_from_oper'),
    core.try_numeric(lr.payload ->> 'ttm_free_cash_flow'),
    core.try_numeric(lr.payload ->> 'free_cash_flow_yield'),
    core.try_numeric(lr.payload ->> 'ttm_cff'),
    core.try_numeric(lr.payload ->> 'shareholder_yield_cff'),
    core.try_numeric(lr.payload ->> 'cf_other_financing_act_excl_fx'),
    core.try_numeric(lr.payload ->> 'cf_cash_from_oper'),
    core.try_numeric(lr.payload ->> 'capital_yield')
from latest_ratios_yield_analysis lr
join core.instrument i
    on i.exchange_code = lr.exchange_code
   and i.ticker = lr.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lr.report_date
   and rp.period_type = lr.period_type;

commit;
