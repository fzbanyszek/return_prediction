begin;

with latest_cash_flow as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.cash_flow
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_cash_flow_id desc
)
insert into core.cash_flow (
    reporting_period_id,
    ebitda,
    ebitda_margin,
    free_cash_flow_firm,
    price_to_free_cash_flow,
    non_cash_items,
    other_non_cash_adjustments,
    cash_from_operations,
    other_investing_activities,
    cash_from_investing_activities,
    other_financing_activities,
    cash_from_financing_activities,
    net_change_in_cash,
    free_cash_flow,
    free_cash_flow_equity,
    cash_flow_to_net_income,
    free_cash_flow_per_share
)
select
    rp.reporting_period_id,
    core.try_numeric(lc.payload ->> 'ebitda'),
    core.try_numeric(lc.payload ->> 'ebitda_margin'),
    core.try_numeric(lc.payload ->> 'cf_free_cash_flow_firm'),
    core.try_numeric(lc.payload ->> 'pr_to_free_cash_flow'),
    core.try_numeric(lc.payload ->> 'cf_non_cash_items_detailed'),
    core.try_numeric(lc.payload ->> 'cf_other_non_cash_adj_less_detailed'),
    core.try_numeric(lc.payload ->> 'cf_cash_from_oper'),
    core.try_numeric(lc.payload ->> 'cf_other_investing_act_detailed'),
    core.try_numeric(lc.payload ->> 'cf_cash_from_inv_act'),
    core.try_numeric(lc.payload ->> 'cf_other_financing_act_excl_fx'),
    core.try_numeric(lc.payload ->> 'cf_cash_from_fin_act'),
    core.try_numeric(lc.payload ->> 'cf_net_chng_cash'),
    core.try_numeric(lc.payload ->> 'cf_free_cash_flow'),
    core.try_numeric(lc.payload ->> 'free_cash_flow_equity'),
    core.try_numeric(lc.payload ->> 'cash_flow_to_net_inc'),
    core.try_numeric(lc.payload ->> 'free_cash_flow_per_sh')
from latest_cash_flow lc
join core.instrument i
    on i.exchange_code = lc.exchange_code
   and i.ticker = lc.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lc.report_date
   and rp.period_type = lc.period_type;

commit;
