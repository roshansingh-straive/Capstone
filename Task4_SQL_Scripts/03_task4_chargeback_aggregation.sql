

CREATE OR REPLACE VIEW ASTRAPAY_DB.ANALYTICS.V_TASK4_CHARGEBACK_BY_TRANSACTION AS
WITH fx_mid AS (
    SELECT
        rate_date,
        currency,
        MAX(rate_to_usd) AS rate_to_usd,
        COUNT(*) AS fx_rate_row_count
    FROM ASTRAPAY_DB.RAW.FX_RATE
    WHERE rate_type = 'MID'
    GROUP BY rate_date, currency
),
chargeback_converted AS (
    SELECT
        c.chargeback_id,
        c.transaction_id,
        c.reason,
        c.amount,
        c.opened_at,
        c.resolved_at,

        CASE
            WHEN c.amount <= 0 THEN NULL
            WHEN t.currency = 'USD' THEN c.amount
            WHEN COALESCE(f.rate_to_usd, t.transaction_fx_rate) IS NOT NULL
                THEN c.amount * COALESCE(f.rate_to_usd, t.transaction_fx_rate)
        END AS chargeback_cost_usd,

        CASE
            WHEN c.amount <= 0 THEN 'INVALID_CHARGEBACK_AMOUNT'
            WHEN t.transaction_id IS NULL THEN 'MISSING_TRANSACTION'
            WHEN t.currency <> 'USD'
                 AND f.rate_to_usd IS NULL
                 AND t.transaction_fx_rate IS NULL THEN 'MISSING_FX'
            WHEN t.currency <> 'USD' AND f.rate_to_usd IS NULL
                THEN 'TRANSACTION_DATE_FX_FALLBACK'
            WHEN COALESCE(f.fx_rate_row_count, 1) > 1 THEN 'DUPLICATE_MID_FX'
            ELSE 'VALID'
        END AS chargeback_quality_flag

    FROM ASTRAPAY_DB.RAW.CHARGEBACK c
    LEFT JOIN ASTRAPAY_DB.ANALYTICS.V_TASK4_TRANSACTION_USD t
        ON c.transaction_id = t.transaction_id
    LEFT JOIN fx_mid f
        ON t.currency = f.currency
       AND CAST(c.opened_at AS DATE) = f.rate_date
)
SELECT
    transaction_id,
    COUNT(*) AS chargeback_record_count,

    COUNT_IF(
        chargeback_quality_flag IN ('VALID', 'TRANSACTION_DATE_FX_FALLBACK')
    ) AS valid_chargeback_count,

    SUM(
        IFF(
            chargeback_quality_flag IN ('VALID', 'TRANSACTION_DATE_FX_FALLBACK'),
            chargeback_cost_usd,
            NULL
        )
    ) AS chargeback_cost_usd,

    SUM(
        IFF(
            UPPER(reason) = 'FRAUD'
            AND chargeback_quality_flag IN ('VALID', 'TRANSACTION_DATE_FX_FALLBACK'),
            chargeback_cost_usd,
            NULL
        )
    ) AS fraud_chargeback_cost_usd,

    COUNT_IF(chargeback_quality_flag = 'INVALID_CHARGEBACK_AMOUNT')
        AS invalid_chargeback_count,

    COUNT_IF(chargeback_quality_flag = 'MISSING_FX')
        AS missing_chargeback_fx_count,

    COUNT_IF(chargeback_quality_flag = 'TRANSACTION_DATE_FX_FALLBACK')
        AS chargeback_fx_fallback_count,

    MIN(opened_at) AS first_chargeback_opened_at,
    MAX(opened_at) AS last_chargeback_opened_at

FROM chargeback_converted
GROUP BY transaction_id;


/* Expected grain check: duplicate_transaction_ids should be zero. */
SELECT
    COUNT(*) AS chargeback_transaction_count,
    COUNT(DISTINCT transaction_id) AS unique_transaction_count,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_transaction_ids
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_CHARGEBACK_BY_TRANSACTION;

