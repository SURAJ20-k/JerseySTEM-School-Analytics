
-- JerseySTEM DATA101 2 - Data Cleanup
-- Original raw tables must remain unchanged.

USE crm_assessment;

-- Create a fresh working copy of School_raw.
-- Only School_work is recreated when this runs.

DROP TABLE IF EXISTS School_work;

CREATE TABLE School_work LIKE School_raw;

INSERT INTO School_work
SELECT * FROM School_raw;

-- Confirm both tables have the same row count.
SELECT
    (SELECT COUNT(*) FROM School_raw) AS Original_Rows,
    (SELECT COUNT(*) FROM School_work) AS Working_Rows;

    -- Verify School working table

SELECT
    (SELECT COUNT(*) FROM crm_assessment.School_raw) AS Original_Rows,
    (SELECT COUNT(*) FROM crm_assessment.School_work) AS Working_Rows;




-- CLEANUP 1: Standardize School Types
-- Valid values: Public, Charter, Private, Magnet
-- Missing values become NULL (unknown).
-- Original School_raw remains unchanged.

UPDATE crm_assessment.School_work
SET School_Type = CASE
    WHEN School_Type IS NULL
         OR TRIM(School_Type) = ''
        THEN NULL

    WHEN LOWER(TRIM(School_Type)) = 'public'
        THEN 'Public'

    WHEN LOWER(TRIM(School_Type)) = 'charter'
        THEN 'Charter'

    WHEN LOWER(TRIM(School_Type)) = 'private'
        THEN 'Private'

    WHEN LOWER(TRIM(School_Type)) = 'magnet'
        THEN 'Magnet'

    ELSE School_Type
END
WHERE Raw_Row_Id > 0
  AND (
      School_Type IS NULL
      OR TRIM(School_Type) = ''
      OR BINARY School_Type NOT IN
         ('Public', 'Charter', 'Private', 'Magnet')
  );


-- Verify School_Type cleanup

SELECT
    COALESCE(School_Type, '(Missing)') AS School_Type,
    COUNT(*) AS School_Count
FROM crm_assessment.School_work
GROUP BY COALESCE(School_Type, '(Missing)')
ORDER BY School_Type;



-- CLEANUP 2: Standardize Partnership Status
-- Valid values: Active, Prospect, Alumni
-- Only update School_work, not School_raw.

UPDATE crm_assessment.School_work
SET Partnership_Status = CASE
    WHEN LOWER(TRIM(Partnership_Status)) = 'active'
        THEN 'Active'
    WHEN LOWER(TRIM(Partnership_Status)) = 'prospect'
        THEN 'Prospect'
    WHEN LOWER(TRIM(Partnership_Status)) = 'alumni'
        THEN 'Alumni'
    ELSE Partnership_Status
END
WHERE LOWER(TRIM(Partnership_Status))
      IN ('active', 'prospect', 'alumni')
  AND BINARY Partnership_Status NOT IN
      ('Active', 'Prospect', 'Alumni');


-- Verify Partnership Status cleanup

SELECT
    School_Id,
    Partnership_Status
FROM crm_assessment.School_work
WHERE School_Id IN (
    'SCH-0005',
    'SCH-0009',
    'SCH-0014'
)
ORDER BY School_Id;



-- CLEANUP 3: Restore Missing Leading Zeros in ZIP Codes
-- The affected records are in NJ and MA.
-- Assumption: four-digit ZIP codes lost their leading zero.
-- Original School_raw remains unchanged.

UPDATE crm_assessment.School_work
SET Zip = LPAD(TRIM(Zip), 5, '0')
WHERE Raw_Row_Id > 0
  AND TRIM(Zip) REGEXP '^[0-9]{4}$'
  AND State IN ('NJ', 'MA');


-- Verify ZIP code corrections

SELECT
    r.School_Id,
    r.Zip AS Original_Zip,
    w.Zip AS Cleaned_Zip
FROM crm_assessment.School_raw r
JOIN crm_assessment.School_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE TRIM(r.Zip) REGEXP '^[0-9]{4}$'
ORDER BY r.School_Id;



-- CLEANUP 4: Inspect Remaining Invalid ZIP Codes
-- Identify missing or malformed ZIP codes
-- after restoring the leading zeros.

SELECT
    School_Id,
    School_Name,
    State,
    Zip
FROM crm_assessment.School_work
WHERE Zip IS NULL
   OR TRIM(Zip) = ''
   OR TRIM(Zip) NOT REGEXP
      '^[0-9]{5}(-[0-9]{4})?$'
ORDER BY School_Id;


-- CLEANUP 4: Handle Missing or Invalid ZIP Codes
-- Decision: Use NULL when the correct ZIP cannot
-- be determined from the available data.
-- Original values remain in School_raw.

UPDATE crm_assessment.School_work
SET Zip = NULL
WHERE School_Id IN ('SCH-0045', 'SCH-0049')
  AND (
      Zip IS NULL
      OR TRIM(Zip) = ''
      OR TRIM(Zip) NOT REGEXP
         '^[0-9]{5}(-[0-9]{4})?$'
  );


-- Verify remaining ZIP code cleanup

SELECT
    r.School_Id,
    r.Zip AS Original_Zip,
    w.Zip AS Cleaned_Zip
FROM crm_assessment.School_raw r
JOIN crm_assessment.School_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE r.School_Id IN ('SCH-0045', 'SCH-0049')
ORDER BY r.School_Id;



-- CLEANUP 5: Invalid School Enrollment
-- Business rule: Enrollment must be positive.
-- Decision: Set invalid values to NULL (unknown).
-- Preserve original values in School_raw.

UPDATE crm_assessment.School_work
SET Enrollment = NULL
WHERE School_Id IN ('SCH-0047', 'SCH-0050')
  AND TRIM(Enrollment) IN ('0', '-10');


-- Verify invalid enrollment cleanup

SELECT
    r.School_Id,
    r.School_Name,
    r.Enrollment AS Original_Enrollment,
    w.Enrollment AS Cleaned_Enrollment
FROM crm_assessment.School_raw r
JOIN crm_assessment.School_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE r.School_Id IN ('SCH-0047', 'SCH-0050')
ORDER BY r.School_Id;



-- CLEANUP 6: Create Contact Working Table
-- Preserve Contact_raw as the original dataset.

DROP TABLE IF EXISTS crm_assessment.Contact_work;

CREATE TABLE crm_assessment.Contact_work
LIKE crm_assessment.Contact_raw;

INSERT INTO crm_assessment.Contact_work
SELECT * FROM crm_assessment.Contact_raw;

-- Verify working copy
SELECT
    (SELECT COUNT(*)
     FROM crm_assessment.Contact_raw) AS Original_Rows,

    (SELECT COUNT(*)
     FROM crm_assessment.Contact_work) AS Working_Rows;



-- CLEANUP 7: Standardize Contact Email Addresses
-- 1. Remove surrounding whitespace.
-- 2. Convert valid emails to lowercase.
-- 3. Set invalid or blank emails to NULL.
-- 4. Preserve original data in Contact_raw.

UPDATE crm_assessment.Contact_work
SET Email = CASE
    WHEN Email IS NULL
         OR TRIM(Email) = ''
        THEN NULL

    WHEN NOT REGEXP_LIKE(
        TRIM(Email),
        '^[[:alnum:]_.%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}$',
        'c'
    )
        THEN NULL

    ELSE LOWER(TRIM(Email))
END
WHERE Raw_Row_Id > 0;



-- Verify Contact Email Cleanup

SELECT
    r.Contact_Id,
    r.Email AS Original_Email,
    COALESCE(w.Email, '(NULL)') AS Cleaned_Email
FROM crm_assessment.Contact_raw r
JOIN crm_assessment.Contact_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE r.Contact_Id IN (
    'CON-0008',
    'CON-0016',
    'CON-0077',
    'CON-0090'
)
ORDER BY r.Contact_Id;



-- CLEANUP 8: Investigate Duplicate Contact Emails
-- Inspection only: Do not delete records yet.
-- Check identities, primary flags, and club references.

SELECT
    c.Contact_Id,
    c.School_Id,
    c.First_Name,
    c.Last_Name,
    c.Email,
    c.Phone,
    c.Is_Primary_Contact,
    (
        SELECT COUNT(*)
        FROM crm_assessment.Club_raw b
        WHERE TRIM(b.Primary_Contact_Id) = TRIM(c.Contact_Id)
    ) AS Clubs_Referencing_Contact

FROM crm_assessment.Contact_work c

JOIN (
    SELECT LOWER(TRIM(Email)) AS Normalized_Email
    FROM crm_assessment.Contact_work
    WHERE Email IS NOT NULL
      AND TRIM(Email) <> ''
    GROUP BY LOWER(TRIM(Email))
    HAVING COUNT(*) > 1
) d
    ON LOWER(TRIM(c.Email)) = d.Normalized_Email

ORDER BY c.Email, c.Contact_Id;


-- CLEANUP 8B: Investigate Duplicate Contact References
-- Compare primary contact flags and club relationships.
-- Inspection only: No records are modified.

SELECT
    a.Contact_Id AS Contact_1,
    b.Contact_Id AS Contact_2,
    a.Email,
    a.Phone AS Phone_1,
    b.Phone AS Phone_2,
    a.Is_Primary_Contact AS Primary_1,
    b.Is_Primary_Contact AS Primary_2,

    (SELECT COUNT(*)
     FROM crm_assessment.Club_raw cl
     WHERE TRIM(cl.Primary_Contact_Id) =
           TRIM(a.Contact_Id)
    ) AS Clubs_Using_1,

    (SELECT COUNT(*)
     FROM crm_assessment.Club_raw cl
     WHERE TRIM(cl.Primary_Contact_Id) =
           TRIM(b.Contact_Id)
    ) AS Clubs_Using_2

FROM crm_assessment.Contact_work a

JOIN crm_assessment.Contact_work b
    ON a.Contact_Id < b.Contact_Id
    AND LOWER(TRIM(a.Email)) = LOWER(TRIM(b.Email))
    AND TRIM(a.School_Id) = TRIM(b.School_Id)
    AND LOWER(TRIM(a.First_Name)) =
        LOWER(TRIM(b.First_Name))
    AND LOWER(TRIM(a.Last_Name)) =
        LOWER(TRIM(b.Last_Name))

WHERE a.Email IS NOT NULL
  AND TRIM(a.Email) <> ''

ORDER BY a.Email;



-- CLEANUP 8D: Compare remaining duplicate contact fields
-- Inspection only: no data is changed.

SELECT
    a.Contact_Id AS Contact_1,
    b.Contact_Id AS Contact_2,

    IF(a.Title <=> b.Title,
       'Same', 'Different') AS Title_Check,

    IF(a.Department <=> b.Department,
       'Same', 'Different') AS Department_Check,

    IF(a.Created_Date <=> b.Created_Date,
       'Same', 'Different') AS Created_Date_Check

FROM crm_assessment.Contact_work a
JOIN crm_assessment.Contact_work b
    ON a.Contact_Id < b.Contact_Id
    AND TRIM(a.School_Id) = TRIM(b.School_Id)
    AND LOWER(TRIM(a.First_Name)) =
        LOWER(TRIM(b.First_Name))
    AND LOWER(TRIM(a.Last_Name)) =
        LOWER(TRIM(b.Last_Name))
    AND LOWER(TRIM(a.Email)) =
        LOWER(TRIM(b.Email))

WHERE a.Email IS NOT NULL
  AND TRIM(a.Email) <> ''

ORDER BY a.Contact_Id;




-- CLEANUP 8E: Remove Confirmed Duplicate Contacts
-- Keep original contact records.
-- Remove only five redundant copies.
-- Preserve Contact_raw unchanged.

DELETE cw
FROM crm_assessment.Contact_work AS cw
WHERE cw.Contact_Id IN (
    'CON-0301',
    'CON-0302',
    'CON-0303',
    'CON-0304',
    'CON-0305'
)
AND cw.Raw_Row_Id > 0
AND TRIM(cw.Is_Primary_Contact) = '0'
AND NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Club_raw AS c
    WHERE TRIM(c.Primary_Contact_Id)
          = TRIM(cw.Contact_Id)
);


-- Verify duplicate contact cleanup

SELECT
    (SELECT COUNT(*)
     FROM crm_assessment.Contact_raw)
        AS Original_Contacts,

    (SELECT COUNT(*)
     FROM crm_assessment.Contact_work)
        AS Cleaned_Contacts;




-- CLEANUP 9: Standardize Contact Phone Numbers
-- Convert recoverable numbers to a consistent format.
-- Preserve phone extensions.
-- Original Contact_raw remains unchanged.

UPDATE crm_assessment.Contact_work
SET Phone = CASE
    WHEN Contact_Id = 'CON-0011'
        THEN '(973) 555-0199'

    WHEN Contact_Id = 'CON-0019'
        THEN '(862) 555-0188'

    WHEN Contact_Id = 'CON-0043'
        THEN '(201) 555-0177'

    WHEN Contact_Id = 'CON-0071'
        THEN '(732) 555-0164 x12'

    ELSE Phone
END
WHERE Contact_Id IN (
    'CON-0011',
    'CON-0019',
    'CON-0043',
    'CON-0071'
);


-- Verify Cleanup 9: Phone Number Standardization

SELECT
    r.Contact_Id,
    r.Phone AS Original_Phone,
    w.Phone AS Cleaned_Phone
FROM crm_assessment.Contact_raw r
JOIN crm_assessment.Contact_work w
    ON r.Contact_Id = w.Contact_Id
WHERE r.Contact_Id IN (
    'CON-0011',
    'CON-0019',
    'CON-0043',
    'CON-0071'
)
ORDER BY r.Contact_Id;



-- CLEANUP 10: Handle Invalid Phone Numbers
-- Decision: Set incomplete or unverifiable
-- phone numbers to NULL.
-- Original values are preserved in Contact_raw.

UPDATE crm_assessment.Contact_work
SET Phone = NULL
WHERE Contact_Id IN (
    'CON-0003',
    'CON-0027',
    'CON-0035',
    'CON-0059'
);



-- Verify Cleanup 10

SELECT
    r.Contact_Id,
    r.Phone AS Original_Phone,
    COALESCE(w.Phone, '(NULL)') AS Cleaned_Phone
FROM crm_assessment.Contact_raw r
JOIN crm_assessment.Contact_work w
    ON r.Contact_Id = w.Contact_Id
WHERE r.Contact_Id IN (
    'CON-0003',
    'CON-0027',
    'CON-0035',
    'CON-0059'
)
ORDER BY r.Contact_Id;



-- CLEANUP 11: Investigate Contacts With Invalid School IDs
-- Inspection only: No records are modified.

SELECT
    c.Contact_Id,
    c.First_Name,
    c.Last_Name,
    c.School_Id AS Contact_School_Id,
    cl.Club_Id,
    cl.School_Id AS Club_School_Id

FROM crm_assessment.Contact_work c

LEFT JOIN crm_assessment.Club_raw cl
    ON TRIM(c.Contact_Id) =
       TRIM(cl.Primary_Contact_Id)

WHERE c.School_Id IS NULL
   OR NOT EXISTS (
       SELECT 1
       FROM crm_assessment.School_work s
       WHERE TRIM(s.School_Id) =
             TRIM(c.School_Id)
   )

ORDER BY c.Contact_Id, cl.Club_Id;



-- CLEANUP 11B: Quarantine Contacts With Invalid Schools
-- Preserve records that reference nonexistent schools.
-- Do not modify Contact_raw.

CREATE TABLE IF NOT EXISTS
crm_assessment.Contact_quarantine
LIKE crm_assessment.Contact_work;

INSERT INTO crm_assessment.Contact_quarantine
SELECT c.*
FROM crm_assessment.Contact_work c
WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.School_work s
    WHERE TRIM(s.School_Id) = TRIM(c.School_Id)
)
AND NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Contact_quarantine q
    WHERE q.Raw_Row_Id = c.Raw_Row_Id
);


-- Verify quarantined contacts

SELECT
    Contact_Id,
    First_Name,
    Last_Name,
    School_Id
FROM crm_assessment.Contact_quarantine
ORDER BY Contact_Id;



-- CLEANUP 12A: Investigate Multiple Primary Contacts
-- Identify primary contacts and their club references.
-- Inspection only: no records are modified.

SELECT
    c.School_Id,
    c.Contact_Id,
    c.First_Name,
    c.Last_Name,
    c.Email,
    c.Is_Primary_Contact,

    (
        SELECT COUNT(*)
        FROM crm_assessment.Club_raw cl
        WHERE TRIM(cl.Primary_Contact_Id) =
              TRIM(c.Contact_Id)
          AND TRIM(cl.School_Id) =
              TRIM(c.School_Id)
    ) AS Clubs_Using_Contact

FROM crm_assessment.Contact_work c

WHERE c.School_Id IN ('SCH-0002', 'SCH-0010')
  AND TRIM(c.Is_Primary_Contact) = '1'

ORDER BY c.School_Id, c.Contact_Id;



-- CLEANUP 12B: Resolve Multiple Primary Contacts
-- Decision: Retain CON-0002 and CON-0034 as
-- provisional primary contacts.
-- Keep all four contact records.
-- Document these assumptions in README.

UPDATE crm_assessment.Contact_work
SET Is_Primary_Contact = '0'
WHERE
    (School_Id = 'SCH-0002'
     AND Contact_Id = 'CON-0003')
    OR
    (School_Id = 'SCH-0010'
     AND Contact_Id = 'CON-0035');


-- Verify Cleanup 12B

SELECT
    School_Id,
    Contact_Id,
    First_Name,
    Last_Name,
    Is_Primary_Contact
FROM crm_assessment.Contact_work
WHERE Contact_Id IN (
    'CON-0002',
    'CON-0003',
    'CON-0034',
    'CON-0035'
)
ORDER BY School_Id, Contact_Id;



-- CLEANUP 12C: Schools Without Primary Contacts
-- Identify schools with zero primary contacts.
-- Inspection only: no records are modified.

SELECT
    s.School_Id,
    s.School_Name,

    COUNT(c.Contact_Id) AS Total_Contacts,

    SUM(
        CASE
            WHEN TRIM(c.Is_Primary_Contact) = '1'
            THEN 1
            ELSE 0
        END
    ) AS Primary_Contact_Count,

    CASE
        WHEN COUNT(c.Contact_Id) = 0
            THEN 'No Contacts Available'

        ELSE 'Contacts Exist - No Primary Selected'
    END AS Issue

FROM crm_assessment.School_work s

LEFT JOIN crm_assessment.Contact_work c
    ON TRIM(s.School_Id) = TRIM(c.School_Id)

GROUP BY
    s.School_Id,
    s.School_Name

HAVING Primary_Contact_Count = 0

ORDER BY s.School_Id;



-- CLEANUP 12D: Inspect Contacts for Schools
-- That Have No Primary Contact
-- Inspection only: no records are modified.

SELECT
    c.School_Id,
    c.Contact_Id,
    c.First_Name,
    c.Last_Name,
    c.Title,
    c.Department,
    c.Is_Primary_Contact,

    (
        SELECT COUNT(*)
        FROM crm_assessment.Club_raw cl
        WHERE TRIM(cl.Primary_Contact_Id) =
              TRIM(c.Contact_Id)
          AND TRIM(cl.School_Id) =
              TRIM(c.School_Id)
    ) AS Clubs_Using_Contact

FROM crm_assessment.Contact_work c

WHERE c.School_Id IN ('SCH-0012', 'SCH-0016')

ORDER BY c.School_Id, c.Contact_Id;




-- CLEANUP 12E: Assign Provisional Primary Contacts
-- Rule: Prefer existing club leads.
-- If multiple contacts qualify, use lowest Contact_Id.
-- Selections require business-owner confirmation.
-- Original Contact_raw remains unchanged.

UPDATE crm_assessment.Contact_work
SET Is_Primary_Contact = '1'
WHERE
    (School_Id = 'SCH-0012'
     AND Contact_Id = 'CON-0039')
    OR
    (School_Id = 'SCH-0016'
     AND Contact_Id = 'CON-0051');


-- Verify Cleanup 12E

SELECT
    School_Id,
    Contact_Id,
    First_Name,
    Last_Name,
    Is_Primary_Contact
FROM crm_assessment.Contact_work
WHERE School_Id IN ('SCH-0012', 'SCH-0016')
  AND TRIM(Is_Primary_Contact) = '1'
ORDER BY School_Id;



-- CLEANUP 12F: Schools Without Any Contacts
-- Business rule: Every school needs one primary contact.
-- Decision: Flag schools with no contacts for review.
-- Do not invent or delete records.

SELECT
    s.School_Id,
    s.School_Name,
    COUNT(c.Contact_Id) AS Total_Contacts,
    'Missing Contact Records - Needs Review' AS Issue

FROM crm_assessment.School_work s

LEFT JOIN crm_assessment.Contact_work c
    ON TRIM(s.School_Id) = TRIM(c.School_Id)

GROUP BY
    s.School_Id,
    s.School_Name

HAVING COUNT(c.Contact_Id) = 0

ORDER BY s.School_Id;



-- CLEANUP 13: Create Club Working Table
-- Preserve Club_raw as the original dataset.

CREATE TABLE IF NOT EXISTS crm_assessment.Club_work
LIKE crm_assessment.Club_raw;

-- Copy records not already present.
INSERT INTO crm_assessment.Club_work
SELECT r.*
FROM crm_assessment.Club_raw r
WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Club_work w
    WHERE w.Raw_Row_Id = r.Raw_Row_Id
);


-- Verify Club working table

SELECT
    (SELECT COUNT(*)
     FROM crm_assessment.Club_raw) AS Original_Rows,

    (SELECT COUNT(*)
     FROM crm_assessment.Club_work) AS Working_Rows;



-- CLEANUP 14: Fix Invalid Club Lead Contact References
-- A club's lead contact must belong to the same school.
-- Set unverifiable references to NULL.
-- Preserve original values in Club_raw.

UPDATE crm_assessment.Club_work AS cl

LEFT JOIN crm_assessment.Contact_work AS ct
    ON TRIM(cl.Primary_Contact_Id) = TRIM(ct.Contact_Id)
    AND TRIM(cl.School_Id) = TRIM(ct.School_Id)

SET cl.Primary_Contact_Id = NULL

WHERE cl.Raw_Row_Id > 0
  AND cl.Primary_Contact_Id IS NOT NULL
  AND TRIM(cl.Primary_Contact_Id) <> ''
  AND ct.Contact_Id IS NULL;


-- Verify Cleanup 14

SELECT
    r.Club_Id,
    r.School_Id,
    r.Primary_Contact_Id AS Original_Lead_Contact,
    COALESCE(
        w.Primary_Contact_Id,
        '(NULL)'
    ) AS Cleaned_Lead_Contact

FROM crm_assessment.Club_raw AS r

JOIN crm_assessment.Club_work AS w
    ON r.Raw_Row_Id = w.Raw_Row_Id

WHERE r.Club_Id IN (
    'CLB-0010',
    'CLB-0012',
    'CLB-0040'
)

ORDER BY r.Club_Id;




-- CLEANUP 15: Remove Quarantined Orphan Contacts
-- Preserve original records in Contact_raw.
-- Preserve quarantined records in Contact_quarantine.
-- Only remove contacts with invalid school references
-- that are not referenced by any club in Club_work.

DELETE c
FROM crm_assessment.Contact_work AS c

JOIN crm_assessment.Contact_quarantine AS q
    ON c.Raw_Row_Id = q.Raw_Row_Id

WHERE c.Contact_Id IN ('CON-0030', 'CON-0060')

  AND NOT EXISTS (
      SELECT 1
      FROM crm_assessment.School_work AS s
      WHERE TRIM(s.School_Id) = TRIM(c.School_Id)
  )

  AND NOT EXISTS (
      SELECT 1
      FROM crm_assessment.Club_work AS cl
      WHERE TRIM(cl.Primary_Contact_Id) =
            TRIM(c.Contact_Id)
  );


-- Verify Cleanup 15

SELECT
    (SELECT COUNT(*)
     FROM crm_assessment.Contact_raw)
        AS Original_Contacts,

    (SELECT COUNT(*)
     FROM crm_assessment.Contact_work)
        AS Working_Contacts,

    (SELECT COUNT(*)
     FROM crm_assessment.Contact_quarantine)
        AS Quarantined_Contacts;



-- CLEANUP 16: Standardize Club Stages
-- Fix inconsistent capitalization, spacing,
-- and missing spaces in club stage values.
-- Preserve original records in Club_raw.

UPDATE crm_assessment.Club_work
SET Stage = CASE
    WHEN Club_Id = 'CLB-0002'
        THEN 'Closed Won'

    WHEN Club_Id = 'CLB-0010'
        THEN 'Closed Won'

    WHEN Club_Id = 'CLB-0021'
        THEN 'Closed Won'

    WHEN Club_Id = 'CLB-0033'
        THEN 'Prospecting'

    ELSE Stage
END
WHERE Club_Id IN (
    'CLB-0002',
    'CLB-0010',
    'CLB-0021',
    'CLB-0033'
);


-- Verify Cleanup 16: Club Stage Standardization

SELECT
    r.Club_Id,
    CONCAT('[', r.Stage, ']') AS Original_Stage,
    CONCAT('[', w.Stage, ']') AS Cleaned_Stage

FROM crm_assessment.Club_raw r

JOIN crm_assessment.Club_work w
    ON r.Club_Id = w.Club_Id

WHERE r.Club_Id IN (
    'CLB-0002',
    'CLB-0010',
    'CLB-0021',
    'CLB-0033'
)

ORDER BY r.Club_Id;



-- CLEANUP 17: Handle Invalid Students Served
-- Decision: Set invalid student counts to NULL.
-- Preserve original values in Club_raw.

UPDATE crm_assessment.Club_work
SET Students_Served = NULL
WHERE Club_Id IN ('CLB-0012', 'CLB-0028')
  AND TRIM(Students_Served) IN ('-5', '0');


-- Verify Cleanup 17: Invalid Student Counts

SELECT
    r.Club_Id,
    r.Students_Served AS Original_Students,
    COALESCE(
        w.Students_Served,
        '(NULL)'
    ) AS Cleaned_Students

FROM crm_assessment.Club_raw r

JOIN crm_assessment.Club_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id

WHERE r.Club_Id IN (
    'CLB-0012',
    'CLB-0028'
)

ORDER BY r.Club_Id;



-- CLEANUP 18: Standardize Club Close Dates
-- Convert MM/DD/YYYY dates to YYYY-MM-DD.
-- Preserve original dates in Club_raw.

UPDATE crm_assessment.Club_work
SET Close_Date = DATE_FORMAT(
    STR_TO_DATE(Close_Date, '%c/%e/%Y'),
    '%Y-%m-%d'
)
WHERE Club_Id IN (
    'CLB-0007',
    'CLB-0015',
    'CLB-0024'
)
AND Close_Date REGEXP
    '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$';



-- Verify Cleanup 18: Club Date Standardization

SELECT
    r.Club_Id,
    r.Close_Date AS Original_Date,
    w.Close_Date AS Cleaned_Date
FROM crm_assessment.Club_raw r
JOIN crm_assessment.Club_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE r.Club_Id IN (
    'CLB-0007',
    'CLB-0015',
    'CLB-0024'
)
ORDER BY r.Club_Id;




-- CLEANUP 19: Create Deliverable Working Table
-- Preserve Deliverable_raw as the original dataset.

CREATE TABLE IF NOT EXISTS crm_assessment.Deliverable_work
LIKE crm_assessment.Deliverable_raw;

-- Copy records only if not already present.

INSERT INTO crm_assessment.Deliverable_work
SELECT r.*
FROM crm_assessment.Deliverable_raw r
WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Deliverable_work w
    WHERE w.Raw_Row_Id = r.Raw_Row_Id
);


-- Verify Deliverable working table

SELECT
    (SELECT COUNT(*)
     FROM crm_assessment.Deliverable_raw) AS Original_Rows,

    (SELECT COUNT(*)
     FROM crm_assessment.Deliverable_work) AS Working_Rows;



-- CLEANUP 20A: Investigate Deliverables With Invalid Club IDs
-- Extract possible Club IDs from deliverable names.
-- Inspection only: no records are modified.

SELECT
    d.Deliverable_Id,
    d.Deliverable_Name,
    d.Club_Id AS Invalid_Club_Id,

    REGEXP_SUBSTR(
        d.Deliverable_Name,
        'CLB-[0-9]{4}'
    ) AS Candidate_Club_Id,

    c.Club_Name AS Matching_Club_Name

FROM crm_assessment.Deliverable_work d

LEFT JOIN crm_assessment.Club_work c
    ON c.Club_Id = REGEXP_SUBSTR(
        d.Deliverable_Name,
        'CLB-[0-9]{4}'
    )

WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Club_work x
    WHERE TRIM(x.Club_Id) = TRIM(d.Club_Id)
)

ORDER BY d.Deliverable_Id;



-- CLEANUP 20B: Repair Invalid Deliverable Club References
-- Decision: Infer the intended Club_Id from Deliverable_Name.
-- Only repair records whose candidate club exists.
-- Preserve original values in Deliverable_raw.

UPDATE crm_assessment.Deliverable_work AS d

JOIN crm_assessment.Club_work AS c
    ON c.Club_Id = REGEXP_SUBSTR(
        d.Deliverable_Name,
        'CLB-[0-9]{4}'
    )

SET d.Club_Id = c.Club_Id

WHERE d.Deliverable_Id IN (
    'DEL-0003',
    'DEL-0014',
    'DEL-0029'
)
AND d.Club_Id = 'CLB-9999';



-- Verify Cleanup 20B

SELECT
    r.Deliverable_Id,
    r.Club_Id AS Original_Club_Id,
    w.Club_Id AS Cleaned_Club_Id

FROM crm_assessment.Deliverable_raw r

JOIN crm_assessment.Deliverable_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id

WHERE r.Deliverable_Id IN (
    'DEL-0003',
    'DEL-0014',
    'DEL-0029'
)

ORDER BY r.Deliverable_Id;



-- CLEANUP 21: Standardize Deliverable Statuses
-- Correct capitalization and formatting.
-- Preserve original records in Deliverable_raw.

UPDATE crm_assessment.Deliverable_work
SET Status = CASE
    WHEN Deliverable_Id = 'DEL-0005'
        THEN 'Completed'

    WHEN Deliverable_Id = 'DEL-0012'
        THEN 'In Progress'

    WHEN Deliverable_Id = 'DEL-0030'
        THEN 'Not Started'

    ELSE Status
END
WHERE Deliverable_Id IN (
    'DEL-0005',
    'DEL-0012',
    'DEL-0030'
);


-- Verify Cleanup 21: Deliverable Statuses

SELECT
    r.Deliverable_Id,
    CONCAT('[', r.Status, ']') AS Original_Status,
    CONCAT('[', w.Status, ']') AS Cleaned_Status
FROM crm_assessment.Deliverable_raw r
JOIN crm_assessment.Deliverable_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE r.Deliverable_Id IN (
    'DEL-0005',
    'DEL-0012',
    'DEL-0030'
)
ORDER BY r.Deliverable_Id;



-- CLEANUP 22A: Remove Completion Dates from
-- Deliverables Not Marked as Completed.
-- Assumption: Current status is authoritative.
-- Original dates remain in Deliverable_raw.

UPDATE crm_assessment.Deliverable_work
SET Completed_Date = NULL
WHERE Deliverable_Id IN (
    'DEL-0007',
    'DEL-0012',
    'DEL-0016',
    'DEL-0025'
)
AND LOWER(TRIM(Status)) <> 'completed'
AND Completed_Date IS NOT NULL
AND TRIM(Completed_Date) <> '';



-- Verify Cleanup 22A

SELECT
    r.Deliverable_Id,
    w.Status,
    r.Completed_Date AS Original_Date,
    COALESCE(
        w.Completed_Date,
        '(NULL)'
    ) AS Cleaned_Date
FROM crm_assessment.Deliverable_raw r
JOIN crm_assessment.Deliverable_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE r.Deliverable_Id IN (
    'DEL-0007',
    'DEL-0012',
    'DEL-0016',
    'DEL-0025'
)
ORDER BY r.Deliverable_Id;



-- CLEANUP 22B: Quarantine Missing Completion Dates
-- Keep original deliverables unchanged.
-- Flag completed items without a completion date.
-- Preserve all 404 records in Deliverable_work.

CREATE TABLE IF NOT EXISTS
crm_assessment.Deliverable_date_exceptions
LIKE crm_assessment.Deliverable_work;

INSERT INTO crm_assessment.Deliverable_date_exceptions
SELECT d.*
FROM crm_assessment.Deliverable_work d
WHERE LOWER(TRIM(d.Status)) = 'completed'
  AND (
      d.Completed_Date IS NULL
      OR TRIM(d.Completed_Date) = ''
  )
  AND NOT EXISTS (
      SELECT 1
      FROM crm_assessment.Deliverable_date_exceptions e
      WHERE e.Raw_Row_Id = d.Raw_Row_Id
  );



-- Verify Cleanup 22B

SELECT
    Deliverable_Id,
    Status,
    COALESCE(Completed_Date, '(NULL)') AS Completed_Date
FROM crm_assessment.Deliverable_date_exceptions
ORDER BY Deliverable_Id;



-- CLEANUP 22C: Standardize Missing Completion Dates
-- Convert blank date strings to SQL NULL.
-- Preserve original values in Deliverable_raw.
-- Do not invent missing completion dates.

UPDATE crm_assessment.Deliverable_work
SET Completed_Date = NULL
WHERE Completed_Date IS NOT NULL
  AND TRIM(Completed_Date) = '';



-- Verify Cleanup 22C

SELECT
    Deliverable_Id,
    Status,
    CASE
        WHEN Completed_Date IS NULL THEN 'SQL NULL'
        WHEN TRIM(Completed_Date) = '' THEN 'EMPTY STRING'
        ELSE Completed_Date
    END AS Date_Check
FROM crm_assessment.Deliverable_work
WHERE Deliverable_Id IN (
    'DEL-0004',
    'DEL-0011',
    'DEL-0022',
    'DEL-0033'
)
ORDER BY Deliverable_Id;



-- CLEANUP 23: Standardize Deliverable Due Dates
-- Convert DD-Mon-YYYY dates to YYYY-MM-DD.
-- Preserve original values in Deliverable_raw.

UPDATE crm_assessment.Deliverable_work
SET Due_Date = DATE_FORMAT(
    STR_TO_DATE(Due_Date, '%d-%b-%Y'),
    '%Y-%m-%d'
)
WHERE Deliverable_Id IN (
    'DEL-0006',
    'DEL-0021',
    'DEL-0036'
)
AND Due_Date REGEXP
    '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$';


-- Verify Cleanup 23

SELECT
    r.Deliverable_Id,
    r.Due_Date AS Original_Date,
    w.Due_Date AS Cleaned_Date
FROM crm_assessment.Deliverable_raw r
JOIN crm_assessment.Deliverable_work w
    ON r.Raw_Row_Id = w.Raw_Row_Id
WHERE r.Deliverable_Id IN (
    'DEL-0006',
    'DEL-0021',
    'DEL-0036'
)
ORDER BY r.Deliverable_Id;



-- CLEANUP 24: Validate Relationships
-- Check for broken foreign-key references.
-- Read-only query: no records are modified.

SELECT
    'Contacts with invalid schools' AS Check_Name,
    COUNT(*) AS Issues
FROM crm_assessment.Contact_work c
LEFT JOIN crm_assessment.School_work s
    ON TRIM(c.School_Id) = TRIM(s.School_Id)
WHERE s.School_Id IS NULL

UNION ALL

SELECT
    'Clubs with invalid schools',
    COUNT(*)
FROM crm_assessment.Club_work c
LEFT JOIN crm_assessment.School_work s
    ON TRIM(c.School_Id) = TRIM(s.School_Id)
WHERE s.School_Id IS NULL

UNION ALL

SELECT
    'Clubs with invalid lead contacts',
    COUNT(*)
FROM crm_assessment.Club_work c
LEFT JOIN crm_assessment.Contact_work ct
    ON TRIM(c.Primary_Contact_Id) = TRIM(ct.Contact_Id)
    AND TRIM(c.School_Id) = TRIM(ct.School_Id)
WHERE c.Primary_Contact_Id IS NOT NULL
  AND TRIM(c.Primary_Contact_Id) <> ''
  AND ct.Contact_Id IS NULL

UNION ALL

SELECT
    'Deliverables with invalid clubs',
    COUNT(*)
FROM crm_assessment.Deliverable_work d
LEFT JOIN crm_assessment.Club_work c
    ON TRIM(d.Club_Id) = TRIM(c.Club_Id)
WHERE c.Club_Id IS NULL;




-- STEP 25A: Check final School table before loading

SELECT
    (SELECT COUNT(*)
     FROM crm_assessment.School_work) AS Working_Rows,

    (SELECT COUNT(*)
     FROM crm_assessment.School) AS Final_Rows;




-- STEP 25B: Load Cleaned School Data
-- Source: School_work
-- Destination: School
-- Original School_raw remains unchanged.

INSERT INTO crm_assessment.School (
    School_Id,
    School_Name,
    School_Type,
    State,
    Zip,
    Enrollment,
    Partnership_Status,
    Relationship_Owner,
    Created_Date
)
SELECT
    TRIM(w.School_Id),
    NULLIF(TRIM(w.School_Name), ''),
    NULLIF(TRIM(w.School_Type), ''),
    NULLIF(TRIM(w.State), ''),
    NULLIF(TRIM(w.Zip), ''),

    CASE
        WHEN TRIM(w.Enrollment)
             REGEXP '^[1-9][0-9]*$'
        THEN CAST(w.Enrollment AS UNSIGNED)
        ELSE NULL
    END,

    NULLIF(TRIM(w.Partnership_Status), ''),
    NULLIF(TRIM(w.Relationship_Owner), ''),

    STR_TO_DATE(
        NULLIF(TRIM(w.Created_Date), ''),
        '%Y-%m-%d'
    )

FROM crm_assessment.School_work w

WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.School s
    WHERE s.School_Id = TRIM(w.School_Id)
);


-- Verify the final School table

SELECT
    COUNT(*) AS Total_Schools,
    SUM(School_Type IS NULL) AS Unknown_School_Types,
    SUM(Zip IS NULL) AS Unknown_Zip_Codes,
    SUM(Enrollment IS NULL) AS Unknown_Enrollments
FROM crm_assessment.School;




-- STEP 26: Load Cleaned Contact Data
-- Source: Contact_work
-- Destination: Contact
-- Preserve Contact_raw unchanged.

INSERT INTO crm_assessment.Contact (
    Contact_Id,
    School_Id,
    First_Name,
    Last_Name,
    Email,
    Phone,
    Title,
    Department,
    Is_Primary_Contact,
    Created_Date
)
SELECT
    TRIM(w.Contact_Id),
    TRIM(w.School_Id),
    NULLIF(TRIM(w.First_Name), ''),
    NULLIF(TRIM(w.Last_Name), ''),
    NULLIF(TRIM(w.Email), ''),
    NULLIF(TRIM(w.Phone), ''),
    NULLIF(TRIM(w.Title), ''),
    NULLIF(TRIM(w.Department), ''),

    CASE
        WHEN TRIM(w.Is_Primary_Contact) IN ('0', '1')
        THEN CAST(w.Is_Primary_Contact AS UNSIGNED)
        ELSE NULL
    END,

    STR_TO_DATE(
        NULLIF(TRIM(w.Created_Date), ''),
        '%Y-%m-%d'
    )

FROM crm_assessment.Contact_work w

WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Contact c
    WHERE c.Contact_Id = TRIM(w.Contact_Id)
)

AND EXISTS (
    SELECT 1
    FROM crm_assessment.School s
    WHERE s.School_Id = TRIM(w.School_Id)
);



-- Verify the final Contact table

SELECT
    COUNT(*) AS Total_Contacts,
    COUNT(DISTINCT Contact_Id) AS Unique_Contact_IDs,
    SUM(Email IS NULL) AS Unknown_Emails,
    SUM(Phone IS NULL) AS Unknown_Phones
FROM crm_assessment.Contact;



-- STEP 27: Load Cleaned Club Data
-- Source: Club_work
-- Destination: Club
-- Preserve Club_raw unchanged.

INSERT INTO crm_assessment.Club (
    Club_Id,
    School_Id,
    Club_Name,
    Stage,
    Students_Served,
    Close_Date,
    Primary_Contact_Id,
    Owner,
    Created_Date
)
SELECT
    TRIM(w.Club_Id),
    TRIM(w.School_Id),
    NULLIF(TRIM(w.Club_Name), ''),
    NULLIF(TRIM(w.Stage), ''),

    CASE
        WHEN TRIM(w.Students_Served)
             REGEXP '^[1-9][0-9]*$'
        THEN CAST(w.Students_Served AS UNSIGNED)
        ELSE NULL
    END,

    STR_TO_DATE(
        NULLIF(TRIM(w.Close_Date), ''),
        '%Y-%m-%d'
    ),

    NULLIF(TRIM(w.Primary_Contact_Id), ''),
    NULLIF(TRIM(w.Owner), ''),

    STR_TO_DATE(
        NULLIF(TRIM(w.Created_Date), ''),
        '%Y-%m-%d'
    )

FROM crm_assessment.Club_work w

WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Club c
    WHERE c.Club_Id = TRIM(w.Club_Id)
)

AND EXISTS (
    SELECT 1
    FROM crm_assessment.School s
    WHERE s.School_Id = TRIM(w.School_Id)
);


-- Verify final Club table

SELECT
    COUNT(*) AS Total_Clubs,
    COUNT(DISTINCT Club_Id) AS Unique_Club_IDs,
    SUM(Students_Served IS NULL) AS Unknown_Student_Counts,
    SUM(Primary_Contact_Id IS NULL) AS Unknown_Lead_Contacts
FROM crm_assessment.Club;



-- STEP 28: Load Cleaned Deliverable Data
-- Source: Deliverable_work
-- Destination: Deliverable
-- Preserve Deliverable_raw unchanged.

INSERT INTO crm_assessment.Deliverable (
    Deliverable_Id,
    Club_Id,
    Deliverable_Name,
    Deliverable_Type,
    Status,
    Due_Date,
    Completed_Date,
    Quantity,
    Assigned_To
)
SELECT
    TRIM(w.Deliverable_Id),
    TRIM(w.Club_Id),
    NULLIF(TRIM(w.Deliverable_Name), ''),
    NULLIF(TRIM(w.Deliverable_Type), ''),
    NULLIF(TRIM(w.Status), ''),

    STR_TO_DATE(
        NULLIF(TRIM(w.Due_Date), ''),
        '%Y-%m-%d'
    ),

    STR_TO_DATE(
        NULLIF(TRIM(w.Completed_Date), ''),
        '%Y-%m-%d'
    ),

    CASE
        WHEN TRIM(w.Quantity) REGEXP '^[1-9][0-9]*$'
        THEN CAST(w.Quantity AS UNSIGNED)
        ELSE NULL
    END,

    NULLIF(TRIM(w.Assigned_To), '')

FROM crm_assessment.Deliverable_work w

WHERE NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Deliverable d
    WHERE d.Deliverable_Id = TRIM(w.Deliverable_Id)
)

AND EXISTS (
    SELECT 1
    FROM crm_assessment.Club c
    WHERE c.Club_Id = TRIM(w.Club_Id)
);


-- Verify final Deliverable table

SELECT
    COUNT(*) AS Total_Deliverables,
    COUNT(DISTINCT Deliverable_Id) AS Unique_Deliverable_IDs,

    SUM(
        Status = 'Completed'
        AND Completed_Date IS NULL
    ) AS Completed_Missing_Date,

    SUM(
        Status <> 'Completed'
        AND Completed_Date IS NOT NULL
    ) AS Incomplete_With_Date

FROM crm_assessment.Deliverable;



-- STEP 29: Final Database Relationship Validation
-- Read-only verification; does not modify data.

SELECT
    'Contact to School' AS Relationship_Check,
    COUNT(*) AS Issues
FROM crm_assessment.Contact ct
LEFT JOIN crm_assessment.School s
    ON ct.School_Id = s.School_Id
WHERE s.School_Id IS NULL

UNION ALL

SELECT
    'Club to School',
    COUNT(*)
FROM crm_assessment.Club cl
LEFT JOIN crm_assessment.School s
    ON cl.School_Id = s.School_Id
WHERE s.School_Id IS NULL

UNION ALL

SELECT
    'Club Lead Contact to Same School',
    COUNT(*)
FROM crm_assessment.Club cl
LEFT JOIN crm_assessment.Contact ct
    ON cl.Primary_Contact_Id = ct.Contact_Id
    AND cl.School_Id = ct.School_Id
WHERE cl.Primary_Contact_Id IS NOT NULL
  AND ct.Contact_Id IS NULL

UNION ALL

SELECT
    'Deliverable to Club',
    COUNT(*)
FROM crm_assessment.Deliverable d
LEFT JOIN crm_assessment.Club cl
    ON d.Club_Id = cl.Club_Id
WHERE cl.Club_Id IS NULL;










