-- Would rather not have had to use som many hard coded values.
WITH STS AS (
SELECT StudentTest.Test_date
  , TestScore.NAME TestScore_Name
  , CASE
    WHEN REGEXP_REPLACE(TestScore.Name, CHR(94) || 'a-zA-Z0-9' || CHR(93)) = 'Sem Adjust Subscale(VQ) SAS' AND StudentTestScore.NumScore > 119 THEN 'Certified by CogAT Abilities'
    WHEN REGEXP_REPLACE(TestScore.Name, CHR(94) || 'a-zA-Z0-9' || CHR(93)) = 'Sem Adjust Subscale(VN) SAS' AND StudentTestScore.NumScore > 119 THEN 'Certified  by CogAT Abilities'
    WHEN REGEXP_REPLACE(TestScore.NAME, CHR(94) || 'a-zA-Z0-9' || CHR(93)) = 'Sem Adjust Subscale(QN) SAS' AND StudentTestScore.NumScore > 119 THEN 'Certified by CogAT Abilities'
    WHEN REGEXP_REPLACE(TestScore.Name, CHR(94) || 'a-zA-Z0-9' || CHR(93)) = 'Sem Adjust Composite(VQN) SAS' AND StudentTestScore.NumScore > 119 THEN 'Certified by  CogAT Abilities'
    WHEN REGEXP_REPLACE(TestScore.Name, CHR(94) || 'a-zA-Z0-9' || CHR(93)) = 'OTIS_SEM_ADJUST_ABILITY_INDEX' AND StudentTestScore.NumScore > 119 THEN 'Certified  OLSAT (Otis-Lennon)'
    WHEN REGEXP_REPLACE(TestScore.Name, CHR(94) || 'a-zA-Z0-9' || CHR(93)) = 'NAGLIERI_SEM_ADJUST_ABILITY_INDEX' AND StudentTestScore.NumScore > 119 THEN 'Certified  by NNAT3 (Naglieri)'
    ELSE 'Achievement'
  END CERTIFIED_BY
  , StudentTest.Grade_Level sts_grade_level
  , StudentTestScore.NumScore sts_numscore
  , CASE WHEN StudentTestScore.NumScore >= 121 THEN 'Automatic' ELSE 'Partial' END score_status
  , ROW_NUMBER() OVER (PARTITION BY StudentTest.StudentID ORDER BY StudentTest.StudentID) rn
  , Students.DCID
FROM Test
  INNER JOIN StudentTest
  ON Test.ID = StudentTest.TestID
  LEFT JOIN Students ON StudentTest.StudentID = Students.ID
  INNER JOIN StudentTestScore
  ON StudentTest.StudentID = StudentTestScore.StudentID
  INNER JOIN TestScore
  ON TestScore.ID = StudentTestScore.TestScoreID
WHERE Students.SchoolID != '999999'
  AND (TestScore.Name = 'NAGLIERI_SEM_ADJUST_ABILITY_INDEX'
  OR TestScore.Name = 'OTIS_SEM_ADJUST_ABILITY_INDEX'
  OR TestScore.Name = 'Sem Adjust Subscale(VQ) SAS'
  OR TestScore.Name = 'Sem Adjust Subscale(VN) SAS'
  OR TestScore.Name = 'Sem Adjust Subscale(QN) SAS'
  OR TestScore.Name = 'Sem Adjust Composite(VQN) SAS')
  AND StudentTestScore.NumScore > 119
  ORDER BY StudentTest.StudentID, TestScore.Name
),
stud AS (
SELECT s.Student_Number
  , s.LastFirst
  , s.First_Name
  , s.Middle_Name
  , s.Last_Name
  , s.ID
  , s.DCID stud_dcid
  , s.Grade_Level
  , s.SchoolID
  ,(SELECT LISTAGG (RACECD, ', ') WITHIN GROUP (ORDER BY RACECD)
                FROM STUDENTRACE sr
                WHERE sr.STUDENTID = s.ID
                ) AS RACECD
  , (SELECT Schools.Name FROM Schools WHERE Schools.School_Number = s.SchoolID) AS School_Name
  , DECODE(s.Enroll_Status, 0, 'Active', 2, 'Inactive', 3, 'Graduated', -1, 'Pre-Registered') AS Enroll_Status
  , s.Gender
  , sx.GiftedTalentedIdentified
  , sx.Ell
  , sx.Gifted
  , sx.HomelessMckinneyVento
  , sx.IDEA
  , sx.Section504
FROM Students s
JOIN S_OK_STU_X sx ON s.DCID = sx.StudentsDCID

)

SELECT stud.*
  , STS.TestScore_Name
  , STS.sts_grade_level
  , STS.certified_by
  , STS.sts_numscore
  , STS.score_status
FROM STS
JOIN stud ON STS.DCID = stud.stud_dcid
WHERE STS.rn = 1
AND STS.sts_numscore > 119

UNION ALL

SELECT stud.*
  , NULL
  , NULL
  , U_StudentsUserFields.TPS_Gift_Talent_Cert
  , NULL
  , NULL
FROM Students s
JOIN stud ON s.DCID = stud.stud_dcid
JOIN S_OK_STU_X ON s.DCID = S_OK_STU_X.StudentsDCID
LEFT JOIN U_StudentsUserFields ON s.DCID = U_StudentsUserFields.StudentsDCID
WHERE s.Enroll_Status = 0
AND s.SchoolID != '999999' 
AND (S_OK_STU_X.Gifted = 'YES'  
OR LOWER(U_StudentsUserFields.TPS_Gift_Talent_Cert) = 'achievement')
AND s.DCID NOT IN (SELECT STS.DCID FROM STS)
  ;
