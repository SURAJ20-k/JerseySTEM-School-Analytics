


SELECT
    School_Id,
    School_Name,
    Enrollment,
    CASE
        WHEN Enrollment IS NULL
             OR TRIM(Enrollment) = ''
            THEN 'Missing Enrollment'
        WHEN TRIM(Enrollment) REGEXP '^-[0-9]+$'
            THEN 'Negative Enrollment'
        WHEN TRIM(Enrollment) REGEXP '^0+$'
            THEN 'Zero Enrollment'
        WHEN TRIM(Enrollment) NOT REGEXP '^[0-9]+$'
            THEN 'Invalid Number Format'
    END AS Issue
FROM crm_assessment.School_raw
WHERE Enrollment IS NULL
   OR TRIM(Enrollment) = ''
   OR TRIM(Enrollment) NOT REGEXP '^[0-9]+$'
   OR TRIM(Enrollment) REGEXP '^0+$';




-- CHECK 2: Invalid School Types
-- Valid types: Public, Charter, Private, Magnet
-- Detect missing values, capitalization, and whitespace.

SELECT
    School_Id,
    School_Name,
    School_Type,
    CASE
        WHEN School_Type IS NULL
             OR TRIM(School_Type) = ''
            THEN 'Missing School Type'

        WHEN BINARY TRIM(School_Type)
             IN ('Public', 'Charter', 'Private', 'Magnet')
            THEN 'Extra Whitespace'

        WHEN LOWER(TRIM(School_Type))
             IN ('public', 'charter', 'private', 'magnet')
            THEN 'Inconsistent Capitalization'

        ELSE 'Invalid School Type'
    END AS Issue
FROM crm_assessment.School_raw
WHERE School_Type IS NULL
   OR TRIM(School_Type) = ''
   OR BINARY School_Type NOT IN
      ('Public', 'Charter', 'Private', 'Magnet')
ORDER BY School_Id;




-- CHECK 3: Invalid Partnership Status
-- Valid values: Active, Prospect, Alumni

SELECT
    School_Id,
    School_Name,
    Partnership_Status,
    CASE
        WHEN Partnership_Status IS NULL
             OR TRIM(Partnership_Status) = ''
            THEN 'Missing Partnership Status'

        WHEN BINARY TRIM(Partnership_Status)
             IN ('Active', 'Prospect', 'Alumni')
            THEN 'Extra Whitespace'

        WHEN LOWER(TRIM(Partnership_Status))
             IN ('active', 'prospect', 'alumni')
            THEN 'Inconsistent Capitalization'

        ELSE 'Invalid Partnership Status'
    END AS Issue

FROM crm_assessment.School_raw

WHERE Partnership_Status IS NULL
   OR TRIM(Partnership_Status) = ''
   OR BINARY Partnership_Status NOT IN
      ('Active', 'Prospect', 'Alumni')

ORDER BY School_Id;



-- CHECK 4: Invalid School ZIP Codes
-- Valid formats: 12345 or 12345-6789
-- Detect missing, malformed, or shortened ZIP codes.

SELECT
    School_Id,
    School_Name,
    Zip,
    CASE
        WHEN Zip IS NULL OR TRIM(Zip) = ''
            THEN 'Missing ZIP Code'

        WHEN TRIM(Zip) REGEXP '^[0-9]{4}$'
            THEN 'Possible Missing Leading Zero'

        WHEN TRIM(Zip) REGEXP '^[0-9]{5}(-[0-9]{4})?$'
             AND BINARY Zip <> BINARY TRIM(Zip)
            THEN 'Extra Whitespace'

        ELSE 'Invalid ZIP Format'
    END AS Issue

FROM crm_assessment.School_raw

WHERE Zip IS NULL
   OR TRIM(Zip) = ''
   OR TRIM(Zip) NOT REGEXP '^[0-9]{5}(-[0-9]{4})?$'
   OR BINARY Zip <> BINARY TRIM(Zip)

ORDER BY School_Id;



-- CHECK 5: Possible Duplicate Schools
-- Detect school names that appear more than once,
-- ignoring capitalization and extra whitespace.

SELECT
    LOWER(TRIM(School_Name)) AS Normalized_School_Name,
    COUNT(*) AS Duplicate_Count,
    GROUP_CONCAT(
        School_Id
        ORDER BY School_Id
        SEPARATOR ', '
    ) AS School_Ids
FROM crm_assessment.School_raw
WHERE School_Name IS NOT NULL
  AND TRIM(School_Name) <> ''
GROUP BY LOWER(TRIM(School_Name))
HAVING COUNT(*) > 1
ORDER BY Duplicate_Count DESC;



-- CHECK 6: Duplicate Contact Email Addresses
-- Identify emails assigned to multiple contact records.

SELECT
    LOWER(TRIM(Email)) AS Normalized_Email,
    COUNT(*) AS Duplicate_Count,
    GROUP_CONCAT(
        Contact_Id
        ORDER BY Contact_Id
        SEPARATOR ', '
    ) AS Contact_Ids
FROM crm_assessment.Contact_raw
WHERE Email IS NOT NULL
  AND TRIM(Email) <> ''
GROUP BY LOWER(TRIM(Email))
HAVING COUNT(*) > 1
ORDER BY Normalized_Email;




-- CHECK 7: Invalid Contact Email Addresses
-- Detect missing and incorrectly formatted emails.

SELECT
    Contact_Id,
    School_Id,
    First_Name,
    Last_Name,
    Email,
    CASE
        WHEN Email IS NULL OR TRIM(Email) = ''
            THEN 'Missing Email'

        ELSE 'Invalid Email Format'
    END AS Issue

FROM crm_assessment.Contact_raw

WHERE Email IS NULL
   OR TRIM(Email) = ''
   OR NOT REGEXP_LIKE(
       TRIM(Email),
       '^[[:alnum:]_.%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}$',
       'c'
   )

ORDER BY Contact_Id;



-- CHECK 8: Invalid or Inconsistent Contact Phone Numbers
-- Standard format: (123) 456-7890
-- Identify numbers requiring review or normalization.

SELECT
    Contact_Id,
    School_Id,
    Phone,
    CASE
        WHEN Phone IS NULL OR TRIM(Phone) = ''
            THEN 'Missing Phone'

        WHEN REGEXP_LIKE(
            TRIM(Phone),
            '[xX][0-9]+$',
            'c'
        )
            THEN 'Phone With Extension'

        WHEN LEFT(TRIM(Phone), 2) = '+1'
             AND LENGTH(REGEXP_REPLACE(Phone, '[^0-9]', '')) = 11
            THEN 'Country Code - Normalize'

        WHEN LENGTH(REGEXP_REPLACE(Phone, '[^0-9]', '')) = 10
            THEN 'Nonstandard Phone Format'

        ELSE 'Invalid or Incomplete Phone'
    END AS Issue

FROM crm_assessment.Contact_raw

WHERE Phone IS NULL
   OR TRIM(Phone) = ''
   OR NOT REGEXP_LIKE(
       TRIM(Phone),
       '^[(][0-9]{3}[)] [0-9]{3}-[0-9]{4}$',
       'c'
   )

ORDER BY Contact_Id;



-- CHECK 9: Contacts Linked to Nonexistent Schools
-- Every contact must belong to an existing school.

SELECT
    c.Contact_Id,
    c.School_Id,
    c.First_Name,
    c.Last_Name,
    CASE
        WHEN c.School_Id IS NULL
             OR TRIM(c.School_Id) = ''
            THEN 'Missing School ID'
        ELSE 'School Does Not Exist'
    END AS Issue

FROM crm_assessment.Contact_raw c

LEFT JOIN crm_assessment.School_raw s
    ON TRIM(c.School_Id) = TRIM(s.School_Id)

WHERE s.School_Id IS NULL

ORDER BY c.Contact_Id;



-- CHECK 10: Schools Without Exactly One Primary Contact
-- Business rule: Each school must have exactly
-- one contact marked as primary.

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
        WHEN SUM(
            CASE
                WHEN TRIM(c.Is_Primary_Contact) = '1'
                THEN 1
                ELSE 0
            END
        ) = 0
        THEN 'Missing Primary Contact'

        ELSE 'Multiple Primary Contacts'
    END AS Issue

FROM crm_assessment.School_raw s

LEFT JOIN crm_assessment.Contact_raw c
    ON TRIM(s.School_Id) = TRIM(c.School_Id)

GROUP BY
    s.School_Id,
    s.School_Name

HAVING Primary_Contact_Count <> 1

ORDER BY s.School_Id;



-- CHECK 11: Clubs Linked to Nonexistent Schools
-- Business Rule: Every club must belong to an existing school.

SELECT
    c.Club_Id,
    c.Club_Name,
    c.School_Id,
    CASE
        WHEN c.School_Id IS NULL
             OR TRIM(c.School_Id) = ''
            THEN 'Missing School ID'
        ELSE 'School Does Not Exist'
    END AS Issue

FROM crm_assessment.Club_raw c

LEFT JOIN crm_assessment.School_raw s
    ON TRIM(c.School_Id) = TRIM(s.School_Id)

WHERE s.School_Id IS NULL

ORDER BY c.Club_Id;



-- CHECK 12: Invalid Club Lead Contact
-- Every club's lead contact must exist
-- and belong to the same school as the club.

SELECT
    c.Club_Id,
    c.Club_Name,
    c.School_Id AS Club_School_Id,
    c.Primary_Contact_Id,
    ct.School_Id AS Contact_School_Id,

    CASE
        WHEN c.Primary_Contact_Id IS NULL
             OR TRIM(c.Primary_Contact_Id) = ''
            THEN 'Missing Lead Contact'

        WHEN ct.Contact_Id IS NULL
            THEN 'Lead Contact Does Not Exist'

        WHEN ct.School_Id IS NULL
             OR TRIM(ct.School_Id) <> TRIM(c.School_Id)
            THEN 'Lead Contact Belongs to Different School'
    END AS Issue

FROM crm_assessment.Club_raw c

LEFT JOIN crm_assessment.Contact_raw ct
    ON TRIM(c.Primary_Contact_Id) =
       TRIM(ct.Contact_Id)

WHERE c.Primary_Contact_Id IS NULL
   OR TRIM(c.Primary_Contact_Id) = ''
   OR ct.Contact_Id IS NULL
   OR ct.School_Id IS NULL
   OR TRIM(ct.School_Id) <> TRIM(c.School_Id)

ORDER BY c.Club_Id;



-- CHECK 13: Invalid Club Stages
-- Business Rule: Club stage must match
-- one of the six permitted values.

SELECT
    Club_Id,
    Club_Name,
    Stage,

    CASE
        WHEN Stage IS NULL
             OR TRIM(Stage) = ''
            THEN 'Missing Stage'

        WHEN BINARY TRIM(Stage) IN (
            'Prospecting',
            'Qualification',
            'Proposal',
            'Negotiation',
            'Closed Won',
            'Closed Lost'
        )
            THEN 'Extra Whitespace'

        WHEN LOWER(TRIM(Stage)) IN (
            'prospecting',
            'qualification',
            'proposal',
            'negotiation',
            'closed won',
            'closed lost'
        )
            THEN 'Inconsistent Capitalization'

        ELSE 'Invalid Stage'
    END AS Issue

FROM crm_assessment.Club_raw

WHERE Stage IS NULL
   OR TRIM(Stage) = ''
   OR BINARY Stage NOT IN (
       'Prospecting',
       'Qualification',
       'Proposal',
       'Negotiation',
       'Closed Won',
       'Closed Lost'
   )

ORDER BY Club_Id;



-- CHECK 14: Invalid Students Served
-- Business Rule: Students_Served must be a positive integer.
-- Detect missing, zero, negative, and nonnumeric values.

SELECT
    Club_Id,
    Club_Name,
    Students_Served,

    CASE
        WHEN Students_Served IS NULL
             OR TRIM(Students_Served) = ''
            THEN 'Missing Student Count'

        WHEN TRIM(Students_Served) REGEXP '^-[0-9]+$'
            THEN 'Negative Student Count'

        WHEN TRIM(Students_Served) REGEXP '^0+$'
            THEN 'Zero Students Served'

        WHEN TRIM(Students_Served) NOT REGEXP '^[0-9]+$'
            THEN 'Invalid Number Format'

    END AS Issue

FROM crm_assessment.Club_raw

WHERE Students_Served IS NULL
   OR TRIM(Students_Served) = ''
   OR TRIM(Students_Served) NOT REGEXP '^[0-9]+$'
   OR TRIM(Students_Served) REGEXP '^0+$'

ORDER BY Club_Id;



-- CHECK 15: Inconsistent Club Date Formats
-- Expected date format: YYYY-MM-DD
-- Find missing dates or dates stored in other formats.

SELECT
    Club_Id,
    Club_Name,
    Close_Date,
    Created_Date,

    CASE
        WHEN Close_Date IS NULL
             OR TRIM(Close_Date) = ''
            THEN 'Missing Close Date'

        WHEN Created_Date IS NULL
             OR TRIM(Created_Date) = ''
            THEN 'Missing Created Date'

        WHEN TRIM(Close_Date) NOT REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN 'Nonstandard Close Date Format'

        WHEN TRIM(Created_Date) NOT REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN 'Nonstandard Created Date Format'
    END AS Issue

FROM crm_assessment.Club_raw

WHERE Close_Date IS NULL
   OR TRIM(Close_Date) = ''
   OR Created_Date IS NULL
   OR TRIM(Created_Date) = ''
   OR TRIM(Close_Date) NOT REGEXP
      '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   OR TRIM(Created_Date) NOT REGEXP
      '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

ORDER BY Club_Id;



-- CHECK 16: Deliverables Linked to Nonexistent Clubs
-- Business Rule: Every deliverable must belong
-- to an existing club.

SELECT
    d.Deliverable_Id,
    d.Deliverable_Name,
    d.Club_Id,

    CASE
        WHEN d.Club_Id IS NULL
             OR TRIM(d.Club_Id) = ''
            THEN 'Missing Club ID'
        ELSE 'Club Does Not Exist'
    END AS Issue

FROM crm_assessment.Deliverable_raw d

LEFT JOIN crm_assessment.Club_raw c
    ON TRIM(d.Club_Id) = TRIM(c.Club_Id)

WHERE c.Club_Id IS NULL

ORDER BY d.Deliverable_Id;



-- CHECK 17: Invalid Deliverable Status
-- Valid values: Not Started, In Progress,
-- Completed, Blocked

SELECT
    Deliverable_Id,
    Deliverable_Name,
    Status,

    CASE
        WHEN Status IS NULL
             OR TRIM(Status) = ''
            THEN 'Missing Status'

        WHEN BINARY TRIM(Status) IN (
            'Not Started',
            'In Progress',
            'Completed',
            'Blocked'
        )
            THEN 'Extra Whitespace'

        WHEN LOWER(TRIM(Status)) IN (
            'not started',
            'in progress',
            'completed',
            'blocked'
        )
            THEN 'Inconsistent Capitalization'

        ELSE 'Invalid Status'
    END AS Issue

FROM crm_assessment.Deliverable_raw

WHERE Status IS NULL
   OR TRIM(Status) = ''
   OR BINARY Status NOT IN (
       'Not Started',
       'In Progress',
       'Completed',
       'Blocked'
   )

ORDER BY Deliverable_Id;





-- CHECK 18: Invalid Deliverable Quantities
-- Business Rule: Quantity must be a positive integer.

SELECT
    Deliverable_Id,
    Deliverable_Name,
    Quantity,

    CASE
        WHEN Quantity IS NULL
             OR TRIM(Quantity) = ''
            THEN 'Missing Quantity'

        WHEN TRIM(Quantity) REGEXP '^-[0-9]+$'
            THEN 'Negative Quantity'

        WHEN TRIM(Quantity) REGEXP '^0+$'
            THEN 'Zero Quantity'

        ELSE 'Invalid Number Format'
    END AS Issue

FROM crm_assessment.Deliverable_raw

WHERE Quantity IS NULL
   OR TRIM(Quantity) = ''
   OR TRIM(Quantity) NOT REGEXP '^[0-9]+$'
   OR TRIM(Quantity) REGEXP '^0+$'

ORDER BY Deliverable_Id;



-- CHECK 19: Completion Date Rule Violations
-- Completed deliverables must have a completion date.
-- Incomplete deliverables must not have one.

SELECT
    Deliverable_Id,
    Deliverable_Name,
    Status,
    Completed_Date,

    CASE
        WHEN LOWER(TRIM(Status)) = 'completed'
             AND (
                 Completed_Date IS NULL
                 OR TRIM(Completed_Date) = ''
             )
        THEN 'Completed But Missing Completion Date'

        WHEN LOWER(TRIM(Status)) <> 'completed'
             AND Completed_Date IS NOT NULL
             AND TRIM(Completed_Date) <> ''
        THEN 'Not Completed But Has Completion Date'
    END AS Issue

FROM crm_assessment.Deliverable_raw

WHERE (
    LOWER(TRIM(Status)) = 'completed'
    AND (
        Completed_Date IS NULL
        OR TRIM(Completed_Date) = ''
    )
)
OR (
    LOWER(TRIM(Status)) <> 'completed'
    AND Completed_Date IS NOT NULL
    AND TRIM(Completed_Date) <> ''
)

ORDER BY Deliverable_Id;



-- CHECK 20: Invalid Deliverable Date Formats
-- Expected format: YYYY-MM-DD
-- Missing completion dates are checked separately in CHECK 19.

SELECT
    Deliverable_Id,
    Deliverable_Name,
    Due_Date,
    Completed_Date,
    CASE
        WHEN Due_Date IS NULL
             OR TRIM(Due_Date) = ''
            THEN 'Missing Due Date'

        WHEN TRIM(Due_Date) NOT REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN 'Nonstandard Due Date Format'

        WHEN Completed_Date IS NOT NULL
             AND TRIM(Completed_Date) <> ''
             AND TRIM(Completed_Date) NOT REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN 'Nonstandard Completion Date Format'
    END AS Issue

FROM crm_assessment.Deliverable_raw

WHERE Due_Date IS NULL
   OR TRIM(Due_Date) = ''
   OR TRIM(Due_Date) NOT REGEXP
      '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   OR (
       Completed_Date IS NOT NULL
       AND TRIM(Completed_Date) <> ''
       AND TRIM(Completed_Date) NOT REGEXP
           '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   )

ORDER BY Deliverable_Id;



-- CHECK 21: Duplicate Record IDs
-- Every School, Contact, Club, and Deliverable
-- must have a unique primary key.

WITH all_ids AS (
    SELECT 'School' AS Table_Name,
           TRIM(School_Id) AS Record_Id
    FROM crm_assessment.School_raw

    UNION ALL

    SELECT 'Contact',
           TRIM(Contact_Id)
    FROM crm_assessment.Contact_raw

    UNION ALL

    SELECT 'Club',
           TRIM(Club_Id)
    FROM crm_assessment.Club_raw

    UNION ALL

    SELECT 'Deliverable',
           TRIM(Deliverable_Id)
    FROM crm_assessment.Deliverable_raw
)

SELECT
    Table_Name,
    Record_Id,
    COUNT(*) AS Duplicate_Count
FROM all_ids
WHERE Record_Id IS NOT NULL
  AND Record_Id <> ''
GROUP BY Table_Name, Record_Id
HAVING COUNT(*) > 1
ORDER BY Table_Name, Record_Id;



-- CHECK 22: Invalid Deliverable Types
-- Business Rule: Deliverable type must be one
-- of Report, Workshop, Installation, Training, Assessment.

SELECT
    Deliverable_Id,
    Deliverable_Name,
    Deliverable_Type,

    CASE
        WHEN Deliverable_Type IS NULL
             OR TRIM(Deliverable_Type) = ''
            THEN 'Missing Deliverable Type'

        WHEN BINARY TRIM(Deliverable_Type) IN (
            'Report',
            'Workshop',
            'Installation',
            'Training',
            'Assessment'
        )
            THEN 'Extra Whitespace'

        WHEN LOWER(TRIM(Deliverable_Type)) IN (
            'report',
            'workshop',
            'installation',
            'training',
            'assessment'
        )
            THEN 'Inconsistent Capitalization'

        ELSE 'Invalid Deliverable Type'
    END AS Issue

FROM crm_assessment.Deliverable_raw

WHERE Deliverable_Type IS NULL
   OR TRIM(Deliverable_Type) = ''
   OR BINARY Deliverable_Type NOT IN (
       'Report',
       'Workshop',
       'Installation',
       'Training',
       'Assessment'
   )

ORDER BY Deliverable_Id;



-- CHECK 23: Missing Primary Key IDs
-- Every record must have a nonempty ID.

SELECT
    'School' AS Table_Name,
    Raw_Row_Id,
    School_Id AS Record_Id
FROM crm_assessment.School_raw
WHERE School_Id IS NULL
   OR TRIM(School_Id) = ''

UNION ALL

SELECT
    'Contact',
    Raw_Row_Id,
    Contact_Id
FROM crm_assessment.Contact_raw
WHERE Contact_Id IS NULL
   OR TRIM(Contact_Id) = ''

UNION ALL

SELECT
    'Club',
    Raw_Row_Id,
    Club_Id
FROM crm_assessment.Club_raw
WHERE Club_Id IS NULL
   OR TRIM(Club_Id) = ''

UNION ALL

SELECT
    'Deliverable',
    Raw_Row_Id,
    Deliverable_Id
FROM crm_assessment.Deliverable_raw
WHERE Deliverable_Id IS NULL
   OR TRIM(Deliverable_Id) = ''

ORDER BY Table_Name, Raw_Row_Id;



-- CHECK 24: Missing Required Names
-- Identify records with missing or blank names.

SELECT
    'School' AS Table_Name,
    School_Id AS Record_Id,
    'Missing School Name' AS Issue
FROM crm_assessment.School_raw
WHERE School_Name IS NULL
   OR TRIM(School_Name) = ''

UNION ALL

SELECT
    'Contact',
    Contact_Id,
    'Missing First Name'
FROM crm_assessment.Contact_raw
WHERE First_Name IS NULL
   OR TRIM(First_Name) = ''

UNION ALL

SELECT
    'Contact',
    Contact_Id,
    'Missing Last Name'
FROM crm_assessment.Contact_raw
WHERE Last_Name IS NULL
   OR TRIM(Last_Name) = ''

UNION ALL

SELECT
    'Club',
    Club_Id,
    'Missing Club Name'
FROM crm_assessment.Club_raw
WHERE Club_Name IS NULL
   OR TRIM(Club_Name) = ''

UNION ALL

SELECT
    'Deliverable',
    Deliverable_Id,
    'Missing Deliverable Name'
FROM crm_assessment.Deliverable_raw
WHERE Deliverable_Name IS NULL
   OR TRIM(Deliverable_Name) = ''

ORDER BY Table_Name, Record_Id;



-- CHECK 25: Invalid Calendar Dates
-- Check ISO-formatted dates for impossible calendar days.
-- Nonstandard formats were identified in earlier checks.

WITH all_dates AS (
    SELECT 'School' AS Table_Name,
           School_Id AS Record_Id,
           'Created_Date' AS Date_Field,
           Created_Date AS Date_Value
    FROM crm_assessment.School_raw

    UNION ALL

    SELECT 'Contact', Contact_Id, 'Created_Date', Created_Date
    FROM crm_assessment.Contact_raw

    UNION ALL

    SELECT 'Club', Club_Id, 'Close_Date', Close_Date
    FROM crm_assessment.Club_raw

    UNION ALL

    SELECT 'Club', Club_Id, 'Created_Date', Created_Date
    FROM crm_assessment.Club_raw

    UNION ALL

    SELECT 'Deliverable', Deliverable_Id, 'Due_Date', Due_Date
    FROM crm_assessment.Deliverable_raw

    UNION ALL

    SELECT 'Deliverable', Deliverable_Id,
           'Completed_Date', Completed_Date
    FROM crm_assessment.Deliverable_raw
),
parsed_dates AS (
    SELECT *,
           CAST(LEFT(Date_Value, 4) AS UNSIGNED) AS yr,
           CAST(SUBSTRING(Date_Value, 6, 2) AS UNSIGNED) AS mon,
           CAST(RIGHT(Date_Value, 2) AS UNSIGNED) AS dy
    FROM all_dates
    WHERE TRIM(Date_Value) REGEXP
          '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
)

SELECT
    Table_Name,
    Record_Id,
    Date_Field,
    Date_Value,
    'Invalid Calendar Date' AS Issue
FROM parsed_dates
WHERE yr NOT BETWEEN 1000 AND 9999
   OR mon NOT BETWEEN 1 AND 12
   OR dy < 1
   OR dy > CASE
       WHEN mon IN (1,3,5,7,8,10,12) THEN 31
       WHEN mon IN (4,6,9,11) THEN 30
       WHEN mon = 2 AND
            (MOD(yr,400) = 0 OR
            (MOD(yr,4) = 0 AND MOD(yr,100) <> 0))
            THEN 29
       WHEN mon = 2 THEN 28
       ELSE 0
   END
ORDER BY Table_Name, Record_Id;


















