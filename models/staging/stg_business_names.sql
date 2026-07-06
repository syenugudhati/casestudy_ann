SELECT
    REGISTER_NAME,
    UPPER(REPLACE(LTRIM(BN_NAME), '"', '')) AS BN_NAME,
    BN_STATUS,
    BN_REG_DT,
    BN_CANCEL_DT,
    BN_STATE_NUM,
    BN_STATE_OF_REG,
    TRIM(CAST(BN_ABN AS VARCHAR)) AS BN_ABN
FROM {{ source('raw', 'raw_business_names') }}