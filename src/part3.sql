/* Write a function that returns the TransferredPoints table in a more human-readable form */

CREATE OR REPLACE FUNCTION task_1() 
RETURNS TABLE (
peer1 VARCHAR,
peer2 VARCHAR,
PointsAmount NUMERIC)
AS $$
BEGIN
RETURN QUERY
SELECT CheckingPeer, CheckedPeer, SUM(PointsSum)
FROM (
  SELECT CheckingPeer, CheckedPeer, tp1.PointsAmount AS PointsSum
  FROM TransferredPoints tp1
  WHERE CheckingPeer < CheckedPeer
  UNION ALL
  SELECT CheckedPeer AS CheckingPeer, CheckingPeer AS CheckedPeer, -tp2.PointsAmount AS PointsSum
  FROM TransferredPoints tp2
  WHERE CheckingPeer > CheckedPeer
) AS subquery
GROUP BY CheckingPeer, CheckedPeer
ORDER BY CheckingPeer;
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM task_1();

/*Write a function that returns a table of the following form: user name, 
name of the checked task, number of XP received*/

CREATE OR REPLACE FUNCTION task_2()
RETURNS TABLE (Peer VARCHAR, Task VARCHAR, XP BIGINT)
AS $$
BEGIN
RETURN QUERY
SELECT DISTINCT CheckingPeer, Checks.Task, XP.XPAmount FROM P2P
JOIN Checks ON P2P.CheckingPeer = Checks.Peer
JOIN XP ON Checks.ID = XP."Check"
LEFT JOIN Verter ON Checks.ID = Verter."Check"
WHERE P2P.state = 'Success' AND (Verter.State = 'Success' OR Verter.State = NULL)
ORDER BY 1;
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM task_2();

/*Write a function that finds the peers who have not left campus for the whole day*/

CREATE OR REPLACE FUNCTION task_3(given_date date)
RETURNS TABLE (Peer VARCHAR)
AS $$
BEGIN
RETURN QUERY
SELECT dates.Peer FROM (SELECT TT.Peer, SUM(State) AS State
				  FROM TimeTracking TT
				  WHERE Date = given_date
				  GROUP BY TT.Peer) dates
WHERE dates.State = 1;
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM task_3('2023-07-04');

/*Calculate the change in the number of peer points of each peer using the TransferredPoints table*/

CREATE OR REPLACE PROCEDURE task_4(IN REF refcursor)
AS $$
BEGIN
OPEN REF FOR
SELECT income.CheckingPeer, (point_income - point_outcome) AS PointsChange FROM
(SELECT tp1.CheckingPeer, SUM(tp1.PointsAmount) AS point_income FROM TransferredPoints tp1
GROUP BY CheckingPeer) AS income
JOIN (SELECT tp2.CheckedPeer, SUM(tp2.PointsAmount) AS point_outcome 
	  FROM TransferredPoints tp2
	 GROUP BY CheckedPeer) AS outcome
	 ON income.CheckingPeer = outcome.CheckedPeer
	 ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql;

--BEGIN;
--CALL task_4('ref');
--FETCH ALL IN "ref";
--END;

/*Calculate the change in the number of peer points of each peer using the table returned by the first function from Part 3*/

CREATE OR REPLACE PROCEDURE task_5(IN REF refcursor) 
AS $$
BEGIN
OPEN REF FOR
SELECT PeerPoints.peer, SUM(PeerPoints.PointsAmount) AS PointsChange
FROM ((SELECT Peer1 AS Peer, t1.PointsAmount FROM task_1() t1)
	 UNION ALL
	 (SELECT Peer2 AS Peer, (t2.PointsAmount * -1) FROM task_1() t2)) AS PeerPoints
	 GROUP BY PeerPoints.Peer
	 ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql;

--BEGIN;
--CALL task_5('ref');
--FETCH ALL IN "ref";
--END;

/*Find the most frequently checked task for each day*/

ROLLBACK TRANSACTION;
CREATE OR REPLACE PROCEDURE task_6(IN ref refcursor)
AS $$
BEGIN
OPEN REF FOR 
WITH pt1 AS (SELECT Task, Date, COUNT(*) AS counts 
			 FROM Checks GROUP BY Task, Date)
			 
SELECT Date, p.Task FROM pt1 AS p
		WHERE counts = (SELECT MAX(counts) FROM 
						(SELECT * FROM pt1 WHERE pt1.Date = p.Date) AS dequalsd) ORDER BY 1 DESC;
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_6('ref');
--FETCH ALL IN "ref";
--END;

/*Find all peers who have completed the whole given block of tasks and the completion date of the last task*/

ROLLBACK TRANSACTION;
CREATE OR REPLACE PROCEDURE task_7(IN ref refcursor, IN BlockName VARCHAR)
AS $$
BEGIN
OPEN REF FOR
WITH last_task AS 
(SELECT Title FROM Tasks 
WHERE Title SIMILAR TO CONCAT(Blockname, '[0-9]%')
ORDER BY 1 DESC LIMIT 1)

SELECT DISTINCT Peer AS "Peer", Date AS "Day" FROM Checks 
LEFT JOIN Verter ON Verter."Check" = Checks.ID 
JOIN P2P ON P2P."Check" = Checks.ID
WHERE Task IN (SELECT Title FROM last_task) AND (Verter.State = 'Success' OR (P2P.State = 'Success' AND Verter.State = NULL));
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_7('ref', 'DO');
--FETCH ALL IN "ref";
--END;

/*Determine which peer each student should go to for a check.*/

CREATE OR REPLACE PROCEDURE task_8(IN ref refcursor)
AS 
$$ BEGIN
OPEN REF FOR
WITH allfriends AS (SELECT Peer1, Peer2 FROM Friends
                             UNION SELECT Peer2 AS Peer1, Peer1 AS Peer2 FROM Friends),
every_recommended AS (SELECT al.Peer1, r.RecommendedPeer FROM allfriends al 
				 JOIN Recommendations r ON r.Peer = al.Peer2 
				 WHERE al.Peer1 <> r.RecommendedPeer),
count_recommendations AS (SELECT Peer1, RecommendedPeer, COUNT(RecommendedPeer) FROM every_recommended  
			  GROUP BY Peer1, RecommendedPeer ORDER BY 1 ASC, 3 DESC)
SELECT Peer1 AS Peer, RecommendedPeer FROM count_recommendations  co1 
WHERE count = (SELECT MAX(count) 
			   FROM count_recommendations  co2 WHERE co1.Peer1 = co2.Peer1);
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_8('ref');
--FETCH ALL IN "ref";
--END;

/*Determine the percentage of peers who:
Started only block 1
Started only block 2
Started both
Have not started any of them
*/

ROLLBACK TRANSACTION;
CREATE OR REPLACE PROCEDURE task_9(IN ref refcursor, IN block1 VARCHAR, IN block2 VARCHAR)
AS $$
BEGIN
OPEN REF FOR 
WITH started_block1 AS (SELECT DISTINCT Peer FROM CHECKS WHERE Task SIMILAR TO CONCAT(block1, '[0-9]%')),
	 started_block2 AS (SELECT DISTINCT Peer FROM CHECKS WHERE Task SIMILAR TO CONCAT(block2, '[0-9]%')),
	 started_bothblocks AS ((SELECT Peer FROM started_block1) INTERSECT (SELECT Peer FROM started_block2)),
	 didnt_start AS ((SELECT Nickname AS Peer FROM Peers) EXCEPT ((SELECT Peer FROM started_block1) 
																  UNION (SELECT Peer FROM started_block2)))
SELECT (SELECT COUNT(Peer) FROM started_block1) * 100 / COUNT(Nickname) AS StartedBlock1,
	   (SELECT COUNT(Peer) FROM started_block2) * 100 / COUNT(Nickname) AS StartedBlock2,
	   (SELECT COUNT(Peer) FROM started_bothblocks) * 100 / COUNT(Nickname) AS StartedBothBlocks,
	   (SELECT COUNT(Peer) FROM didnt_start) * 100 / COUNT(Nickname) AS DidntStartAnyBlock FROM Peers;
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_9('ref', 'DO', 'CPP');
--FETCH ALL IN "ref";
--END;

/*Determine the percentage of peers who have ever successfully passed a check on their birthday*/

CREATE OR REPLACE PROCEDURE task_10(IN ref refcursor)
AS $$
BEGIN
OPEN REF FOR
WITH successbday AS (SELECT p.Nickname as Peer, Checks.Date, ptp.State AS pstate, v.State AS vstate FROM Checks 
LEFT JOIN Verter v ON Checks.ID = v."Check"
JOIN P2P ptp ON Checks.ID = ptp."Check"
JOIN Peers p ON Checks.Peer = p.Nickname
WHERE (EXTRACT(MONTH FROM Checks.Date) = EXTRACT(MONTH FROM p.Birthday)) AND
			(EXTRACT(DAY FROM Checks.Date) = EXTRACT(DAY FROM p.Birthday)))
SELECT (SELECT COUNT(Peer) FROM successbday 
		WHERE pstate = 'Success' AND (vstate = 'Success' OR vstate = NULL)) * 100 / COUNT(Peers.Nickname) AS SuccessfulChecks, 
(SELECT COUNT(Peer) FROM successbday 
 WHERE (pstate = 'Fail' OR vstate = 'Fail')) * 100 / COUNT(Peers.Nickname) AS UnsuccessfulChecks FROM Peers;
END;
$$ LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_10('ref');
--FETCH ALL IN "ref";
--END;

/*Determine all peers who did the given tasks 1 and 2, but did not do task 3*/

ROLLBACK TRANSACTION;
CREATE OR REPLACE PROCEDURE task_11(IN REF refcursor, task1 VARCHAR, task2 VARCHAR, task3 VARCHAR)
AS $$
BEGIN
OPEN REF FOR
WITH firsttask AS (SELECT p.Nickname as Peer FROM Checks 
JOIN Peers p ON Checks.Peer = p.Nickname
WHERE Checks.Task = task1),
secondtask AS (SELECT p.Nickname as Peer FROM Checks 
JOIN Peers p ON Checks.Peer = p.Nickname
WHERE Checks.Task = task2),
thirdtask AS (SELECT p.Nickname as Peer FROM Checks 
JOIN Peers p ON Checks.Peer = p.Nickname
WHERE Checks.Task = task3)
SELECT Peer FROM (SELECT Peer FROM (SELECT Peer FROM firsttask 
								 INTERSECT 
								 SELECT Peer FROM secondtask) AS oneandtwo
				  EXCEPT
				  (SELECT Peer FROM thirdtask)) AS oneandtwoandthree;
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_11('ref', 'CPP1_s21_matrixplus', 'DO5_SimpleDocker', 'DO1_Linux');
--FETCH ALL IN "ref";
--END;

/*Using recursive common table expression, output the number of preceding tasks for each task*/

CREATE OR REPLACE PROCEDURE task_12(IN REF refcursor)
AS $$
BEGIN
OPEN REF FOR
WITH RECURSIVE counter AS (
SELECT Tasks.ParentTask AS Parent, Tasks.Title as TaskTitle FROM Tasks
UNION ALL
SELECT Tasks.ParentTask, counter.TaskTitle
FROM counter
JOIN Tasks ON counter.Parent = Tasks.Title)

SELECT TaskTitle AS Task, count(Parent) AS PrevCount FROM counter GROUP BY TaskTitle;
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_12('ref');
--FETCH ALL IN "ref";
--END;

/*Find "lucky" days for checks. A day is considered "lucky" if it has at least N consecutive successful checks*/

CREATE OR REPLACE PROCEDURE task_13(IN REF refcursor, N BIGINT)
AS $$
BEGIN
OPEN REF FOR
WITH 
all_eighty AS (SELECT Date, p.State AS P2PCheck, sttime.Time AS P2PTime, 
			   v.State AS VerterCheck FROM Checks
			  LEFT JOIN Verter v ON Checks.ID = v."Check"
			  JOIN XP x ON Checks.ID = x."Check"
			  JOIN P2P p ON Checks.ID = p."Check"
			  JOIN Tasks t ON Checks.Task = t.Title
			  JOIN (SELECT "Check", Time FROM P2P WHERE State = 'Start') sttime 
			   ON sttime."Check" = Checks.ID 
			  WHERE x.XPAmount >= t.MaxXP * 0.8 AND p.State <> 'Start' AND v.State <> 'Start'),
count_success AS (SELECT ale.Date, ale.P2PCheck, ale.P2PTime, ale.VerterCheck,
				  (CASE WHEN (P2PCheck = 'Success' AND 
							  (VerterCheck = 'Success' OR VerterCheck = NULL))
				   THEN row_number() OVER (PARTITION BY P2PCheck, date) 
				   ELSE 0 END) as Counter FROM all_eighty ale ORDER BY Date),
count_days AS (SELECT to_char(sd.Date, 'day') as weekday, SUM(sd.Counter) as count_week FROM 
(SELECT cs.Date, MAX(Counter) AS Counter FROM count_success cs GROUP BY Date) sd GROUP BY weekday)

SELECT weekday FROM count_days WHERE count_week >= N;
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_13('ref', 1);
--FETCH ALL IN "ref";
--END;

/*Find the peer with the highest amount of XP*/

CREATE OR REPLACE PROCEDURE task_14(IN REF refcursor)
AS $$
BEGIN
OPEN REF FOR
WITH allsumxp AS (SELECT Peer, SUM(x.XPAmount) AS sumxp FROM Checks
JOIN XP x ON x."Check" = Checks.ID GROUP BY Peer)
SELECT Peer, sumxp AS XP FROM allsumxp WHERE sumxp = (SELECT MAX(sumxp) FROM allsumxp);
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_14('ref');
--FETCH ALL IN "ref";
--END;

/*Determine the peers that came before the given time at least N times during the whole time*/

CREATE OR REPLACE PROCEDURE task_15(IN REF refcursor, CT TIME, N BIGINT)
AS $$
BEGIN
OPEN REF FOR
WITH came_before AS (SELECT Peer, Time FROM TimeTracking WHERE Time < CT)
SELECT Peer FROM (SELECT Peer, count(Time) as tm FROM came_before GROUP BY Peer) cot WHERE tm >= N;
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_15('ref', '10:00:00', '2');
--FETCH ALL IN "ref";
--END;

/*Determine the peers who left the campus more than M times during the last N days*/

CREATE OR REPLACE PROCEDURE task_16(IN REF refcursor, M BIGINT, N BIGINT)
AS $$
BEGIN
OPEN REF FOR
WITH takebefore AS (SELECT Peer, COUNT(Date) AS counter FROM TimeTracking
        WHERE state = 2 AND NOW()::DATE - Date < M
        GROUP BY Peer)
SELECT Peer FROM takebefore WHERE counter > N;
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_16('ref', 360, 0);
--FETCH ALL IN "ref";
--END;

/*Determine for each month the percentage of early entries*/

CREATE OR REPLACE PROCEDURE task_17(IN REF refcursor)
AS $$
BEGIN
OPEN REF FOR
WITH entries_birthdays AS (SELECT Peer, Time, to_char(tmtr.Date, 'Month') AS camemonth, 
					 to_char(ps.Birthday, 'Month') AS birthmonth 
				  FROM TimeTracking tmtr
				 JOIN Peers ps ON tmtr.Peer = ps.Nickname
					WHERE State = 1),
months AS (SELECT TO_CHAR(generate_series('2023-01-01', '2023-12-31', INTERVAL '1 month'), 
						  'Month') AS month),
counted_entries AS (SELECT Peer, Time, camemonth FROM entries_birthdays WHERE camemonth = birthmonth),
all_entries AS (SELECT DISTINCT Peer, camemonth, COUNT(camemonth) counter FROM entries_birthdays  
			 WHERE camemonth = birthmonth GROUP BY Peer, camemonth),
entries_before_noon AS (SELECT ent.counter AS counter, ent.camemonth AS month
			 FROM all_entries ent, counted_entries e
			 WHERE e.time < '12:00:00' AND e.camemonth = ent.camemonth AND e.Peer = ent.Peer 
						GROUP BY ent.camemonth, ent.counter),
result_set AS (SELECT tw.month as month, (tw.counter / (SELECT SUM(ent.counter) FROM all_entries ent) * 100) AS counter
	   FROM entries_before_noon tw
	   GROUP BY tw.counter, tw.month
	   UNION ALL
	   SELECT m.month, 0 FROM months m, entries_before_noon n)
SELECT r.month, cast(ROUND(SUM(r.counter)) AS INT) AS EarlyEntries FROM result_set r GROUP BY r.month
ORDER BY EXTRACT(MONTH FROM TO_DATE(r.month, 'Month'));
END;
$$
LANGUAGE PLPGSQL;

--BEGIN;
--CALL task_17('ref');
--FETCH ALL IN "ref";
--END;