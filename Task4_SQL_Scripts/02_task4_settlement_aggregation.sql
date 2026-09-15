

CREATE OR REPLACE VIEW ASTRAPAY_DB.ANALYTICS.V_TASK4_SETTLEMENT_BY_TRANSACTION AS
WITH fx_settlement AS (
    SELECT
        rate_date,
        currency,
        MAX(rate_to_usd) AS rate_to_usd,
        COUNT(*) AS fx_rate_row_count
    FROM ASTRAPAY_DB.RAW.FX_RATE
    WHERE rate_type = 'SETTLEMENT'
    GROUP BY rate_date, currency
),
settlement_converted AS (
    SELECT
        s.transaction_id,
        s.settlement_status,
        s.settlement_date,
        s.settlement_currency,

        CASE
            WHEN s.settlement_currency = 'USD' THEN s.settlement_amount
            WHEN f.rate_to_usd IS NOT NULL
                THEN s.settlement_amount * f.rate_to_usd
        END AS settlement_amount_usd,

        CASE
            WHEN s.settlement_currency = 'USD' THEN s.fee_amount
            WHEN f.rate_to_usd IS NOT NULL
                THEN s.fee_amount * f.rate_to_usd
        END AS merchant_fee_revenue_usd,

        CASE
            WHEN s.settlement_currency = 'USD' THEN 'FX_AVAILABLE'
            WHEN f.rate_to_usd IS NULL THEN 'MISSING_FX'
            WHEN f.fx_rate_row_count > 1 THEN 'DUPLICATE_SETTLEMENT_FX'
            ELSE 'FX_AVAILABLE'
        END AS settlement_fx_quality_flag

    FROM ASTRAPAY_DB.RAW.SETTLEMENT s
    LEFT JOIN fx_settlement f
        ON s.settlement_currency = f.currency
       AND s.settlement_date = f.rate_date
)
SELECT
    transaction_id,
    COUNT(*) AS settlement_record_count,
    COUNT_IF(settlement_status = 'SETTLED') AS settled_record_count,
    MIN(settlement_date) AS first_settlement_date,
    MAX(settlement_date) AS last_settlement_date,

    SUM(
        IFF(settlement_status = 'SETTLED', settlement_amount_usd, NULL)
    ) AS settled_amount_usd,

    SUM(
        IFF(settlement_status = 'SETTLED', merchant_fee_revenue_usd, NULL)
    ) AS merchant_fee_revenue_usd,

    COUNT_IF(settlement_fx_quality_flag = 'MISSING_FX')
        AS missing_settlement_fx_count,

    COUNT_IF(settlement_fx_quality_flag = 'DUPLICATE_SETTLEMENT_FX')
        AS duplicate_settlement_fx_count

FROM settlement_converted
GROUP BY transaction_id;


/* Expected grain check: duplicate_transaction_ids should be zero. */
SELECT
    COUNT(*) AS settlement_transaction_count,
    COUNT(DISTINCT transaction_id) AS unique_transaction_count,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_transaction_ids
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_SETTLEMENT_BY_TRANSACTION;

