begin;

with latest_balance_sheet as (
    select distinct on (exchange_code, ticker, report_date, period)
        exchange_code,
        ticker,
        report_date,
        lower(period) as period_type,
        payload
    from raw.balance_sheet
    where report_date is not null
      and lower(period) in ('annual', 'quarterly', 'ttm')
    order by exchange_code, ticker, report_date, period, raw_balance_sheet_id desc
)
insert into core.balance_sheet (
    reporting_period_id,
    cash_and_short_term_investments,
    cash_and_near_cash,
    accounts_and_notes_receivable,
    accounts_receivable,
    other_current_assets,
    current_assets,
    net_fixed_assets,
    gross_fixed_assets,
    goodwill,
    disclosed_intangibles,
    other_intangible_assets,
    other_non_current_assets,
    total_non_current_assets,
    total_assets,
    accounts_payable_and_accruals,
    accrued_liabilities,
    short_term_borrowings,
    short_term_debt,
    other_current_liabilities,
    short_term_deferred_revenue,
    current_liabilities,
    long_term_borrowings,
    non_current_liabilities,
    total_liabilities,
    common_equity_and_apic,
    common_stock,
    additional_paid_in_capital,
    treasury_stock_amount,
    retained_earnings,
    other_shareholder_equity,
    equity_before_minority_interest,
    minority_interest,
    total_equity,
    total_liabilities_and_equity,
    shares_outstanding,
    total_capital_leases,
    net_debt,
    net_debt_to_shareholder_equity,
    tangible_common_equity_ratio,
    current_ratio,
    cash_conversion_cycle,
    long_term_investments,
    taxes_payable,
    inventories,
    preferred_equity_and_hybrid_capital
)
select
    rp.reporting_period_id,
    core.try_numeric(lb.payload ->> 'bs_c_and_ce_and_sti_detailed'),
    core.try_numeric(lb.payload ->> 'bs_cash_near_cash_item'),
    core.try_numeric(lb.payload ->> 'bs_acct_note_rcv'),
    core.try_numeric(lb.payload ->> 'bs_accts_rec_excl_notes_rec'),
    core.try_numeric(lb.payload ->> 'bs_other_current_assets_detailed'),
    core.try_numeric(lb.payload ->> 'bs_cur_asset_report'),
    core.try_numeric(lb.payload ->> 'bs_net_fix_asset'),
    core.try_numeric(lb.payload ->> 'bs_gross_fix_asset'),
    core.try_numeric(lb.payload ->> 'bs_goodwill'),
    core.try_numeric(lb.payload ->> 'bs_disclosed_intangibles'),
    core.try_numeric(lb.payload ->> 'bs_other_intangible_assets_detailed'),
    core.try_numeric(lb.payload ->> 'bs_other_noncurrent_assets_detailed'),
    core.try_numeric(lb.payload ->> 'bs_tot_non_cur_asset'),
    core.try_numeric(lb.payload ->> 'bs_tot_asset'),
    core.try_numeric(lb.payload ->> 'bs_acct_payable_and_accruals_detailed'),
    coalesce(
        core.try_numeric(lb.payload ->> 'bs_accrued_liabilities'),
        core.try_numeric(lb.payload ->> 'bs_accrual')
    ),
    core.try_numeric(lb.payload ->> 'bs_st_borrow'),
    core.try_numeric(lb.payload ->> 'bs_short_term_debt_detailed'),
    coalesce(
        core.try_numeric(lb.payload ->> 'bs_other_current_liabs_detailed'),
        core.try_numeric(lb.payload ->> 'bs_other_current_liabs_sub_detailed')
    ),
    core.try_numeric(lb.payload ->> 'bs_st_deferred_revenue'),
    core.try_numeric(lb.payload ->> 'bs_cur_liab'),
    core.try_numeric(lb.payload ->> 'bs_lt_borrow'),
    core.try_numeric(lb.payload ->> 'bs_non_cur_liab'),
    core.try_numeric(lb.payload ->> 'bs_tot_liab'),
    core.try_numeric(lb.payload ->> 'bs_sh_cap_and_apic'),
    core.try_numeric(lb.payload ->> 'bs_common_stock'),
    core.try_numeric(lb.payload ->> 'bs_add_paid_in_cap'),
    core.try_numeric(lb.payload ->> 'bs_amt_of_tsy_stock'),
    core.try_numeric(lb.payload ->> 'bs_pure_retained_earnings'),
    core.try_numeric(lb.payload ->> 'bs_other_ins_res_to_shrhldr_eqy'),
    core.try_numeric(lb.payload ->> 'bs_eqty_bef_minority_int_detailed'),
    core.try_numeric(lb.payload ->> 'bs_minority_noncontrolling_interest'),
    core.try_numeric(lb.payload ->> 'bs_total_equity'),
    core.try_numeric(lb.payload ->> 'bs_tot_liab_and_eqy'),
    core.try_numeric(lb.payload ->> 'bs_sh_out'),
    core.try_numeric(lb.payload ->> 'bs_total_capital_leases'),
    core.try_numeric(lb.payload ->> 'net_debt'),
    core.try_numeric(lb.payload ->> 'net_debt_to_shrhldr_eqty'),
    core.try_numeric(lb.payload ->> 'tce_ratio'),
    core.try_numeric(lb.payload ->> 'cur_ratio'),
    core.try_numeric(lb.payload ->> 'cash_conversion_cycle'),
    coalesce(
        core.try_numeric(lb.payload ->> 'bs_long_term_investments'),
        core.try_numeric(lb.payload ->> 'bs_lt_invest')
    ),
    core.try_numeric(lb.payload ->> 'bs_taxes_payable'),
    core.try_numeric(lb.payload ->> 'bs_inventories'),
    core.try_numeric(lb.payload ->> 'bs_pfd_eqty_and_hybrid_cptl')
from latest_balance_sheet lb
join core.instrument i
    on i.exchange_code = lb.exchange_code
   and i.ticker = lb.ticker
join core.reporting_period rp
    on rp.instrument_id = i.instrument_id
   and rp.report_date = lb.report_date
   and rp.period_type = lb.period_type;

commit;
