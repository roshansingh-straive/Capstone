

CREATE OR REPLACE VIEW ASTRAPAY_DB.ANALYTICS.V_TASK4_TRANSACTION_USD AS
WITH fx_mid AS (
    SELECT
        rate_date,
        currency,
        MAX(rate_to_usd) AS rate_to_usd,
        COUNT(*) AS fx_rate_row_count
    FROM ASTRAPAY_DB.RAW.FX_RATE
    WHERE rate_type = 'MID'
    GROUP BY rate_date, currency
)
SELECT
    t.transaction_id,
    t.customer_id,
    t.merchant_id,
    t.route_id,
    t.created_at,
    CAST(t.created_at AS DATE) AS transaction_date,
    DATE_TRUNC('MONTH', t.created_at)::DATE AS transaction_month,
    t.currency,
    t.channel,
    t.status,
    t.amount AS transaction_amount_native,

    1 AS attempt_flag,
    IFF(t.status = 'SUCCESS', 1, 0) AS success_flag,

    CASE
        WHEN t.amount > 0 THEN 'VALID_POSITIVE'
        WHEN t.amount = 0 THEN 'ZERO_AMOUNT'
        WHEN t.amount < 0 AND t.status = 'REVERSED' THEN 'VALID_REVERSAL'
        WHEN t.amount < 0 THEN 'INVALID_NEGATIVE'
        ELSE 'MISSING_AMOUNT'
    END AS amount_quality_flag,

    CASE
        WHEN t.currency = 'USD' THEN 1
        ELSE f.rate_to_usd
    END AS transaction_fx_rate,

    CASE
        WHEN t.currency = 'USD' THEN t.amount
        WHEN f.rate_to_usd IS NOT NULL THEN t.amount * f.rate_to_usd
    END AS transaction_amount_usd,

    CASE
        WHEN t.currency = 'USD' THEN 'FX_AVAILABLE'
        WHEN f.rate_to_usd IS NULL THEN 'MISSING_FX'
        WHEN f.fx_rate_row_count > 1 THEN 'DUPLICATE_MID_FX'
        ELSE 'FX_AVAILABLE'
    END AS transaction_fx_quality_flag

FROM ASTRAPAY_DB.RAW.TRANSACTION_DATA t
LEFT JOIN fx_mid f
    ON t.currency = f.currency
   AND CAST(t.created_at AS DATE) = f.rate_date;


/* Expected grain check: duplicate_transaction_ids should be zero. */
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT transaction_id) AS unique_transaction_count,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_transaction_ids
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRANSACTION_USD;

