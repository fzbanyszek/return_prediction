begin;

with latest_price as (
    select distinct on (exchange_code, ticker, trade_date)
        exchange_code,
        ticker,
        trade_date,
        open,
        high,
        low,
        close,
        adj_close,
        volume,
        unadjusted_volume,
        change,
        change_percent,
        vwap,
        label
    from raw.price_daily
    where trade_date is not null
    order by exchange_code, ticker, trade_date, raw_price_id desc
)
insert into core.price_daily (
    instrument_id,
    trade_date,
    open,
    high,
    low,
    close,
    adj_close,
    volume,
    unadjusted_volume,
    change_amount,
    change_percent,
    vwap,
    label
)
select
    i.instrument_id,
    lp.trade_date,
    lp.open,
    lp.high,
    lp.low,
    lp.close,
    lp.adj_close,
    lp.volume,
    lp.unadjusted_volume,
    lp.change,
    lp.change_percent,
    lp.vwap,
    lp.label
from latest_price lp
join core.instrument i
    on i.exchange_code = lp.exchange_code
   and i.ticker = lp.ticker;

commit;
