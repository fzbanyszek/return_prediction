begin;

with all_instruments as (
    select distinct exchange_code, ticker
    from raw.company_profile
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.price_daily
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.income_statement
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.balance_sheet
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.cash_flow
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.enterprise_value
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.multiples
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.per_share
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.ratios_credit
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.ratios_liquidity
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.ratios_profitability
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.ratios_working_capital
    where ticker is not null

    union

    select distinct exchange_code, ticker
    from raw.ratios_yield_analysis
    where ticker is not null
),
latest_profile as (
    select distinct on (exchange_code, ticker)
        exchange_code,
        ticker,
        company_name,
        cik,
        cusip,
        isin
    from raw.company_profile
    where ticker is not null
    order by exchange_code, ticker, raw_profile_id desc
)
insert into core.instrument (
    exchange_code,
    ticker,
    company_name,
    cik,
    cusip,
    isin
)
select
    ai.exchange_code,
    ai.ticker,
    lp.company_name,
    lp.cik,
    lp.cusip,
    lp.isin
from all_instruments ai
left join latest_profile lp
    on lp.exchange_code = ai.exchange_code
   and lp.ticker = ai.ticker;

commit;
