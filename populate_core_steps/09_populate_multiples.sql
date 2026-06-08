begin;

with latest_multiples as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.multiples
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_multiples_id desc
)
insert into core.multiples (
    reporting_period_id,
    average_pe_ratio,
    pe_ratio_high_close_price,
    pe_ratio_low_close_price,
    price_to_book,
    average_price_to_book,
    high_price_to_book,
    low_price_to_book,
    price_to_tangible_book,
    average_price_to_tangible_book,
    high_price_to_tangible_book,
    low_price_to_tangible_book,
    price_to_sales,
    average_price_to_sales,
    high_price_to_sales,
    low_price_to_sales,
    ev_to_ttm_sales,
    average_ev_to_ttm_sales,
    high_ev_to_ttm_sales,
    low_ev_to_ttm_sales,
    average_ev_to_ttm_ebitda,
    high_ev_to_ttm_ebitda,
    low_ev_to_ttm_ebitda,
    average_ev_to_ttm_ebit,
    high_ev_to_ttm_ebit,
    low_ev_to_ttm_ebit,
    last_price,
    high_price,
    low_price,
    enterprise_value,
    average_enterprise_value,
    high_enterprise_value,
    low_enterprise_value,
    shares_outstanding,
    pe_ratio,
    price_to_cash_flow,
    average_price_to_cash_flow,
    high_price_to_cash_flow,
    low_price_to_cash_flow,
    price_to_free_cash_flow,
    average_price_to_free_cash_flow,
    high_price_to_free_cash_flow,
    low_price_to_free_cash_flow
)
select
    rp.reporting_period_id,
    core.try_numeric(lm.payload ->> 'average_price_earnings_ratio'),
    core.try_numeric(lm.payload ->> 'pe_ratio_with_high_clos_pr'),
    core.try_numeric(lm.payload ->> 'pe_ratio_with_low_clos_pr'),
    core.try_numeric(lm.payload ->> 'pr_to_book_ratio'),
    core.try_numeric(lm.payload ->> 'average_price_to_book_ratio'),
    core.try_numeric(lm.payload ->> 'high_closing_price_to_book_ratio'),
    core.try_numeric(lm.payload ->> 'low_closing_price_to_book_ratio'),
    core.try_numeric(lm.payload ->> 'pr_to_tang_bv_per_sh'),
    core.try_numeric(lm.payload ->> 'average_price_to_tangible_bps'),
    core.try_numeric(lm.payload ->> 'high_price_to_tangible_bps'),
    core.try_numeric(lm.payload ->> 'low_price_to_tangible_bps'),
    core.try_numeric(lm.payload ->> 'pr_to_sales_ratio'),
    core.try_numeric(lm.payload ->> 'average_price_to_sales_ratio'),
    core.try_numeric(lm.payload ->> 'high_closing_price_to_sales_ratio'),
    core.try_numeric(lm.payload ->> 'low_closing_price_to_sales_ratio'),
    core.try_numeric(lm.payload ->> 'ev_to_ttm_sales'),
    core.try_numeric(lm.payload ->> 'average_ev_to_ttm_sales'),
    core.try_numeric(lm.payload ->> 'high_ev_to_ttm_sales'),
    core.try_numeric(lm.payload ->> 'low_ev_to_ttm_sales'),
    core.try_numeric(lm.payload ->> 'avg_ev_to_ttm_ebitda'),
    core.try_numeric(lm.payload ->> 'high_ev_to_ttm_ebitda'),
    core.try_numeric(lm.payload ->> 'low_ev_to_ttm_ebitda'),
    core.try_numeric(lm.payload ->> 'average_ev_to_ttm_ebit'),
    core.try_numeric(lm.payload ->> 'high_ev_to_ttm_ebit'),
    core.try_numeric(lm.payload ->> 'low_ev_to_ttm_ebit'),
    core.try_numeric(lm.payload ->> 'pr_last'),
    core.try_numeric(lm.payload ->> 'pr_high'),
    core.try_numeric(lm.payload ->> 'pr_low'),
    core.try_numeric(lm.payload ->> 'enterprise_value'),
    core.try_numeric(lm.payload ->> 'average_enterprise_value'),
    core.try_numeric(lm.payload ->> 'high_enterprise_value'),
    core.try_numeric(lm.payload ->> 'low_enterprise_value'),
    core.try_numeric(lm.payload ->> 'bs_sh_out'),
    core.try_numeric(lm.payload ->> 'pe_ratio'),
    core.try_numeric(lm.payload ->> 'pr_to_cash_flow'),
    core.try_numeric(lm.payload ->> 'average_price_to_cash_flow'),
    core.try_numeric(lm.payload ->> 'high_closing_price_to_cash_flow'),
    core.try_numeric(lm.payload ->> 'low_closing_price_to_cash_flow'),
    core.try_numeric(lm.payload ->> 'pr_to_free_cash_flow'),
    core.try_numeric(lm.payload ->> 'average_price_to_free_cash_flow'),
    core.try_numeric(lm.payload ->> 'high_price_to_free_cash_flow'),
    core.try_numeric(lm.payload ->> 'low_price_to_free_cash_flow')
from latest_multiples lm
join core.instrument i
    on i.exchange_code = lm.exchange_code
   and i.ticker = lm.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lm.report_date
   and rp.period_type = lm.period_type;

commit;
