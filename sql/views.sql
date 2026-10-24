
-- JerseySTEM DATA101 2 - SQL Reporting Views

USE crm_assessment;

-- VIEW 1: School and Club Summary
-- Include all schools, even those with zero clubs.

CREATE OR REPLACE VIEW vw_school_club_summary AS

SELECT
    s.School_Id,
    s.School_Name,
    s.School_Type,
    s.Partnership_Status,

    COUNT(c.Club_Id) AS Total_Clubs,

    SUM(
        CASE
            WHEN c.Stage = 'Closed Won'
            THEN 1
            ELSE 0
        END
    ) AS Confirmed_Clubs,

    COALESCE(
        SUM(
            CASE
                WHEN c.Stage = 'Closed Won'
                THEN c.Students_Served
                ELSE 0
            END
        ), 0
    ) AS Known_Students_Served,

    SUM(
        CASE
            WHEN c.Stage = 'Closed Won'
                 AND c.Students_Served IS NULL
            THEN 1
            ELSE 0
        END
    ) AS Confirmed_Clubs_Missing_Count

FROM School s

LEFT JOIN Club c
    ON s.School_Id = c.School_Id

GROUP BY
    s.School_Id,
    s.School_Name,
    s.School_Type,
    s.Partnership_Status;



-- Verify View 1

SELECT COUNT(*) AS Total_Schools
FROM crm_assessment.vw_school_club_summary;

SELECT *
FROM crm_assessment.vw_school_club_summary
ORDER BY Total_Clubs DESC
LIMIT 10;




-- VIEW 2: Overdue Deliverables
-- Identify work items that are past due
-- and have not been completed.

CREATE OR REPLACE VIEW crm_assessment.vw_overdue_deliverables AS

SELECT
    d.Deliverable_Id,
    d.Deliverable_Name,
    d.Deliverable_Type,
    d.Status,
    d.Due_Date,
    d.Assigned_To,

    c.Club_Id,
    c.Club_Name,

    s.School_Id,
    s.School_Name,
    s.School_Type,

    DATEDIFF(CURDATE(), d.Due_Date)
        AS Days_Overdue

FROM crm_assessment.Deliverable d

JOIN crm_assessment.Club c
    ON d.Club_Id = c.Club_Id

JOIN crm_assessment.School s
    ON c.School_Id = s.School_Id

WHERE d.Due_Date < CURDATE()
  AND d.Status <> 'Completed';



-- Count overdue deliverables

SELECT COUNT(*) AS Overdue_Deliverables
FROM crm_assessment.vw_overdue_deliverables;

-- Show 10 most overdue deliverables

SELECT
    Deliverable_Id,
    Deliverable_Name,
    School_Name,
    Due_Date,
    Status,
    Days_Overdue
FROM crm_assessment.vw_overdue_deliverables
ORDER BY Days_Overdue DESC
LIMIT 10;




-- VIEW 3: Students Served by School Type
-- Summarize schools, clubs, confirmed clubs,
-- and reported students served by school type.

CREATE OR REPLACE VIEW
crm_assessment.vw_students_by_school_type AS

SELECT
    COALESCE(School_Type, 'Unknown') AS School_Type,

    COUNT(*) AS Total_Schools,

    SUM(Total_Clubs) AS Total_Clubs,

    SUM(Confirmed_Clubs) AS Confirmed_Clubs,

    SUM(Known_Students_Served) AS Known_Students_Served,

    SUM(Confirmed_Clubs_Missing_Count)
        AS Clubs_Missing_Student_Count

FROM crm_assessment.vw_school_club_summary

GROUP BY COALESCE(School_Type, 'Unknown');



-- Verify View 3

SELECT *
FROM crm_assessment.vw_students_by_school_type
ORDER BY Known_Students_Served DESC;




-- VIEW 4: Top Schools by Students Served
-- Includes school performance and primary contact.
-- Preserves schools without primary contacts.

CREATE OR REPLACE VIEW
crm_assessment.vw_top_schools AS

SELECT
    s.School_Id,
    s.School_Name,
    COALESCE(s.School_Type, 'Unknown')
        AS School_Type,
    s.Partnership_Status,

    s.Total_Clubs,
    s.Confirmed_Clubs,
    s.Known_Students_Served,
    s.Confirmed_Clubs_Missing_Count,

    CASE
        WHEN c.Contact_Id IS NULL
            THEN 'Not Available'
        ELSE CONCAT_WS(' ', c.First_Name, c.Last_Name)
    END AS Primary_Contact_Name,

    c.Email AS Primary_Contact_Email

FROM crm_assessment.vw_school_club_summary s

LEFT JOIN crm_assessment.Contact c
    ON s.School_Id = c.School_Id
   AND c.Is_Primary_Contact = 1;



-- Verify View 4: Top 10 Schools

SELECT
    School_Id,
    School_Name,
    Total_Clubs,
    Confirmed_Clubs,
    Known_Students_Served,
    Primary_Contact_Name
FROM crm_assessment.vw_top_schools

ORDER BY Known_Students_Served DESC,
         School_Name ASC
LIMIT 10;



-- VIEW 5: Schools With Contacts But No Clubs
-- Identify schools that have contacts
-- but no club records.

CREATE OR REPLACE VIEW
crm_assessment.vw_schools_contacts_no_clubs AS

SELECT
    s.School_Id,
    s.School_Name,
    COALESCE(s.School_Type, 'Unknown') AS School_Type,
    s.Partnership_Status,
    s.Relationship_Owner,

    (
        SELECT COUNT(*)
        FROM crm_assessment.Contact c
        WHERE c.School_Id = s.School_Id
    ) AS Total_Contacts,

    COALESCE(
        (
            SELECT CONCAT_WS(' ', c.First_Name, c.Last_Name)
            FROM crm_assessment.Contact c
            WHERE c.School_Id = s.School_Id
              AND c.Is_Primary_Contact = 1
            ORDER BY c.Contact_Id
            LIMIT 1
        ),
        'Not Available'
    ) AS Primary_Contact_Name

FROM crm_assessment.School s

WHERE EXISTS (
    SELECT 1
    FROM crm_assessment.Contact c
    WHERE c.School_Id = s.School_Id
)

AND NOT EXISTS (
    SELECT 1
    FROM crm_assessment.Club cl
    WHERE cl.School_Id = s.School_Id
);


-- Count schools with contacts but no clubs

SELECT COUNT(*) AS Schools_With_Contacts_No_Clubs
FROM crm_assessment.vw_schools_contacts_no_clubs;

-- Inspect the schools

SELECT *
FROM crm_assessment.vw_schools_contacts_no_clubs
ORDER BY Total_Contacts DESC, School_Name;




-- VIEW 6: School Deliverable Workload
-- Show deliverable counts and status by school.
-- Include schools with zero clubs or deliverables.

CREATE OR REPLACE VIEW
crm_assessment.vw_school_deliverable_workload AS

SELECT
    s.School_Id,
    s.School_Name,
    COALESCE(s.School_Type, 'Unknown') AS School_Type,
    s.Partnership_Status,

    COUNT(DISTINCT c.Club_Id) AS Total_Clubs,

    COUNT(d.Deliverable_Id) AS Total_Deliverables,

    SUM(
        CASE WHEN d.Status = 'Completed'
        THEN 1 ELSE 0 END
    ) AS Completed_Deliverables,

    SUM(
        CASE WHEN d.Status = 'In Progress'
        THEN 1 ELSE 0 END
    ) AS In_Progress_Deliverables,

    SUM(
        CASE WHEN d.Status = 'Not Started'
        THEN 1 ELSE 0 END
    ) AS Not_Started_Deliverables,

    SUM(
        CASE WHEN d.Status = 'Blocked'
        THEN 1 ELSE 0 END
    ) AS Blocked_Deliverables,

    SUM(
        CASE
            WHEN d.Due_Date < CURDATE()
             AND d.Status <> 'Completed'
            THEN 1 ELSE 0
        END
    ) AS Overdue_Deliverables

FROM crm_assessment.School s

LEFT JOIN crm_assessment.Club c
    ON s.School_Id = c.School_Id

LEFT JOIN crm_assessment.Deliverable d
    ON c.Club_Id = d.Club_Id

GROUP BY
    s.School_Id,
    s.School_Name,
    s.School_Type,
    s.Partnership_Status;



-- Verify View 6: School Deliverable Workload

SELECT
    COUNT(*) AS Total_Schools,
    SUM(Total_Clubs) AS Total_Clubs,
    SUM(Total_Deliverables) AS Total_Deliverables,
    SUM(Overdue_Deliverables) AS Overdue_Deliverables
FROM crm_assessment.vw_school_deliverable_workload;




-- VIEW 7: Deliverable Status Summary
-- Count deliverables by status and overdue condition.

CREATE OR REPLACE VIEW
crm_assessment.vw_deliverable_status_summary AS

SELECT
    Status,

    COUNT(*) AS Total_Deliverables,

    SUM(
        CASE
            WHEN Due_Date < CURDATE()
             AND Status <> 'Completed'
            THEN 1
            ELSE 0
        END
    ) AS Overdue_Deliverables

FROM crm_assessment.Deliverable

GROUP BY Status;


-- Verify View 7

SELECT *
FROM crm_assessment.vw_deliverable_status_summary
ORDER BY Total_Deliverables DESC;



-- Check all overdue totals on the same date

SELECT
    CURDATE() AS Report_Date,

    (SELECT COUNT(*)
     FROM crm_assessment.vw_overdue_deliverables)
        AS Overdue_View_2,

    (SELECT SUM(Overdue_Deliverables)
     FROM crm_assessment.vw_school_deliverable_workload)
        AS Overdue_View_6,

    (SELECT SUM(Overdue_Deliverables)
     FROM crm_assessment.vw_deliverable_status_summary)
        AS Overdue_View_7;




-- STEP 38: Export School Deliverable Workload

SELECT *
FROM crm_assessment.vw_school_deliverable_workload
ORDER BY School_Id;




-- STEP 49A: Export Student Participation Data
-- Includes student counts and primary contacts.

SELECT
    School_Id,
    School_Name,
    School_Type,
    Total_Clubs,
    Confirmed_Clubs,
    Known_Students_Served,
    Confirmed_Clubs_Missing_Count,
    Primary_Contact_Name
FROM crm_assessment.vw_top_schools
ORDER BY School_Id;
