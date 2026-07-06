SELECT *
FROM {{ ref('int_business_names_flagged') }}
WHERE REGISTERED_NO_VALID_ABN = 0