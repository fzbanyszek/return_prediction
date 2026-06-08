begin;

with latest_per_share as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.per_share
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_per_share_id desc
)
insert into core.per_share (
    reporting_period_id,
    shares_outstanding,
    diluted_shares,
    average_shares_basic,
    revenue_per_share,
    ebitda_per_share,
    operating_income_per_share,
    eps,
    eps_continuing_operations,
    diluted_eps,
    diluted_eps_continuing_operations,
    cash_and_short_term_investments_per_share,
    book_value_per_share,
    tangible_book_value_per_share,
    cash_flow_per_share,
    free_cash_flow_per_share
)
select
    rp.reporting_period_id,
    core.try_numeric(lp.payload ->> 'bs_sh_out'),
    core.try_numeric(lp.payload ->> 'is_sh_for_diluted_eps'),
    core.try_numeric(lp.payload ->> 'is_avg_num_sh_for_eps'),
    core.try_numeric(lp.payload ->> 'revenue_per_sh'),
    core.try_numeric(lp.payload ->> 'ebitda_per_sh'),
    core.try_numeric(lp.payload ->> 'oper_inc_per_sh'),
    core.try_numeric(lp.payload ->> 'eps'),
    core.try_numeric(lp.payload ->> 'eps_cont_ops'),
    core.try_numeric(lp.payload ->> 'diluted_eps'),
    core.try_numeric(lp.payload ->> 'dil_eps_cont_ops'),
    core.try_numeric(lp.payload ->> 'cash_st_investments_per_sh'),
    core.try_numeric(lp.payload ->> 'book_val_per_sh'),
    core.try_numeric(lp.payload ->> 'tang_book_val_per_sh'),
    core.try_numeric(lp.payload ->> 'cash_flow_per_sh'),
    core.try_numeric(lp.payload ->> 'free_cash_flow_per_sh')
from latest_per_share lp
join core.instrument i
    on i.exchange_code = lp.exchange_code
   and i.ticker = lp.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lp.report_date
   and rp.period_type = lp.period_type;

commit;
