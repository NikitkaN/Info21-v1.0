-- 1 задание
CREATE OR REPLACE PROCEDURE peer_rvw
(p2p_checked varchar, p2p_checking varchar, task_name text, status check_status, check_time TIME) LANGUAGE plpgsql AS $$
    BEGIN
        IF (status = 'start')
		THEN
				INSERT INTO checks
                VALUES
                    ((SELECT MAX(id) FROM checks) + 1, p2p_checked, task_name, NOW());
                INSERT INTO p2p
                VALUES ((SELECT MAX(id) FROM p2p) + 1, (SELECT MAX(id) FROM checks), p2p_checking, status, check_time);
        ELSE
            INSERT INTO p2p
            VALUES ((SELECT MAX(id) FROM p2p) + 1, (SELECT "Check" FROM p2p
                     JOIN checks ON p2p."Check" = checks.id
                     WHERE p2p.checkingpeer = p2p_checking
					 	AND checks.peer = p2p_checked
					 	AND checks.task = task_name),
                    p2p_checking, status, check_time);
    END IF;
END;
$$;

-- DROP PROCEDURE add_peer_review(character varying,character varying,text,check_status,time without time zone);

-- 2 задание
CREATE OR REPLACE PROCEDURE verter_rvw(p2p_checked varchar, task_name text, status check_status, verter_time time)
    LANGUAGE plpgsql AS $$
    BEGIN
        IF (status = 'start') THEN
                    INSERT INTO verter
                    VALUES ((SELECT MAX(id) FROM verter) + 1,
                            (SELECT DISTINCT checks.id FROM p2p JOIN checks ON p2p."Check" = checks.id
                             WHERE checks.peer = p2p_checked
							 	AND p2p.state = 'Success'
                                AND checks.task = task_name), status, verter_time);
        ELSE
            INSERT INTO verter
            VALUES ((SELECT MAX(id) FROM verter) + 1, (SELECT "Check" FROM verter
                     GROUP BY "Check" HAVING COUNT(*) % 2 = 1), status, verter_time);
        END IF;
    END;
$$;

-- 3 задание
CREATE OR REPLACE FUNCTION trg_update() RETURNS TRIGGER
    LANGUAGE plpgsql AS $$
	DECLARE t2 varchar = ((
               SELECT checks.peer FROM p2p JOIN checks ON p2p."Check" = checks.id
			   WHERE checks.id = NEW."Check"
           )
			UNION
			(
               SELECT checks.peer FROM p2p JOIN checks ON p2p."Check" = checks.id
			   WHERE checks.id = NEW."Check"
           ));
    BEGIN
       IF (NEW.state = 'Start')
	   THEN
           WITH t1 AS (
               SELECT checks.peer AS peer  FROM p2p JOIN checks ON p2p."Check" = checks.id
			   AND NEW."Check" = checks.id
           )
           UPDATE transferredpoints SET pointsamount = pointsamount + 1 FROM t1
           WHERE  transferredpoints.checkedpeer = t1.peer
		   AND  transferredpoints.checkingpeer = NEW.checkingpeer;
       END IF;
	   IF ((SELECT COUNT(*)
		  FROM transferredpoints WHERE checkedpeer = t2
		  AND checkingpeer = NEW.checkingpeer) = 0
		  AND NEW.state = 'Start')
		  THEN
		  INSERT INTO transferredpoints VALUES (DEFAULT, NEW.checkingpeer, t2, '1');
	   END IF;
    END;
$$;

CREATE OR REPLACE TRIGGER trg_update
AFTER INSERT ON P2P
    FOR EACH ROW EXECUTE FUNCTION trg_update();

-- 4 задание

CREATE OR REPLACE FUNCTION check_before() RETURNS TRIGGER
    LANGUAGE plpgsql AS $$
    BEGIN
        IF ((SELECT maxxp FROM checks JOIN tasks ON checks.task = tasks.title
            WHERE NEW."Check" = checks.id) < NEW.xpamount OR
            (SELECT state FROM p2p
             WHERE NEW."Check" = p2p."Check" AND p2p.state IN ('Success', 'Failure')) = 'Failure' OR
            (SELECT state FROM verter
             WHERE NEW."Check" = verter."Check" AND verter.state = 'Failure') = 'Failure')
			 THEN
                RAISE EXCEPTION 'error';
        END IF;
    RETURN (NEW.id, NEW."Check", NEW.xpamount);
    END;
$$;

CREATE OR REPLACE TRIGGER check_before
BEFORE INSERT ON XP
    FOR EACH ROW EXECUTE FUNCTION check_before();
