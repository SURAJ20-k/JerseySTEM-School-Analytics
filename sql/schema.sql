
-- JerseySTEM DATA101 2 - School Analytics
-- Database Schema

USE crm_assessment;

-- Table 1: School
CREATE TABLE IF NOT EXISTS School (
    School_Id VARCHAR(20) PRIMARY KEY,
    School_Name VARCHAR(200),
    School_Type VARCHAR(30),
    State VARCHAR(10),
    Zip VARCHAR(10),
    Enrollment INT,
    Partnership_Status VARCHAR(30),
    Relationship_Owner VARCHAR(100),
    Created_Date DATE
);

-- Verify that the table was created
SHOW TABLES;

-- Inspect the table structure
DESCRIBE School;




-- Table 2: Contact
-- Stores contacts associated with JerseySTEM schools

CREATE TABLE IF NOT EXISTS Contact (
    Contact_Id VARCHAR(20) PRIMARY KEY,
    School_Id VARCHAR(20),
    First_Name VARCHAR(100),
    Last_Name VARCHAR(100),
    Email VARCHAR(254),
    Phone VARCHAR(30),
    Title VARCHAR(100),
    Department VARCHAR(100),
    Is_Primary_Contact TINYINT(1),
    Created_Date DATE
);




-- Table 3: Club
-- Stores STEM club information

USE crm_assessment;

CREATE TABLE IF NOT EXISTS Club (
    Club_Id VARCHAR(20) PRIMARY KEY,
    School_Id VARCHAR(20),
    Club_Name VARCHAR(200),
    Stage VARCHAR(30),
    Students_Served INT,
    Close_Date DATE,
    Primary_Contact_Id VARCHAR(20),
    Owner VARCHAR(100),
    Created_Date DATE
);

-- Verify the table
DESCRIBE Club;




-- Table 4: Deliverable
-- Stores work items associated with STEM clubs

USE crm_assessment;

CREATE TABLE IF NOT EXISTS Deliverable (
    Deliverable_Id VARCHAR(20) PRIMARY KEY,
    Club_Id VARCHAR(20),
    Deliverable_Name VARCHAR(200),
    Deliverable_Type VARCHAR(30),
    Status VARCHAR(30),
    Due_Date DATE,
    Completed_Date DATE NULL,
    Quantity INT,
    Assigned_To VARCHAR(100)
);

-- Verify the table structure
DESCRIBE Deliverable;

-- Verify all tables
SHOW TABLES;




-- STEP 30A: Add Foreign Key from Contact to School
-- Every contact's School_Id must reference
-- an existing School record.

ALTER TABLE crm_assessment.Contact
ADD CONSTRAINT fk_contact_school
FOREIGN KEY (School_Id)
REFERENCES crm_assessment.School(School_Id);


-- Verify Contact foreign key

SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'crm_assessment'
  AND TABLE_NAME = 'Contact'
  AND REFERENCED_TABLE_NAME IS NOT NULL;



-- STEP 30B: Add Foreign Key from Club to School
-- Every club must belong to an existing school.

ALTER TABLE crm_assessment.Club
ADD CONSTRAINT fk_club_school
FOREIGN KEY (School_Id)
REFERENCES crm_assessment.School(School_Id);


-- Verify Club to School foreign key

SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'crm_assessment'
  AND TABLE_NAME = 'Club'
  AND CONSTRAINT_NAME = 'fk_club_school';



-- STEP 30C: Enforce Club Lead Contact Relationship
-- Each club's lead contact must belong to
-- the same school as the club.

-- First, create a unique index on the parent table.
ALTER TABLE crm_assessment.Contact
ADD CONSTRAINT uq_contact_school_contact
UNIQUE (School_Id, Contact_Id);

-- Next, create the composite foreign key.
ALTER TABLE crm_assessment.Club
ADD CONSTRAINT fk_club_school_contact
FOREIGN KEY (School_Id, Primary_Contact_Id)
REFERENCES crm_assessment.Contact
    (School_Id, Contact_Id);


-- Verify the composite Club to Contact foreign key.

SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'crm_assessment'
  AND TABLE_NAME = 'Club'
  AND CONSTRAINT_NAME = 'fk_club_school_contact'
ORDER BY ORDINAL_POSITION;





-- STEP 30D: Add Foreign Key from Deliverable to Club
-- Every deliverable must reference an existing club.

ALTER TABLE crm_assessment.Deliverable
ADD CONSTRAINT fk_deliverable_club
FOREIGN KEY (Club_Id)
REFERENCES crm_assessment.Club(Club_Id);


-- Verify Deliverable to Club foreign key

SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'crm_assessment'
  AND TABLE_NAME = 'Deliverable'
  AND CONSTRAINT_NAME = 'fk_deliverable_club';

