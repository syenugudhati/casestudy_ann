SELECT
    *,
    regexp_replace(
        lower(regexp_replace(
            regexp_replace(BN_NAME, '\s+', '', 'g'),
            '(ptyltd|ltd|pl)$', '', 'i'
        )),
        '[^a-z0-9]', '', 'g'
    ) AS search_key
FROM {{ ref('int_business_names_valid') }}