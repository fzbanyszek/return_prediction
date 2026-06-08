begin;

with latest_income_statement as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.income_statement
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_income_statement_id desc
)
insert into core.income_statement (
    reporting_period_id,
    revenue,
    sales_and_services_revenue,
    cost_of_goods_sold,
    cost_of_goods_and_services_sold,
    gross_profit,
    operating_expenses,
    selling_general_and_admin_expense,
    research_and_development_expense,
    other_operating_expenses,
    operating_income,
    non_operating_income_loss,
    other_non_operating_income_loss,
    pretax_income,
    income_tax_expense,
    net_income,
    earnings_for_common,
    average_shares_basic,
    eps,
    eps_continuing_operations,
    shares_for_diluted_eps,
    diluted_eps,
    diluted_eps_continuing_operations,
    ebitda,
    ebitda_margin,
    ebita,
    ebit,
    gross_margin,
    operating_margin,
    profit_margin,
    net_interest_expense,
    interest_income,
    interest_expense,
    dividends_per_share,
    depreciation_expense,
    discontinued_operations,
    extraordinary_items_and_accounting_changes,
    other_operating_income
)
select
    rp.reporting_period_id,
    core.try_numeric(li.payload ->> 'is_sales_revenue_turnover'),
    core.try_numeric(li.payload ->> 'is_sales_and_services_revenues'),
    core.try_numeric(li.payload ->> 'is_cogs'),
    core.try_numeric(li.payload ->> 'is_cog_and_services_sold'),
    core.try_numeric(li.payload ->> 'is_gross_profit'),
    core.try_numeric(li.payload ->> 'is_operating_expn'),
    core.try_numeric(li.payload ->> 'is_sg_and_a_expense'),
    core.try_numeric(li.payload ->> 'is_operating_expenses_r_and_d'),
    core.try_numeric(li.payload ->> 'is_other_operating_expenses'),
    core.try_numeric(li.payload ->> 'is_oper_income'),
    core.try_numeric(li.payload ->> 'is_nonop_income_loss'),
    core.try_numeric(li.payload ->> 'is_other_nonop_income_loss'),
    core.try_numeric(li.payload ->> 'is_pretax_income'),
    core.try_numeric(li.payload ->> 'is_inc_tax_exp'),
    core.try_numeric(li.payload ->> 'is_net_income'),
    core.try_numeric(li.payload ->> 'is_earn_for_common'),
    core.try_numeric(li.payload ->> 'is_avg_num_sh_for_eps'),
    core.try_numeric(li.payload ->> 'eps'),
    core.try_numeric(li.payload ->> 'eps_cont_ops'),
    core.try_numeric(li.payload ->> 'is_sh_for_diluted_eps'),
    core.try_numeric(li.payload ->> 'diluted_eps'),
    core.try_numeric(li.payload ->> 'dil_eps_cont_ops'),
    core.try_numeric(li.payload ->> 'ebitda'),
    core.try_numeric(li.payload ->> 'ebitda_margin'),
    core.try_numeric(li.payload ->> 'ebita'),
    core.try_numeric(li.payload ->> 'ebit'),
    core.try_numeric(li.payload ->> 'gross_margin'),
    core.try_numeric(li.payload ->> 'oper_margin'),
    core.try_numeric(li.payload ->> 'profit_margin'),
    core.try_numeric(li.payload ->> 'is_net_interest_expense'),
    core.try_numeric(li.payload ->> 'is_int_income'),
    core.try_numeric(li.payload ->> 'is_int_expense'),
    core.try_numeric(li.payload ->> 'div_per_shr'),
    core.try_numeric(li.payload ->> 'is_depr_exp'),
    core.try_numeric(li.payload ->> 'is_discontinued_operations'),
    core.try_numeric(li.payload ->> 'is_extraord_items_and_acctg_chng'),
    core.try_numeric(li.payload ->> 'is_other_oper_income')
from latest_income_statement li
join core.instrument i
    on i.exchange_code = li.exchange_code
   and i.ticker = li.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = li.report_date
   and rp.period_type = li.period_type;

commit;
