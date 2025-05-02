-- Looking forward to using variations of this for multiple projects
WITH
student AS (
    SELECT * FROM Students WHERE ID = :studentid
),

-- split stored grade credit type into separate rows (for easier joining)
stored_grades_credit_types AS (
    SELECT DCID, xmlcast(column_value as varchar2(4000)) credit_type
    , ROW_NUMBER() OVER (PARTITION BY DCID, credit_types ORDER BY DCID) sg_dcid_row
    , Grade_Level
    , EarnedCrHrs
    , StoreCode
    , TermID
    , Course_Number
    , Course_Name
    FROM (
        SELECT StoredGrades.DCID, '"' || REPLACE(StoredGrades.Credit_Type, ',', '","') || '"' credit_types
        , student.ID
        , StoredGrades.Grade_level
        , StoredGrades.EarnedCrHrs
        , StoredGrades.StoreCode
        , StoredGrades.TermID
        , StoredGrades.Course_Number
        , StoredGrades.Course_Name
        FROM StoredGrades, student
        WHERE student.ID = StoredGrades.StudentID
    ) x, xmltable(x.credit_types)
),
-- split cc credit type into separate rows (for easier joining)
cc_credit_types AS (
    SELECT DCID, xmlcast(column_value as varchar2(4000)) credit_type
    FROM (
        SELECT CC.DCID, '"'||REPLACE(Courses.CreditType, ',', '","')||'"' credit_types
        FROM CC, Courses, student
        WHERE CC.Course_Number = Courses.Course_Number AND student.ID = CC.StudentID
    ) x, xmltable(x.credit_types)
),

gp_node_tree AS (
    SELECT ROWNUM "row_num"
         , node.GPVersionID
         , LEVEL "level"
         , node.SortOrder
         , node.ID
         , node.ParentID
         , node.NodeType
    FROM GPNode node
    START WITH node.ParentID IS NULL
    CONNECT BY PRIOR node.ID = node.ParentID
    ORDER SIBLINGS BY node.SortOrder
),

gp AS (
    SELECT RPAD(' ', (gp_node_tree."level"-1)*2, ' ') || GPNode.Name node_name
      , GPStudentPlan.StudentID
          , gp_node_tree.ID node_tree_id
          , gp_node_tree.NodeType
          , gp_node_tree."level"
          , gp_node_tree."row_num"
          , gp_node_tree.GPVersionID
          , GPStudentPlan.SortOrder splan_sortorder
          , GPTarget.SortOrder tgt_sortorder
          , GPSelector.SortOrder selector_sortorder
          , GPSelectedCrType.CreditType gp_credit_type
    FROM gp_node_tree
    JOIN GPNode ON GPNode.ID = gp_node_tree.ID
    JOIN GPStudentPlan ON GPStudentPlan.GPVersionID = gp_node_tree.GPVersionID
    JOIN student ON student.ID = GPStudentPlan.StudentID
    LEFT OUTER JOIN GPSelector ON GPSelector.GPVersionID = GPNode.GPVersionID
    JOIN GPTarget ON GPSelector.ID = GPTarget.GPSelectorID AND GPTarget.GPNodeID = gp_node_tree.ID
    LEFT OUTER JOIN GPSelectedCrType ON GPSelectedCrType.GPSelectorID = GPSelector.ID
    WHERE gp_node_tree.GPVersionID IN (10052, 10252, 10203, 10303, 10152, 10102, 10202, 10302, 10352)
    ORDER BY gp_node_tree."row_num", GPTarget.SortOrder,  GPSelector.SortOrder
)
SELECT Students.Student_Number, Students.LastFirst 
  , StoredGrades.StudentID
  , StoredGrades.SchoolID
  , gp.node_name
  , gp.node_tree_id
  , gp.NodeType
  , gp."row_num"
  , gp."level"
  , gp.splan_sortorder
  , gp.tgt_sortorder
  , gp.gp_credit_type
  , sgct.credit_type
  , sgct.Grade_level
  , sgct.EarnedCrHrs
  , sgct.sg_dcid_row
  , sgct.DCID sgct_dcid
  , sgct.StoreCode
  , sgct.TermID
  , sgct.Course_Number
  , sgct.Course_Name
FROM StoredGrades
JOIN stored_grades_credit_types sgct ON StoredGrades.DCID = sgct.DCID
JOIN Students ON Students.ID = StoredGrades.StudentID
JOIN gp ON Students.ID = gp.StudentID AND sgct.credit_type = gp.gp_credit_type
WHERE StoredGrades.DCID = sgct.DCID
AND gp.tgt_sortorder = 1
AND sgct.sg_dcid_row = 1
ORDER BY sgct.DCID
