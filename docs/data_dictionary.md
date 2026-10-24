
# JerseySTEM DATA101 — Data Dictionary

## Entity 1: School

**Description:** Stores information about schools participating in, previously involved with, or being considered for JerseySTEM programs.

| Column | Proposed Data Type | Key | Nullable | Description |
|---|---|---|---|---|
| School_Id | VARCHAR(20) | PK | No | Unique identifier for each school |
| School_Name | VARCHAR(200) | | No | Name of the school |
| School_Type | VARCHAR(30) | | No | Public, Charter, Private, or Magnet |
| State | VARCHAR(30) | | No | State where the school is located |
| Zip | VARCHAR(10) | | No | Postal ZIP code, stored as text to preserve leading zeros |
| Enrollment | INT | | Review | Number of students enrolled; should be positive when provided |
| Partnership_Status | VARCHAR(30) | | No | Active Partner, Prospect, or Alumni |
| Relationship_Owner | VARCHAR(100) | | Review | JerseySTEM staff member responsible for the school |
| Created_Date | DATE | | Review | Date the school was added to the system |

**Primary Key:** School_Id

**Business Rules:**
- Each school must have a unique identifier.
- School type must be one of the allowed categories.
- Enrollment must not be negative or zero when recorded.
- Every school must have exactly one primary contact.
- ZIP codes must be stored as strings to preserve leading zeros.

**Notes:** These are proposed types and target rules. Actual ID formats, missing-value requirements, and date formats must be confirmed from the CSV records before finalizing the MySQL schema.




---

## Entity 2: Contact

**Description:** Stores information about individuals associated with each school.

| Column | Proposed Data Type | Key | Nullable | Description |
|---|---|---|---|---|
| Contact_Id | VARCHAR(20) | PK | No | Unique identifier for each contact |
| School_Id | VARCHAR(20) | FK | No | References School.School_Id |
| First_Name | VARCHAR(100) | | Review | Contact's first name |
| Last_Name | VARCHAR(100) | | Review | Contact's last name |
| Email | VARCHAR(254) | | Review | Contact's email address |
| Phone | VARCHAR(30) | | Review | Contact's phone number |
| Title | VARCHAR(100) | | Review | Contact's job title |
| Department | VARCHAR(100) | | Review | Department within the school |
| Is_Primary_Contact | BOOLEAN | | No | Indicates whether the contact is the school's primary contact |
| Created_Date | DATE | | Review | Date the contact was added |

**Primary Key:** Contact_Id

**Foreign Key:** School_Id references School.School_Id

**Relationship:** One School can have many Contacts, but each Contact belongs to exactly one School.

**Business Rules:**
- Every contact must reference an existing school.
- Each school must have exactly one primary contact.
- Email addresses should be checked for invalid formats.
- Phone numbers should be checked for inconsistent or invalid formats.
- Duplicate contact records should be identified.
- A club's lead contact must belong to the same school as the club.

**Notes:** Data types and nullable fields are provisional until the CSV data is inspected. BOOLEAN is represented by TINYINT(1) in MySQL.




---

## Entity 3: Club

**Description:** Stores information about STEM clubs associated with schools, including their progress, student participation, and assigned contacts.

| Column | Proposed Data Type | Key | Nullable | Description |
|---|---|---|---|---|
| Club_Id | VARCHAR(20) | PK | No | Unique identifier for each club |
| School_Id | VARCHAR(20) | FK | No | References School.School_Id |
| Club_Name | VARCHAR(200) | | No | Name of the STEM club |
| Stage | VARCHAR(30) | | No | Current stage of the club |
| Students_Served | INT | | Review | Number of students served by the club |
| Close_Date | DATE | | Review | Date field from the raw export; business meaning requires confirmation |
| Primary_Contact_Id | VARCHAR(20) | FK | Review | References Contact.Contact_Id |
| Owner | VARCHAR(100) | | Review | JerseySTEM staff member responsible for the club |
| Created_Date | DATE | | Review | Date the club record was created |

**Primary Key:** Club_Id

**Foreign Keys:**
- School_Id references School.School_Id
- Primary_Contact_Id references Contact.Contact_Id

**Relationships:**
- One School can have multiple Clubs.
- Each Club belongs to exactly one School.
- Each Club has a lead Contact who must belong to the same School.

**Business Rules:**
- Every club must have a unique Club_Id.
- Every club must reference an existing school.
- Stage must be one of:
  - Prospecting
  - Qualification
  - Proposal
  - Negotiation
  - Closed Won
  - Closed Lost
- Students_Served must be checked for invalid or negative values.
- A club's lead contact must belong to the same school as the club.
- Dates must be checked for invalid or inconsistent formats.

**Notes:**
- The assignment conversation describes an expected start date, while the CSV uses Close_Date. This difference requires clarification or a documented assumption.
- Data types and nullable fields are provisional until the raw values have been inspected.
- Closed Won indicates a confirmed club; Closed Lost indicates a club that did not proceed.




---

## Entity 4: Deliverable

**Description:** Stores work items associated with STEM clubs, including their type, status, due date, completion date, quantity, and assigned person.

| Column | Proposed Data Type | Key | Nullable | Description |
|---|---|---|---|---|
| Deliverable_Id | VARCHAR(20) | PK | No | Unique identifier for each deliverable |
| Club_Id | VARCHAR(20) | FK | No | References Club.Club_Id |
| Deliverable_Name | VARCHAR(200) | | No | Name of the work item |
| Deliverable_Type | VARCHAR(30) | | No | Type of work being performed |
| Status | VARCHAR(30) | | No | Current progress of the deliverable |
| Due_Date | DATE | | Review | Deadline for completing the work item |
| Completed_Date | DATE | | Yes | Completion date; must be NULL if not completed |
| Quantity | INT | | Review | Number of units associated with the deliverable |
| Assigned_To | VARCHAR(100) | | Review | Person responsible for the work item |

**Primary Key:** Deliverable_Id

**Foreign Key:** Club_Id references Club.Club_Id

**Relationship:**
- One Club can have multiple Deliverables.
- Each Deliverable belongs to exactly one Club.

**Business Rules:**
- Every deliverable must have a unique Deliverable_Id.
- Every deliverable must reference an existing club.
- Deliverable_Type must be one of:
  - Report
  - Workshop
  - Installation
  - Training
  - Assessment
- Status must be one of:
  - Not Started
  - In Progress
  - Completed
  - Blocked
- Completed_Date must be NULL when Status is not Completed.
- A Completed deliverable should have a valid completion date; missing dates should be investigated.
- Quantity should be a positive integer when provided.
- Dates must be checked for invalid or inconsistent formats.
- An overdue deliverable has a Due_Date earlier than the reporting date and Status other than Completed.

**Notes:**
- Completed_Date is nullable because unfinished deliverables do not have a completion date.
- The dataset may contain inconsistent statuses, invalid dates, and broken club references that require diagnosis before cleanup.
- Data types and nullable requirements are provisional until the actual CSV values have been inspected.