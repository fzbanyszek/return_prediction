begin;

with latest_ratios_credit as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.ratios_credit
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_ratios_credit_id desc
)
insert into core.ratios_credit (
    reporting_period_id,
    short_and_long_term_debt,
    short_term_borrowings,
    long_term_borrowings,
    total_debt_to_ebitda,
    net_debt_to_ebitda,
    total_debt_to_ebit,
    net_debt_to_ebit,
    common_equity_to_total_assets,
    long_term_debt_to_total_equity,
    long_term_debt_to_total_capital,
    long_term_debt_to_total_assets,
    total_debt_to_total_equity,
    total_debt_to_total_capital,
    total_debt_to_total_assets,
    net_debt_to_shareholder_equity,
    net_debt_to_capital,
    ebitda,
    ebitda_after_capex,
    operating_income,
    ebitda_to_interest_expense,
    ebitda_minus_capex_to_interest_expense,
    operating_income_to_interest_expense,
    interest_expense
)
select
    rp.reporting_period_id,
    core.try_numeric(lr.payload ->> 'short_and_long_term_debt'),
    core.try_numeric(lr.payload ->> 'bs_st_borrow'),
    core.try_numeric(lr.payload ->> 'bs_lt_borrow'),
    core.try_numeric(lr.payload ->> 'tot_debt_to_ebitda'),
    core.try_numeric(lr.payload ->> 'net_debt_to_ebitda'),
    core.try_numeric(lr.payload ->> 'total_debt_to_ebit'),
    core.try_numeric(lr.payload ->> 'net_debt_to_ebit'),
    core.try_numeric(lr.payload ->> 'com_eqy_to_tot_asset'),
    core.try_numeric(lr.payload ->> 'lt_debt_to_tot_eqy'),
    core.try_numeric(lr.payload ->> 'lt_debt_to_tot_cap'),
    core.try_numeric(lr.payload ->> 'lt_debt_to_tot_asset'),
    core.try_numeric(lr.payload ->> 'tot_debt_to_tot_eqy'),
    core.try_numeric(lr.payload ->> 'tot_debt_to_tot_cap'),
    core.try_numeric(lr.payload ->> 'tot_debt_to_tot_asset'),
    core.try_numeric(lr.payload ->> 'net_debt_to_shrhldr_eqty'),
    core.try_numeric(lr.payload ->> 'net_debt_to_capital'),
    core.try_numeric(lr.payload ->> 'ebitda'),
    core.try_numeric(lr.payload ->> 'ebitda_after_capex'),
    core.try_numeric(lr.payload ->> 'is_oper_income'),
    core.try_numeric(lr.payload ->> 'ebitda_to_interest_expn'),
    core.try_numeric(lr.payload ->> 'ebitda_les_cap_expend_to_int_exp'),
    core.try_numeric(lr.payload ->> 'oper_inc_to_int_exp'),
    core.try_numeric(lr.payload ->> 'is_int_expense')
from latest_ratios_credit lr
join core.instrument i
    on i.exchange_code = lr.exchange_code
   and i.ticker = lr.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lr.report_date
   and rp.period_type = lr.period_type;

commit;
