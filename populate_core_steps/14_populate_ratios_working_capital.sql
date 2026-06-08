begin;

with latest_ratios_working_capital as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.ratios_working_capital
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_ratios_working_capital_id desc
)
insert into core.ratios_working_capital (
    reporting_period_id,
    accounts_receivable_turnover,
    accounts_receivable_days,
    cash_conversion_cycle,
    inventory_to_cash_days,
    accounts_payable_turnover,
    accounts_payable_turnover_days,
    inventory_turnover,
    inventory_days,
    inventories,
    other_inventory
)
select
    rp.reporting_period_id,
    core.try_numeric(lr.payload ->> 'acct_rcv_turn'),
    core.try_numeric(lr.payload ->> 'acct_rcv_days'),
    core.try_numeric(lr.payload ->> 'cash_conversion_cycle'),
    core.try_numeric(lr.payload ->> 'inv_to_cash_days'),
    core.try_numeric(lr.payload ->> 'accounts_payable_turnover'),
    core.try_numeric(lr.payload ->> 'accounts_payable_turnover_days'),
    core.try_numeric(lr.payload ->> 'invent_turn'),
    core.try_numeric(lr.payload ->> 'invent_days'),
    core.try_numeric(lr.payload ->> 'bs_inventories'),
    core.try_numeric(lr.payload ->> 'bs_other_inv')
from latest_ratios_working_capital lr
join core.instrument i
    on i.exchange_code = lr.exchange_code
   and i.ticker = lr.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lr.report_date
   and rp.period_type = lr.period_type;

commit;
