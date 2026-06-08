begin;

with latest_ratios_profitability as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.ratios_profitability
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_ratios_profitability_id desc
)
insert into core.ratios_profitability (
    reporting_period_id,
    return_on_assets,
    gross_margin,
    ebitda_margin,
    operating_margin,
    pretax_income_to_sales,
    profit_margin,
    net_income_to_common_margin,
    return_on_capital,
    incremental_operating_margin,
    effective_tax_rate,
    return_on_common_equity,
    sustainable_growth_rate,
    return_on_invested_capital
)
select
    rp.reporting_period_id,
    core.try_numeric(lr.payload ->> 'return_on_asset'),
    core.try_numeric(lr.payload ->> 'gross_margin'),
    core.try_numeric(lr.payload ->> 'ebitda_margin'),
    core.try_numeric(lr.payload ->> 'oper_margin'),
    core.try_numeric(lr.payload ->> 'pretax_inc_to_net_sales'),
    core.try_numeric(lr.payload ->> 'profit_margin'),
    core.try_numeric(lr.payload ->> 'net_income_to_common_margin'),
    core.try_numeric(lr.payload ->> 'return_on_cap'),
    core.try_numeric(lr.payload ->> 'incremental_operating_margin'),
    core.try_numeric(lr.payload ->> 'eff_tax_rate'),
    core.try_numeric(lr.payload ->> 'return_com_eqy'),
    core.try_numeric(lr.payload ->> 'sustain_growth_rt'),
    core.try_numeric(lr.payload ->> 'return_on_inv_capital')
from latest_ratios_profitability lr
join core.instrument i
    on i.exchange_code = lr.exchange_code
   and i.ticker = lr.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lr.report_date
   and rp.period_type = lr.period_type;

commit;
