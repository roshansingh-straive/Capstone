/*
Task 5, Query 1: April and May baseline

Purpose: Confirm the total deterioration before segmenting it.
Source grain: one row per transaction from the Task 4 profitability model.
*/

SELECT
    transaction_month,
    COUNT(*) AS payment_attempts,
    SUM(success_flag) AS successful_payments,
    SUM(success_flag) / NULLIF(COUNT(*), 0)::FLOAT AS success_rate,
    SUM(attempted_volume_usd) AS attempted_volume_usd,
    SUM(gross_payment_value_usd) AS gross_payment_value_usd,
    SUM(COALESCE(merchant_fee_revenue_usd, 0)) AS revenue_usd,
    SUM(COALESCE(processing_cost_usd, 0)) AS processing_cost_usd,
    SUM(COALESCE(chargeback_cost_usd, 0)) AS chargeback_cost_usd,
    SUM(COALESCE(observed_contribution_profit_usd, 0))
        AS contribution_profit_usd,
    SUM(COALESCE(observed_contribution_profit_usd, 0))
        / NULLIF(SUM(success_flag), 0)
        AS profit_per_successful_transaction_usd
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY
WHERE transaction_month IN ('2025-04-01'::DATE, '2025-05-01'::DATE)
GROUP BY transaction_month
ORDER BY transaction_month;


/* One-row comparison for the final conclusion. */
WITH monthly AS (
    SELECT
        transaction_month,
        COUNT(*) AS attempts,
        SUM(success_flag) AS successes,
        SUM(COALESCE(observed_contribution_profit_usd, 0)) AS profit_usd
    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY
    WHERE transaction_month IN ('2025-04-01'::DATE, '2025-05-01'::DATE)
    GROUP BY transaction_month
)
SELECT
    MAX(IFF(transaction_month = '2025-04-01'::DATE, attempts, NULL))
        AS april_attempts,
    MAX(IFF(transaction_month = '2025-05-01'::DATE, attempts, NULL))
        AS may_attempts,
    MAX(IFF(transaction_month = '2025-04-01'::DATE, successes, NULL))
        AS april_successes,
    MAX(IFF(transaction_month = '2025-05-01'::DATE, successes, NULL))
        AS may_successes,
    MAX(IFF(transaction_month = '2025-04-01'::DATE, profit_usd, NULL))
        AS april_profit_usd,
    MAX(IFF(transaction_month = '2025-05-01'::DATE, profit_usd, NULL))
        AS may_profit_usd,
    MAX(IFF(transaction_month = '2025-05-01'::DATE, profit_usd, NULL))
      - MAX(IFF(transaction_month = '2025-04-01'::DATE, profit_usd, NULL))
        AS profit_change_usd
FROM monthly;

