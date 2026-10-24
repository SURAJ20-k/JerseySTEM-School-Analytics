
USE crm_assessment;

-- Raw staging table for School.csv
-- Keep original values as text before cleaning

CREATE TABLE IF NOT EXISTS School_raw (
    Raw_Row_Id INT AUTO_INCREMENT PRIMARY KEY,
    School_Id VARCHAR(255),
    School_Name VARCHAR(255),
    School_Type VARCHAR(255),
    State VARCHAR(255),
    Zip VARCHAR(255),
    Enrollment VARCHAR(255),
    Partnership_Status VARCHAR(255),
    Relationship_Owner VARCHAR(255),
    Created_Date VARCHAR(255)
);

SHOW TABLES;




-- Raw staging table for Contact.csv

CREATE TABLE IF NOT EXISTS Contact_raw (
    Raw_Row_Id INT AUTO_INCREMENT PRIMARY KEY,
    Contact_Id VARCHAR(255),
    School_Id VARCHAR(255),
    First_Name VARCHAR(255),
    Last_Name VARCHAR(255),
    Email VARCHAR(255),
    Phone VARCHAR(255),
    Title VARCHAR(255),
    Department VARCHAR(255),
    Is_Primary_Contact VARCHAR(255),
    Created_Date VARCHAR(255)
);
