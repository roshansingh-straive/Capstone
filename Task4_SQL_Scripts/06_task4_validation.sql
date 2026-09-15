/*
Task 4, Query 6: Validation and reconciliation


*/


/* Check 1: Final model grain. Duplicate count must be zero. */
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT transaction_id) AS unique_transaction_count,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_count
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY;


/* Check 2: Prove the safe model does not inflate transaction amount. */
WITH base AS (
    SELECT SUM(transaction_amount_usd) AS base_amount_usd
    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRANSACTION_USD
),
naive_settlement_join AS (
    SELECT SUM(t.transaction_amount_usd) AS naive_join_amount_usd
    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRANSACTION_USD t
    LEFT JOIN ASTRAPAY_DB.RAW.SETTLEMENT s
        ON t.transaction_id = s.transaction_id
),
safe_model AS (
    SELECT SUM(transaction_amount_usd) AS safe_model_amount_usd
    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY
)
SELECT
    b.base_amount_usd,
    n.naive_join_amount_usd,
    s.safe_model_amount_usd,
    n.naive_join_amount_usd - b.base_amount_usd
        AS inflation_from_naive_join_usd,
    s.safe_model_amount_usd - b.base_amount_usd
        AS safe_model_difference_usd
FROM base b
CROSS JOIN naive_settlement_join n
CROSS JOIN safe_model s;


/* Check 3: Settlement fees reconcile before and after aggregation. */
WITH fx_settlement AS (
    SELECT
        rate_date,
        currency,
        MAX(rate_to_usd) AS rate_to_usd
    FROM ASTRAPAY_DB.RAW.FX_RATE
    WHERE rate_type = 'SETTLEMENT'
    GROUP BY rate_date, currency
),
raw_converted AS (
    SELECT
        SUM(
            CASE
                WHEN s.settlement_status <> 'SETTLED' THEN 0
                WHEN s.settlement_currency = 'USD' THEN s.fee_amount
                WHEN f.rate_to_usd IS NOT NULL THEN s.fee_amount * f.rate_to_usd
            END
        ) AS raw_settled_fee_usd
    FROM ASTRAPAY_DB.RAW.SETTLEMENT s
    LEFT JOIN fx_settlement f
        ON s.settlement_currency = f.currency
       AND s.settlement_date = f.rate_date
),
aggregated AS (
    SELECT SUM(merchant_fee_revenue_usd) AS aggregated_settled_fee_usd
    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_SETTLEMENT_BY_TRANSACTION
)
SELECT
    r.raw_settled_fee_usd,
    a.aggregated_settled_fee_usd,
    a.aggregated_settled_fee_usd - r.raw_settled_fee_usd
        AS difference_usd
FROM raw_converted r
CROSS JOIN aggregated a;


/* Check 4: Show settlement coverage without treating it as one-to-one. */
SELECT
    COUNT_IF(status = 'SUCCESS') AS successful_transactions,
    COUNT_IF(status = 'SUCCESS' AND COALESCE(settled_record_count, 0) > 0)
        AS successful_transactions_with_settlement,
    COUNT_IF(status = 'SUCCESS' AND COALESCE(settled_record_count, 0) = 0)
        AS successful_transactions_without_settlement,
    COUNT_IF(COALESCE(settlement_record_count, 0) > 1)
        AS transactions_with_multiple_settlements
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY;


/* Check 5: Explain why records are excluded from trusted profit. */
SELECT
    economics_quality_flag,
    COUNT(*) AS transaction_count,
    SUM(observed_contribution_profit_usd) AS observed_profit_usd
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY
GROUP BY economics_quality_flag
ORDER BY transaction_count DESC;

