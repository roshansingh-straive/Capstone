/*
Task 4, Query 4: Trusted transaction-level profitability model

Final grain: exactly one row per transaction_id.

Contribution profit = settlement fee revenue
                    - payment processing cost
                    - observed chargeback cost

*/

CREATE OR REPLACE VIEW ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY AS
WITH route_one_row AS (
    SELECT
        route_id,
        MAX(provider) AS provider,
        MAX(region) AS route_region,
        MAX(fixed_fee) AS fixed_fee,
        MAX(variable_fee_pct) AS variable_fee_pct,
        COUNT(*) AS route_cost_row_count
    FROM ASTRAPAY_DB.RAW.ROUTE_COST
    GROUP BY route_id
),
transaction_costed AS (
    SELECT
        t.*,
        r.provider,
        r.route_region,
        r.fixed_fee,
        r.variable_fee_pct,
        r.route_cost_row_count,

        CASE
            WHEN r.route_id IS NULL OR t.transaction_amount_usd IS NULL THEN NULL
            ELSE r.fixed_fee
                 + GREATEST(t.transaction_amount_usd, 0) * r.variable_fee_pct
        END AS processing_cost_usd,

        CASE
            WHEN r.route_id IS NULL THEN 'MISSING_ROUTE_COST'
            WHEN r.route_cost_row_count > 1 THEN 'DUPLICATE_ROUTE_COST'
            WHEN t.transaction_amount_usd IS NULL THEN 'MISSING_USD_AMOUNT'
            ELSE 'COST_AVAILABLE'
        END AS processing_cost_quality_flag

    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRANSACTION_USD t
    LEFT JOIN route_one_row r
        ON t.route_id = r.route_id
)
SELECT
    t.transaction_id,
    t.customer_id,
    t.merchant_id,
    t.route_id,
    t.created_at,
    t.transaction_date,
    t.transaction_month,
    t.currency,
    t.channel,
    t.status,
    t.transaction_amount_native,
    t.transaction_fx_rate,
    t.transaction_amount_usd,

    t.attempt_flag,
    t.success_flag,

    CASE
        WHEN t.amount_quality_flag IN ('VALID_POSITIVE', 'VALID_REVERSAL')
            THEN t.transaction_amount_usd
    END AS attempted_volume_usd,

    CASE
        WHEN t.status = 'SUCCESS'
         AND t.amount_quality_flag = 'VALID_POSITIVE'
            THEN t.transaction_amount_usd
    END AS gross_payment_value_usd,

    t.provider,
    t.route_region,
    t.fixed_fee,
    t.variable_fee_pct,
    t.processing_cost_usd,

    s.settlement_record_count,
    s.settled_record_count,
    s.first_settlement_date,
    s.last_settlement_date,
    s.settled_amount_usd,
    s.merchant_fee_revenue_usd,

    COALESCE(c.chargeback_record_count, 0) AS chargeback_record_count,
    COALESCE(c.valid_chargeback_count, 0) AS valid_chargeback_count,
    COALESCE(c.chargeback_cost_usd, 0) AS chargeback_cost_usd,
    COALESCE(c.fraud_chargeback_cost_usd, 0) AS fraud_chargeback_cost_usd,

    CASE
        WHEN t.status = 'SUCCESS'
         AND s.settled_record_count > 0
         AND s.settled_amount_usd IS NOT NULL
            THEN s.settled_amount_usd - t.transaction_amount_usd
    END AS fx_impact_usd,

    COALESCE(s.merchant_fee_revenue_usd, 0)
      - t.processing_cost_usd
      - COALESCE(c.chargeback_cost_usd, 0)
        AS observed_contribution_profit_usd,

    CASE
        WHEN t.transaction_fx_quality_flag <> 'FX_AVAILABLE' THEN NULL
        WHEN t.processing_cost_quality_flag <> 'COST_AVAILABLE' THEN NULL
        WHEN t.status = 'SUCCESS' AND t.amount_quality_flag <> 'VALID_POSITIVE'
            THEN NULL
        WHEN t.status = 'SUCCESS' AND COALESCE(s.settled_record_count, 0) = 0
            THEN NULL
        WHEN COALESCE(s.missing_settlement_fx_count, 0) > 0 THEN NULL
        WHEN COALESCE(s.duplicate_settlement_fx_count, 0) > 0 THEN NULL
        WHEN COALESCE(c.invalid_chargeback_count, 0) > 0 THEN NULL
        WHEN COALESCE(c.missing_chargeback_fx_count, 0) > 0 THEN NULL
        ELSE COALESCE(s.merchant_fee_revenue_usd, 0)
             - t.processing_cost_usd
             - COALESCE(c.chargeback_cost_usd, 0)
    END AS trusted_contribution_profit_usd,

    CASE
        WHEN t.transaction_fx_quality_flag <> 'FX_AVAILABLE'
            THEN 'TRANSACTION_FX_ISSUE'
        WHEN t.processing_cost_quality_flag <> 'COST_AVAILABLE'
            THEN 'PROCESSING_COST_ISSUE'
        WHEN t.status = 'SUCCESS' AND t.amount_quality_flag <> 'VALID_POSITIVE'
            THEN 'INVALID_SUCCESS_AMOUNT'
        WHEN t.status = 'SUCCESS' AND COALESCE(s.settled_record_count, 0) = 0
            THEN 'MISSING_SUCCESS_SETTLEMENT'
        WHEN COALESCE(s.missing_settlement_fx_count, 0) > 0
            THEN 'MISSING_SETTLEMENT_FX'
        WHEN COALESCE(s.duplicate_settlement_fx_count, 0) > 0
            THEN 'DUPLICATE_SETTLEMENT_FX'
        WHEN COALESCE(c.invalid_chargeback_count, 0) > 0
            THEN 'INVALID_CHARGEBACK'
        WHEN COALESCE(c.missing_chargeback_fx_count, 0) > 0
            THEN 'MISSING_CHARGEBACK_FX'
        ELSE 'COMPLETE'
    END AS economics_quality_flag,

    t.amount_quality_flag,
    t.transaction_fx_quality_flag,
    t.processing_cost_quality_flag,
    COALESCE(s.missing_settlement_fx_count, 0) AS missing_settlement_fx_count,
    COALESCE(c.invalid_chargeback_count, 0) AS invalid_chargeback_count,
    COALESCE(c.missing_chargeback_fx_count, 0) AS missing_chargeback_fx_count,
    COALESCE(c.chargeback_fx_fallback_count, 0) AS chargeback_fx_fallback_count

FROM transaction_costed t
LEFT JOIN ASTRAPAY_DB.ANALYTICS.V_TASK4_SETTLEMENT_BY_TRANSACTION s
    ON t.transaction_id = s.transaction_id
LEFT JOIN ASTRAPAY_DB.ANALYTICS.V_TASK4_CHARGEBACK_BY_TRANSACTION c
    ON t.transaction_id = c.transaction_id;


/* Expected result: one row for every transaction and zero duplicates. */
SELECT
    COUNT(*) AS model_row_count,
    COUNT(DISTINCT transaction_id) AS unique_transaction_count,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_transaction_ids
FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY;

