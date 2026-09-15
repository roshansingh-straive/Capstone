/*
Task 5, Query 3: Mix effect and within-segment performance effect

This query uses contribution profit per payment attempt as the unit economics.

Profit change is separated into:
- Volume effect: change in the total number of attempts.
- Mix effect: transactions moving between segments.
- Within effect: profit per attempt changing inside the same segment.

The three effects reconcile to the total profit change for each factor.
*/

CREATE OR REPLACE VIEW ASTRAPAY_DB.ANALYTICS.V_TASK5_MIX_WITHIN_EFFECT AS
WITH base AS (
    SELECT
        p.transaction_id,
        p.transaction_month,
        COALESCE(p.channel, 'UNKNOWN') AS channel,
        COALESCE(p.provider, 'UNKNOWN') AS provider,
        COALESCE(m.category, 'UNKNOWN') AS merchant_category,
        COALESCE(m.country, 'UNKNOWN') AS merchant_country,
        COALESCE(c.segment, 'UNKNOWN') AS customer_segment,
        COALESCE(p.observed_contribution_profit_usd, 0) AS profit_usd
    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY p
    LEFT JOIN ASTRAPAY_DB.RAW.MERCHANT m
        ON p.merchant_id = m.merchant_id
    LEFT JOIN ASTRAPAY_DB.RAW.CUSTOMER c
        ON p.customer_id = c.customer_id
    WHERE p.transaction_month IN ('2025-04-01'::DATE, '2025-05-01'::DATE)
),
segment_rows AS (
    SELECT transaction_id, transaction_month, profit_usd,
           'CHANNEL' AS factor_name, channel AS segment_value
    FROM base
    UNION ALL
    SELECT transaction_id, transaction_month, profit_usd,
           'PROVIDER', provider
    FROM base
    UNION ALL
    SELECT transaction_id, transaction_month, profit_usd,
           'MERCHANT_CATEGORY', merchant_category
    FROM base
    UNION ALL
    SELECT transaction_id, transaction_month, profit_usd,
           'MERCHANT_COUNTRY', merchant_country
    FROM base
    UNION ALL
    SELECT transaction_id, transaction_month, profit_usd,
           'CUSTOMER_SEGMENT', customer_segment
    FROM base
),
segment_summary AS (
    SELECT
        factor_name,
        segment_value,
        COUNT_IF(transaction_month = '2025-04-01'::DATE)
            AS april_transactions,
        COUNT_IF(transaction_month = '2025-05-01'::DATE)
            AS may_transactions,
        SUM(IFF(transaction_month = '2025-04-01'::DATE, profit_usd, 0))
            AS april_profit_usd,
        SUM(IFF(transaction_month = '2025-05-01'::DATE, profit_usd, 0))
            AS may_profit_usd
    FROM segment_rows
    GROUP BY factor_name, segment_value
),
with_totals AS (
    SELECT
        s.*,
        SUM(april_transactions) OVER (PARTITION BY factor_name)
            AS april_total_transactions,
        SUM(may_transactions) OVER (PARTITION BY factor_name)
            AS may_total_transactions,
        SUM(april_profit_usd) OVER (PARTITION BY factor_name)
            AS april_total_profit_usd,
        SUM(may_profit_usd) OVER (PARTITION BY factor_name)
            AS may_total_profit_usd
    FROM segment_summary s
),
rates AS (
    SELECT
        *,
        COALESCE(april_transactions / NULLIF(april_total_transactions, 0)::FLOAT, 0)
            AS april_mix_share,
        COALESCE(may_transactions / NULLIF(may_total_transactions, 0)::FLOAT, 0)
            AS may_mix_share,
        COALESCE(april_profit_usd / NULLIF(april_transactions, 0), 0)
            AS april_profit_per_attempt,
        COALESCE(may_profit_usd / NULLIF(may_transactions, 0), 0)
            AS may_profit_per_attempt,
        april_total_profit_usd / NULLIF(april_total_transactions, 0)
            AS april_overall_profit_per_attempt
    FROM with_totals
),
effects AS (
    SELECT
        *,

        (may_total_transactions - april_total_transactions)
          * april_mix_share
          * april_profit_per_attempt
            AS volume_effect_usd,

        may_total_transactions
          * (may_mix_share - april_mix_share)
          * april_profit_per_attempt
            AS mix_effect_usd,

        may_total_transactions
          * may_mix_share
          * (may_profit_per_attempt - april_profit_per_attempt)
            AS within_segment_effect_usd

    FROM rates
)
SELECT
    factor_name,
    segment_value,
    april_transactions,
    may_transactions,
    april_mix_share,
    may_mix_share,
    april_profit_per_attempt,
    may_profit_per_attempt,
    april_profit_usd,
    may_profit_usd,
    may_profit_usd - april_profit_usd AS actual_profit_change_usd,
    volume_effect_usd,
    mix_effect_usd,
    within_segment_effect_usd,
    volume_effect_usd + mix_effect_usd + within_segment_effect_usd
        AS explained_profit_change_usd,
    (volume_effect_usd + mix_effect_usd + within_segment_effect_usd)
      - (may_profit_usd - april_profit_usd)
        AS reconciliation_difference_usd,
    CASE
        WHEN ABS(within_segment_effect_usd) >= ABS(mix_effect_usd)
            THEN 'WITHIN_SEGMENT_PERFORMANCE'
        ELSE 'MIX'
    END AS larger_driver
FROM effects;


/* Segment-level decomposition. */
SELECT *
FROM ASTRAPAY_DB.ANALYTICS.V_TASK5_MIX_WITHIN_EFFECT
ORDER BY factor_name, actual_profit_change_usd;


/* Factor summary. Reconciliation difference should be approximately zero. */
SELECT
    factor_name,
    SUM(actual_profit_change_usd) AS actual_profit_change_usd,
    SUM(volume_effect_usd) AS volume_effect_usd,
    SUM(mix_effect_usd) AS mix_effect_usd,
    SUM(within_segment_effect_usd) AS within_segment_effect_usd,
    SUM(reconciliation_difference_usd) AS reconciliation_difference_usd
FROM ASTRAPAY_DB.ANALYTICS.V_TASK5_MIX_WITHIN_EFFECT
GROUP BY factor_name
ORDER BY factor_name;
