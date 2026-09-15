/*
Task 5, Query 2: Segment deterioration across five factors

Factors compared:
1. Payment channel
2. Route provider
3. Merchant category
4. Merchant country
5. Customer segment

The view calculates April profit, May profit and the change for every segment.
A negative profit_change_usd means deterioration.

Important: Segments from different factors overlap. For example, a Retail customer
can also use Web and pay a Singapore merchant. Do not add deterioration values from
different factors together. Use the ranking to identify investigation priorities.
*/

CREATE OR REPLACE VIEW ASTRAPAY_DB.ANALYTICS.V_TASK5_SEGMENT_DETERIORATION AS
WITH base AS (
    SELECT
        p.transaction_id,
        p.transaction_month,
        p.channel,
        COALESCE(p.provider, 'UNKNOWN') AS provider,
        COALESCE(m.category, 'UNKNOWN') AS merchant_category,
        COALESCE(m.country, 'UNKNOWN') AS merchant_country,
        COALESCE(c.segment, 'UNKNOWN') AS customer_segment,
        p.success_flag,
        COALESCE(p.attempted_volume_usd, 0) AS attempted_volume_usd,
        COALESCE(p.merchant_fee_revenue_usd, 0) AS revenue_usd,
        COALESCE(p.processing_cost_usd, 0)
          + COALESCE(p.chargeback_cost_usd, 0) AS total_cost_usd,
        COALESCE(p.observed_contribution_profit_usd, 0) AS profit_usd
    FROM ASTRAPAY_DB.ANALYTICS.V_TASK4_TRUSTED_PROFITABILITY p
    LEFT JOIN ASTRAPAY_DB.RAW.MERCHANT m
        ON p.merchant_id = m.merchant_id
    LEFT JOIN ASTRAPAY_DB.RAW.CUSTOMER c
        ON p.customer_id = c.customer_id
    WHERE p.transaction_month IN ('2025-04-01'::DATE, '2025-05-01'::DATE)
),
segment_rows AS (
    SELECT *, 'CHANNEL' AS factor_name, COALESCE(channel, 'UNKNOWN') AS segment_value
    FROM base

    UNION ALL

    SELECT *, 'PROVIDER' AS factor_name, provider AS segment_value
    FROM base

    UNION ALL

    SELECT *, 'MERCHANT_CATEGORY' AS factor_name, merchant_category AS segment_value
    FROM base

    UNION ALL

    SELECT *, 'MERCHANT_COUNTRY' AS factor_name, merchant_country AS segment_value
    FROM base

    UNION ALL

    SELECT *, 'CUSTOMER_SEGMENT' AS factor_name, customer_segment AS segment_value
    FROM base
),
overall AS (
    SELECT
        SUM(IFF(transaction_month = '2025-04-01'::DATE, profit_usd, 0))
            AS april_total_profit_usd,
        SUM(IFF(transaction_month = '2025-05-01'::DATE, profit_usd, 0))
            AS may_total_profit_usd
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

        SUM(IFF(transaction_month = '2025-04-01'::DATE, success_flag, 0))
            AS april_successes,
        SUM(IFF(transaction_month = '2025-05-01'::DATE, success_flag, 0))
            AS may_successes,

        SUM(IFF(transaction_month = '2025-04-01'::DATE, attempted_volume_usd, 0))
            AS april_attempted_volume_usd,
        SUM(IFF(transaction_month = '2025-05-01'::DATE, attempted_volume_usd, 0))
            AS may_attempted_volume_usd,

        SUM(IFF(transaction_month = '2025-04-01'::DATE, revenue_usd, 0))
            AS april_revenue_usd,
        SUM(IFF(transaction_month = '2025-05-01'::DATE, revenue_usd, 0))
            AS may_revenue_usd,

        SUM(IFF(transaction_month = '2025-04-01'::DATE, total_cost_usd, 0))
            AS april_total_cost_usd,
        SUM(IFF(transaction_month = '2025-05-01'::DATE, total_cost_usd, 0))
            AS may_total_cost_usd,

        SUM(IFF(transaction_month = '2025-04-01'::DATE, profit_usd, 0))
            AS april_profit_usd,
        SUM(IFF(transaction_month = '2025-05-01'::DATE, profit_usd, 0))
            AS may_profit_usd

    FROM segment_rows
    GROUP BY factor_name, segment_value
),
calculated AS (
    SELECT
        s.*,
        s.may_transactions - s.april_transactions AS transaction_change,
        s.may_profit_usd - s.april_profit_usd AS profit_change_usd,

        s.april_profit_usd / NULLIF(s.april_successes, 0)
            AS april_profit_per_success_usd,
        s.may_profit_usd / NULLIF(s.may_successes, 0)
            AS may_profit_per_success_usd,

        100 * (s.april_profit_usd - s.may_profit_usd)
            / NULLIF(o.april_total_profit_usd - o.may_total_profit_usd, 0)
            AS contribution_to_total_deterioration_pct

    FROM segment_summary s
    CROSS JOIN overall o
)
SELECT
    calculated.*,
    ROW_NUMBER() OVER (
        PARTITION BY factor_name
        ORDER BY profit_change_usd, segment_value
    ) AS deterioration_rank_within_factor,
    ROW_NUMBER() OVER (
        ORDER BY profit_change_usd, factor_name, segment_value
    ) AS overall_deterioration_rank
FROM calculated;


/* Full comparison across all five factors. */
SELECT *
FROM ASTRAPAY_DB.ANALYTICS.V_TASK5_SEGMENT_DETERIORATION
ORDER BY factor_name, profit_change_usd;


/* Two worst segment values inside each factor. */
SELECT
    factor_name,
    segment_value,
    april_profit_usd,
    may_profit_usd,
    profit_change_usd,
    contribution_to_total_deterioration_pct,
    deterioration_rank_within_factor
FROM ASTRAPAY_DB.ANALYTICS.V_TASK5_SEGMENT_DETERIORATION
WHERE deterioration_rank_within_factor <= 2
ORDER BY factor_name, deterioration_rank_within_factor;


/* Two worst reducing segment values across all five factors. */
SELECT
    factor_name,
    segment_value,
    april_profit_usd,
    may_profit_usd,
    profit_change_usd,
    contribution_to_total_deterioration_pct
FROM ASTRAPAY_DB.ANALYTICS.V_TASK5_SEGMENT_DETERIORATION
WHERE overall_deterioration_rank <= 2
ORDER BY overall_deterioration_rank;

