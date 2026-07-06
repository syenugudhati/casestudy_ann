SELECT
    *,
    -- Rule: business registered before 28/05/2012 may have multi-state registrations and no ABNs (not an error)
    -- However, after 28/05/2012, a business must have a valid ABN to be registered. If not, it is flagged for review.
    CASE
        WHEN TRIM(CAST(BN_ABN AS VARCHAR)) IS NULL THEN 0
        WHEN REGEXP_FULL_MATCH(
        REGEXP_REPLACE(TRIM(CAST(BN_ABN AS VARCHAR)), '\.0$', ''),
        '^[0-9]{11}$'
        ) THEN 1
        ELSE 0
    END AS VALID_ABN,
    CASE
        WHEN BN_STATUS = 'Registered' AND VALID_ABN = 0 THEN 1
        ELSE 0
    END AS REGISTERED_NO_VALID_ABN,
    CASE
        WHEN STRPTIME(BN_REG_DT, '%d/%m/%Y') > DATE '2012-05-28' AND BN_STATUS = 'Registered' AND VALID_ABN = 0 THEN 1
        ELSE 0
    END AS REVIEW_FLAG
FROM {{ ref('stg_business_names') }}