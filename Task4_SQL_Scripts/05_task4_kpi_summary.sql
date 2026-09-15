/*
Task 4, Query 5: Executive profitability measures

Date basis: transaction month.
Profit per successful transaction is a ratio of totals. It is not an average of
transaction-level profit ratios.
*/

SELECT
    transaction_month,

    SUM(attempt_flag) AS payment_attempts,
    SUM(success_flag) AS successful_payments,

    SUM(success_flag) / NULLIF(SUM(attempt_flag), 0)::FLOAT
        AS success_rate,

    SUM(attempted_volume_usd) AS attempted_volume_usd,
    SUM(gross_payment_value_usd) AS gross_payment_value_usd,

    SUM(processing_cost_usd) AS processing_cost_usd,
    SUM(fraud_chargeback_cost_usd) AS fraud_cost_usd,
    SUM(chargeback_cost_usd) AS total_chargeback_cost_usd,
    SUM(fx_impact_usd) AS settlement_fx_impact_usd,
    SUM(merchant_fee_revenue_usd) AS merchant_fee_revenue_usd,

    SUM(observed_contribution_profit_usd)
        AS observed_contribution_profit_usd,

    SUM(trusted_contribution_profit_usd)
        AS trusted_contribution_profit_usd,

    SUM(observed_contribution_profit_usd)
        / NULLIF(SUM(success_flag), 0)
        AS contribution_profit_per_successful_transaction,

    COUNT_IF(economics_quality_flag = 'COMPLETE')
        AS trusted_transaction_count,

    COUNT_IF(economics_quality_flag <> 'COMPLETE')
        AS excluded_or_flagged_transaction_count

FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY
GROUP BY transaction_month
ORDER BY transaction_month;


/* Overall Task 4 KPI result. */
SELECT
    SUM(attempt_flag) AS payment_attempts,
    SUM(success_flag) AS successful_payments,
    SUM(success_flag) / NULLIF(SUM(attempt_flag), 0)::FLOAT AS success_rate,
    SUM(attempted_volume_usd) AS attempted_volume_usd,
    SUM(gross_payment_value_usd) AS gross_payment_value_usd,
    SUM(processing_cost_usd) AS processing_cost_usd,
    SUM(fraud_chargeback_cost_usd) AS fraud_cost_usd,
    SUM(chargeback_cost_usd) AS total_chargeback_cost_usd,
    SUM(fx_impact_usd) AS settlement_fx_impact_usd,
    SUM(merchant_fee_revenue_usd) AS merchant_fee_revenue_usd,
    SUM(observed_contribution_profit_usd) AS contribution_profit_usd,
    SUM(observed_contribution_profit_usd)
        / NULLIF(SUM(success_flag), 0)
        AS contribution_profit_per_successful_transaction
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY;

