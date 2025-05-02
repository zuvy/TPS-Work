WITH sg AS (
  SELECT StoredGrades.StudentID
  , StoredGrades.Grade_Level
  , StoredGrades.EarnedCrHrs
  , StoredGrades.Credit_Type
  FROM StoredGrades
  JOIN Students ON StoredGrades.StudentID = Students.ID
  WHERE StoredGrades.DateStored > TO_DATE('08/16/2017', 'MM/DD/YYYY')
  AND Students.Grade_level BETWEEN 6 AND 13
  AND StoredGrades.Credit_Type IS NOT NULL
),
cb_grade_levels AS (
  SELECT DISTINCT
    sg.StudentID
    , Students.Grade_Level
    , SUM(CASE WHEN sg.Grade_Level BETWEEN 6 AND 8 THEN sg.EarnedCrHrs ELSE 0 END) OVER (PARTITION BY sg.StudentID) AS cr_ms
    , SUM(CASE WHEN sg.Grade_Level BETWEEN 6 AND 9 THEN sg.EarnedCrHrs ELSE 0 END) OVER (PARTITION BY sg.StudentID) AS cr_9
    , SUM(CASE WHEN sg.Grade_Level BETWEEN 6 AND 10 THEN sg.EarnedCrHrs ELSE 0 END) OVER (PARTITION BY sg.StudentID) AS cr_10
    , SUM(CASE WHEN sg.Grade_Level BETWEEN 6 AND 11 THEN sg.EarnedCrHrs ELSE 0 END) OVER (PARTITION BY sg.StudentID) AS cr_11
    , SUM(CASE WHEN sg.Grade_Level BETWEEN 6 AND 13 THEN sg.EarnedCrHrs ELSE 0 END) OVER (PARTITION BY sg.StudentID) AS cr_12
    , SUM(sg.EarnedCrHrs) OVER (PARTITION BY sg.StudentID) AS total_earned_cr_hrs
  FROM sg
  JOIN Students ON Students.ID = sg.StudentID
),
cb_grade AS (
  SELECT DISTINCT
    sg.StudentID cbg_student_id,
    sg.Grade_Level cbg_grade_level,
    cbl.cr_ms,
    cbl.cr_9,
    cbl.cr_10,
    cbl.cr_11,
    cbl.cr_12,
    CASE
      WHEN cbl.total_earned_cr_hrs <= 6 THEN 9
      WHEN cbl.total_earned_cr_hrs >= 6.01 AND cbl.total_earned_cr_hrs <= 12 THEN 10
      WHEN cbl.total_earned_cr_hrs >= 12.01 AND cbl.total_earned_cr_hrs <= 17 THEN 11
      WHEN cbl.total_earned_cr_hrs >= 17.01 THEN 12
      ELSE NULL
    END AS cb_grade,
    ROW_NUMBER() OVER (PARTITION BY sg.StudentID ORDER BY sg.StudentID ASC) AS rn
  FROM cb_grade_levels cbl
  JOIN sg ON sg.StudentID = cbl.StudentID
)
SELECT Students.LastFirst
  , Students.Student_Number
  , Students.DCID
  , Students.ID
  , Students.Grade_Level
  , CASE WHEN cb_grade.cb_grade > Students.Grade_Level THEN Students.Grade_Level ELSE cb_grade.cb_grade END cb_grade_level
  , cb_grade.cr_ms
  , CASE WHEN Students.Grade_Level >= 9 THEN cb_grade.cr_9 ELSE NULL END AS cr_9
  , CASE WHEN Students.Grade_Level >= 10 THEN cb_grade.cr_10 ELSE NULL END AS cr_10
  , CASE WHEN Students.Grade_Level >= 11 THEN cb_grade.cr_11 ELSE NULL END AS cr_11
  , CASE WHEN Students.Grade_Level >= 12 THEN cb_grade.cr_12 ELSE NULL END AS cr_12
  , (SELECT Schools.Name FROM Schools WHERE Schools.School_Number = Students.SchoolID) AS School_Name
  , DECODE(Students.Enroll_Status, 0, 'Active', 2, 'Inactive', 3, 'Graduated', -1, 'Pre-Registered') AS Enrollment_Status
  , cb_grade.rn
FROM cb_grade
JOIN Students ON Students.ID = cb_grade.cbg_student_id
WHERE Students.Grade_Level BETWEEN 9 AND 13
AND cb_grade.rn = 1
;