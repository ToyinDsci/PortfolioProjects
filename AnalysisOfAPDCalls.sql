-- CREATE A VIEW OF ALL ROWS EXCEPT ROWS WITH NO INCIDENT NUMBER
--DROP VIEW APDCALLSVIEW
CREATE VIEW APDCALLSVIEW AS 
	SELECT * FROM APDCALLS 
	WHERE Incident_Number LIKE '2%'; 

/* What is the total number of incidents that occurred in each sector?*/
SELECT Sector, Count(*) AS TotalIncidents FROM APDCALLSVIEW
GROUP BY Sector
ORDER BY TotalIncidents DESC;

/*What are the top 5 busiest geographic areas in terms of 911 calls, and what is the average response time for each of these areas?*/
SELECT TOP 5 Census_Block_Group, AVG(Response_time) AS AvgResponseTime, COUNT(*) AS TotalIncidents
FROM APDCALLSVIEW
GROUP BY Census_Block_Group
ORDER BY TotalIncidents DESC,AvgResponseTime;

/*Identify sectors where mental health-related incidents make up more than 30% of the total incidents.*/
WITH IncidentsCounts AS (
	SELECT Sector, COUNT(*) AS Total_Incidents, SUM(CASE WHEN Mental_Health_Flag = 'Mental Health Incident' THEN 1 ELSE 0 END) AS Mental_Health_Incidents,
		SUM(CASE WHEN Mental_Health_Flag = 'Not Mental Health Incident' THEN 1 ELSE 0 END) AS Not_Mental_Health_Incidents
	FROM APDCALLSVIEW
	GROUP BY Sector
)
SELECT 
	Sector, Total_Incidents, Mental_Health_Incidents
FROM IncidentsCounts 
WHERE CAST(Mental_Health_Incidents AS FLOAT)/Total_Incidents > 0.30
ORDER BY Total_Incidents, Mental_Health_Incidents;

/*	What are the busiest days of the week, and how do the types of incidents differ across those days?*/
SELECT Incident_Type,Mental_Health_Flag,Response_Day_of_Week, COUNT(*) AS TotalIncidents
FROM APDCALLSVIEW
GROUP BY Incident_Type,Mental_Health_Flag, Response_Day_of_Week
ORDER BY TotalIncidents DESC;

/*	What is the average response time for all incidents involving mental health issues?*/
SELECT COUNT(*) AS TotalMentalHealthIncidents, AVG(Response_time) AS AvgResponseTime
FROM APDCALLSVIEW
WHERE Mental_Health_Flag = 'Mental Health Incident';


/*	Which types of incidents have response times that are above the overall average response time?*/
WITH OverallAverage AS (
    SELECT 
        AVG(CAST(Response_Time AS BIGINT)) AS Overall_Avg_Response_Time
    FROM 
        APDCALLSVIEW
),
IncidentTypeAverage AS (
    SELECT 
        Mental_Health_Flag,
        AVG(CAST(Response_Time AS BIGINT)) AS Incident_Avg_Response_Time
    FROM 
        APDCALLSVIEW
    GROUP BY 
        Mental_Health_Flag
)
SELECT 
    ita.Mental_Health_Flag,
    ita.Incident_Avg_Response_Time,
    oa.Overall_Avg_Response_Time
FROM 
    IncidentTypeAverage ita
JOIN 
    OverallAverage oa ON 1=1 -- Cross join to include the overall average in each row
WHERE 
    ita.Incident_Avg_Response_Time > oa.Overall_Avg_Response_Time
ORDER BY 
    ita.Incident_Avg_Response_Time DESC;




/*	Find the geographic areas where the average number of units dispatched is greater than the average number of units dispatched 
across all areas.*/

WITH OverallAverage AS (
	SELECT AVG(Number_of_Units_Arrived) AS AvgUnitDispatched FROM APDCALLSVIEW 
),

GeoAverage AS (
	SELECT Census_Block_Group, AVG(Number_of_Units_Arrived) AS AvgUnitDispatched
	FROM APDCALLSVIEW
	GROUP BY Census_Block_Group
)
SELECT 
	GA.Census_Block_Group, GA.AvgUnitDispatched
FROM GeoAverage GA
JOIN
	OverallAverage OA ON 1=1
WHERE GA.AvgUnitDispatched > OA.AvgUnitDispatched
ORDER BY GA.AvgUnitDispatched DESC;


/*	Which sectors have the highest percentage of reclassified calls (where the final problem description differs from the initial one)?*/
WITH TotalSectorCalls AS (
	SELECT Sector, COUNT(*) AS TotalCalls FROM APDCALLSVIEW 
	GROUP BY Sector
),
ReClassifiedCallsTotal AS (
	SELECT Sector, COUNT(*) AS ReclassifiedCallCount FROM APDCALLSVIEW
	WHERE Initial_Problem_Description != Final_Problem_Description
	GROUP BY Sector
)
SELECT TC.Sector, (CAST(RC.ReclassifiedCallCount AS FLOAT)/TC.TotalCalls) * 100 AS RecCallPercent
FROM TotalSectorCalls TC
JOIN ReClassifiedCallsTotal RC ON TC.Sector=RC.Sector
ORDER BY RecCallPercent DESC; 


/*	What is the cumulative number of calls throughout each day, and how does this cumulative total change by sector?*/
--Cumulative total call by day
WITH DailyCumulative AS (
    SELECT 
        CAST(Response_Datetime AS DATE) AS CallDate,
        COUNT(*) OVER (PARTITION BY CAST(Response_Datetime AS DATE) ORDER BY Response_Hour ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cumulative_Calls,
        ROW_NUMBER() OVER (PARTITION BY CAST(Response_Datetime AS DATE) ORDER BY Response_Hour DESC) AS Row_Num
    FROM APDCALLSVIEW
)
SELECT 
    CallDate, Cumulative_Calls
FROM DailyCumulative
WHERE Row_Num = 1
ORDER BY CallDate;

  
--Cumulative total call by sector
WITH SectorDailyCumulative AS (
    SELECT 
        CAST(Response_Datetime AS DATE) AS CallDate, Sector,
        COUNT(*) OVER (PARTITION BY CAST(Response_Datetime AS DATE),Sector ORDER BY Response_Hour ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cumulative_Calls,
        ROW_NUMBER() OVER (PARTITION BY CAST(Response_Datetime AS DATE) ORDER BY Response_Hour DESC) AS Row_Num
    FROM APDCALLSVIEW
)
SELECT 
    CallDate,Sector, Cumulative_Calls
FROM SectorDailyCumulative
WHERE Row_Num = 1
ORDER BY CallDate,Sector;


/*•	For each sector, rank the geographic areas by total number of 911 calls and show the response time for each area.*/
SELECT Sector, Census_Block_Group, 
	COUNT(*) AS TotalCalls,
	AVG(CAST(Response_Time AS BIGINT)) AS Avg_Response_Time,
    RANK() OVER (PARTITION BY Sector ORDER BY COUNT(*) DESC) AS Area_Rank
FROM APDCALLSVIEW
GROUP BY Sector, Census_Block_Group
ORDER BY Sector, Area_Rank; 

/*•	What are the most common types of incidents that occur between 10 PM and 6 AM?*/
--Priority level
SELECT Priority_Level, COUNT(*) AS TotalIncidents FROM APDCALLSVIEW
WHERE DATEPART(HOUR, Response_Datetime) >= 22 
    OR DATEPART(HOUR, Response_Datetime) < 6
GROUP BY Priority_Level
ORDER BY TotalIncidents DESC;
--Mental Health Flag
SELECT Mental_Health_Flag, COUNT(*) AS TotalIncidents FROM APDCALLSVIEW
WHERE DATEPART(HOUR, Response_Datetime) >= 22 
    OR DATEPART(HOUR, Response_Datetime) < 6
GROUP BY Mental_Health_Flag
ORDER BY TotalIncidents DESC;

/*•	What percentage of incidents required more than 3 units to be dispatched?*/
SELECT 
    (COUNT(CASE WHEN Number_of_Units_Arrived > 3 THEN 1 END) * 100.0 / COUNT(*)) AS Percentage_More_Than_3_Units
FROM 
    APDCALLSVIEW;

/*•	How do response times compare across different priorities for each type of incident?*/
SELECT 
	Priority_Level, Mental_Health_Flag, AVG(Response_time) AS AvgResponseTime
FROM APDCALLSVIEW
GROUP BY Priority_Level, Mental_Health_Flag
ORDER BY Priority_Level, Mental_Health_Flag,AvgResponseTime;


/*•	Which geographic areas have the highest number of incidents involving officer injuries or fatalities?*/
SELECT 
	Census_Block_Group, Count(*) AS TotalOfficerKilledInjured
FROM APDCALLSVIEW
WHERE Officer_Injured_Killed_Count >= 1
GROUP BY Census_Block_Group,Officer_Injured_Killed_Count
ORDER BY Officer_Injured_Killed_Count DESC;


/*•	Which council districts have the highest average response times?*/
SELECT 
	Council_District, AVG(Response_time) AS AvgResponseTime
FROM APDCALLSVIEW
GROUP BY Council_District
ORDER BY AvgResponseTime DESC;


/*•	How many incidents involve serious injury or death (either officers or subjects) related to mental health?*/
SELECT 
    COUNT(*) AS NumberOfIncidents
FROM 
    APDCALLSVIEW
WHERE 
    Mental_Health_Flag = 'Mental Health Incident' 
    AND (Officer_Injured_Killed_Count > 0 OR Subject_Injured_Killed_Count > 0);


/*•	Find the average response time for each incident type and compare it with the overall average response time.*/
--Using Mental Health Flag
WITH OverallAverageResponse AS (
	SELECT AVG(CAST(Response_time AS BIGINT)) AS OverallAvgResp FROM APDCALLSVIEW
),
IncidentType AS(
	SELECT Mental_Health_Flag, AVG(CAST(Response_time AS BIGINT)) AS AvgResponseTime
	FROM APDCALLSVIEW
	GROUP BY Mental_Health_Flag
)

SELECT I.Mental_Health_Flag, I.AvgResponseTime, OA.OverallAvgResp,
	   CASE 
        WHEN I.AvgResponseTime > OA.OverallAvgResp THEN 'Above Average'
        WHEN I.AvgResponseTime < OA.OverallAvgResp THEN 'Below Average'
        ELSE 'Equal to Average'
    END AS Comparison
FROM IncidentType I
JOIN OverallAverageResponse OA ON 1=1;

--Using Priority Level
WITH OverallAverageResponse AS (
	SELECT AVG(CAST(Response_time AS BIGINT)) AS OverallAvgResp FROM APDCALLSVIEW
),
IncidentType AS(
	SELECT Priority_Level, AVG(CAST(Response_time AS BIGINT)) AS AvgResponseTime
	FROM APDCALLSVIEW
	GROUP BY Priority_Level
)

SELECT I.Priority_Level, I.AvgResponseTime, OA.OverallAvgResp,
	   CASE 
        WHEN I.AvgResponseTime > OA.OverallAvgResp THEN 'Above Average'
        WHEN I.AvgResponseTime < OA.OverallAvgResp THEN 'Below Average'
        ELSE 'Equal to Average'
    END AS Comparison
FROM IncidentType I
JOIN OverallAverageResponse OA ON 1=1
ORDER BY I.AvgResponseTime;

/*•	Which incidents have closure times that are longer than the average closure time for all incidents?*/
--Using Mental Health Flag
WITH OverallClosureAvg AS (
	SELECT AVG(CAST(Unit_Time_on_Scene AS BIGINT)) AS AvgClosureTime FROM APDCALLSVIEW
),
IncidentClosureAvg AS (
	SELECT Mental_Health_Flag,
		AVG(CAST(Unit_Time_on_Scene AS BIGINT)) AvgClosureTime 
	FROM APDCALLSVIEW
	GROUP BY Mental_Health_Flag
)
SELECT I.Mental_Health_Flag, I.AvgClosureTime, O.AvgClosureTime AS OverallClosureAvg
FROM IncidentClosureAvg I
JOIN OverallClosureAvg O ON 1=1
WHERE I.AvgClosureTime > O.AvgClosureTime;

--Using Priority Level
WITH OverallClosureAvg AS (
	SELECT AVG(CAST(Unit_Time_on_Scene AS BIGINT)) AS AvgClosureTime FROM APDCALLSVIEW
),
IncidentClosureAvg AS (
	SELECT Priority_Level,
		AVG(CAST(Unit_Time_on_Scene AS BIGINT)) AvgClosureTime 
	FROM APDCALLSVIEW
	GROUP BY Priority_Level
)
SELECT I.Priority_Level, I.AvgClosureTime, O.AvgClosureTime AS OverallClosureAvg
FROM IncidentClosureAvg I
JOIN OverallClosureAvg O ON 1=1
WHERE I.AvgClosureTime > O.AvgClosureTime
ORDER BY I.AvgClosureTime DESC;

/*•	For each day of the week, calculate the difference between the average response time for that day and the average response
time for all days combined.*/
WITH OverallAvg AS (
	SELECT AVG(CAST(Response_time AS BIGINT)) AS AvgResTime FROM APDCALLSVIEW
),
WeekDayAvg AS (
	SELECT Response_Day_of_Week, AVG(CAST(Response_time AS BIGINT)) AS AvgResTime FROM APDCALLSVIEW
	GROUP BY Response_Day_of_Week
)
SELECT W.Response_Day_of_Week, W.AvgResTime, O.AvgResTime AS OverallAvgResTime,
	(W.AvgResTime - O.AvgResTime) AS AvgResTimeDiff
FROM WeekDayAvg W
JOIN OverallAvg O ON 1=1
Order BY AvgResTimeDiff;
	
/*•	What are the top 3 most frequent final problem descriptions?*/
SELECT TOP 3 Final_Problem_Description, COUNT(*) AS Frequency FROM APDCALLSVIEW
GROUP BY Final_Problem_Description
ORDER BY Frequency DESC;

/*•	What are the busiest times of the day, and how do incident types vary by time?*/
WITH HourlyIncidents AS (
    SELECT 
        Response_Hour, Mental_Health_Flag, COUNT(*) AS Incident_Count
    FROM APDCALLSVIEW
    GROUP BY Response_Hour, Mental_Health_Flag
),
TotalIncidentsByHour AS (
    SELECT 
        Response_Hour, SUM(Incident_Count) AS Total_Incident_Count
    FROM HourlyIncidents
    GROUP BY Response_Hour
)
SELECT 
    h.Response_Hour,
    h.Mental_Health_Flag,
    h.Incident_Count,
    t.Total_Incident_Count,
    (h.Incident_Count * 100.0 / t.Total_Incident_Count) AS Percentage_By_Incident_Type
FROM 
    HourlyIncidents h
JOIN 
    TotalIncidentsByHour t ON h.Response_Hour = t.Response_Hour
ORDER BY 
    t.Total_Incident_Count DESC, h.Response_Hour, h.Incident_Count DESC;

/*•	What is the total number of mental health-related incidents, and how has this changed over time?*/
WITH TotalIncidents AS ( 
	SELECT COUNT(*) AS OverallTotalIncident FROM APDCALLSVIEW WHERE Mental_Health_Flag = 'Mental Health Incident'
),
YearlyIncidents AS (
	SELECT YEAR(Response_Datetime) AS Response_Year, DATENAME(MONTH, Response_Datetime) AS Response_Month,
	DATEPART(MONTH, Response_Datetime) AS Month_Order,
	COUNT(*) AS TotalIncidents FROM APDCALLSVIEW 
	WHERE Mental_Health_Flag = 'Mental Health Incident' 
	GROUP BY YEAR(Response_Datetime),DATEPART(MONTH, Response_Datetime), DATENAME(MONTH, Response_Datetime)
)
SELECT Y.Response_Year,Y.Response_Month, Y.TotalIncidents,T.OverallTotalIncident 
FROM YearlyIncidents Y
JOIN TotalIncidents T ON 1=1
ORDER BY Y.Response_Year, Y.Month_Order;


/*•	Which sectors have above-average mental health-related incidents compared to the overall average for all sectors?*/
WITH MentalIncidentsTotal AS(
	SELECT Sector, COUNT(*) AS TotalIncidents FROM APDCALLSVIEW
	WHERE Mental_Health_Flag = 'Mental Health Incident' 
	GROUP BY Sector
),
AverageTotal AS (
	SELECT AVG(TotalIncidents) as AvgMentalIncidents FROM MentalIncidentsTotal
)
SELECT M.Sector, M.TotalIncidents, A.AvgMentalIncidents 
FROM MentalIncidentsTotal M
JOIN AverageTotal A ON 1=1
WHERE M.TotalIncidents > A.AvgMentalIncidents
ORDER BY M.TotalIncidents DESC;


/*•	What is the average time spent on scene by units across different types of incidents?*/
SELECT Mental_Health_Flag, AVG(CAST(Unit_Time_on_Scene AS BIGINT)) AS AvgTimeOnScene 
FROM APDCALLSVIEW
GROUP BY Mental_Health_Flag;
--Based on Priority Level
SELECT Priority_Level, AVG(CAST(Unit_Time_on_Scene AS BIGINT)) AS AvgTimeOnScene 
FROM APDCALLSVIEW
GROUP BY Priority_Level
ORDER BY AvgTimeOnScene DESC;

/*•	What is the distribution of response times across the sectors, and which sectors have the fastest and slowest response times?*/
SELECT 
    Sector,
    AVG(CAST(Response_Time AS FLOAT)) AS Avg_Response_Time,
    MIN(CAST(Response_Time AS FLOAT)) AS Min_Response_Time,
    MAX(CAST(Response_Time AS FLOAT)) AS Max_Response_Time
FROM APDCALLSVIEW
GROUP BY Sector
ORDER BY Avg_Response_Time ASC;


/*•	Which incidents have the longest on-scene time, and how does this correlate with the incident type or priority level?*/
SELECT 
    Incident_Type,
    Priority_Level,
    AVG(CAST(Unit_Time_on_Scene AS FLOAT)) AS Avg_On_Scene_Time,
    MAX(CAST(Unit_Time_on_Scene AS FLOAT)) AS Max_On_Scene_Time
FROM 
    APDCALLSVIEW
GROUP BY 
    Incident_Type, Priority_Level
ORDER BY 
    Avg_On_Scene_Time DESC;


/*•	Which types of incidents typically require reports to be written, and how frequently do these occur?*/
SELECT Mental_Health_Flag, Priority_Level, COUNT(*) AS IncidentFrequency
FROM APDCALLSVIEW
WHERE Report_Written_Flag = 'Yes'
GROUP BY Mental_Health_Flag, Priority_Level
ORDER BY IncidentFrequency DESC;


/*•	What is the average number of units dispatched to incidents based on the incident type?*/
SELECT Priority_Level, AVG(Number_of_Units_Arrived) AS AvgUnitsDispatched FROM APDCALLSVIEW
GROUP BY Priority_Level
ORDER BY AvgUnitsDispatched DESC;
