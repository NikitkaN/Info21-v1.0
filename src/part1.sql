CREATE DATABASE Info21;

CREATE TYPE check_status AS enum ('Start', 'Success', 'Fail');


CREATE TABLE IF NOT EXISTS Peers (
	Nickname varchar PRIMARY KEY,
	Birthday date NOT NULL
);

CREATE TABLE IF NOT EXISTS Tasks (
	Title varchar PRIMARY KEY,
	ParentTask varchar NULL,
	MaxXP bigint NOT NULL,
	CONSTRAINT fk_tasks_title FOREIGN KEY (ParentTask) REFERENCES Tasks(Title)
);

CREATE TABLE IF NOT EXISTS Checks (
ID bigint PRIMARY KEY,
	Peer varchar NOT NULL,
	Task varchar NOT NULL,
	Date date NOT NULL,
	CONSTRAINT fk_checks_title FOREIGN KEY (Task) REFERENCES Tasks(Title),
	CONSTRAINT fk_checks_nickname FOREIGN KEY (Peer) REFERENCES Peers(Nickname)
);

CREATE TABLE IF NOT EXISTS P2P (
   ID bigint PRIMARY KEY,
   "Check" bigint NOT NULL,
   CheckingPeer varchar NOT NULL,
   State check_status NOT NULL,
   Time time NOT NULL,
   CONSTRAINT fk_p2p_id FOREIGN KEY ("Check") REFERENCES Checks(ID),
	CONSTRAINT fk_p2p_nickname FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT uq_incomplete_check UNIQUE ("Check", CheckingPeer, State)
   );
   
CREATE TABLE IF NOT EXISTS XP (
ID bigint PRIMARY KEY,
	"Check" bigint NOT NULL,
	XPAmount bigint NOT NULL,
	CONSTRAINT fk_xp_id FOREIGN KEY ("Check") REFERENCES Checks(ID),
	CONSTRAINT ch_xp CHECK (XPAmount > 0)
);

CREATE TABLE IF NOT EXISTS Verter (
	ID bigint PRIMARY KEY,
	"Check" bigint NOT NULL,
	State check_status NOT NULL,
	Time time NOT NULL,
	CONSTRAINT fk_verter_id FOREIGN KEY ("Check") REFERENCES Checks(ID),
	CONSTRAINT uq_verter_check UNIQUE ("Check", State, Time)
);

CREATE TABLE IF NOT EXISTS TransferredPoints (
ID bigint PRIMARY KEY,
	CheckingPeer varchar NOT NULL,
	CheckedPeer varchar NOT NULL,
	PointsAmount bigint NOT NULL,
	CONSTRAINT fk_transferredpoints_checking_nickname FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_transferredpoints_checked_nickname FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname),
	CONSTRAINT ch_points_peers CHECK (CheckingPeer <> CheckedPeer)
);

CREATE TABLE IF NOT EXISTS Friends (
ID bigint PRIMARY KEY,
	Peer1 varchar NOT NULL,
	Peer2 varchar NOT NULL,
	CONSTRAINT fk_friends_peer1_nickname FOREIGN KEY (Peer1) REFERENCES Peers(Nickname),
	CONSTRAINT fk_friends_peer2_nickname FOREIGN KEY (Peer2) REFERENCES Peers(Nickname),
	CONSTRAINT ch_friends_peers CHECK (Peer1 <> Peer2)
);

CREATE TABLE IF NOT EXISTS Recommendations (
ID bigint PRIMARY KEY,
	Peer varchar NOT NULL,
	RecommendedPeer varchar NOT NULL,
	CONSTRAINT fk_recommendations_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_recommendations_recommended FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname),
	CONSTRAINT ch_recommended_peers CHECK (Peer <> RecommendedPeer)
);

CREATE TABLE IF NOT EXISTS TimeTracking (
ID bigint PRIMARY KEY,
	Peer varchar NOT NULL,
	Date date NOT NULL,
	Time time NOT NULL,
	State bigint NOT NULL,
	CONSTRAINT fk_timetracking_nickname FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT ch_state CHECK (State in (1, 2))
);

INSERT INTO Peers (Nickname, Birthday)
VALUES
('brittnyc', '2003-03-20'),
('williamc', '2001-07-24'),
('lowellda', '2004-10-19'),
('maplesar', '2001-12-20'),
('spongebob', '2001-06-09'),
('keygench', '2000-01-01');

INSERT INTO Tasks (Title, ParentTask, MaxXP)
VALUES
('DO1_Linux', NULL, 300),
('CPP1_s21_matrixplus', NULL, 300),
('DO2_LinuxNetwork', 'DO1_Linux', 350),
('DO3_LinuxMonitoring_v1.0', 'DO2_LinuxNetwork', 350),
('DO4_LinuxMonitoring_v2.0', 'DO3_LinuxMonitoring_v1.0', 501),
('DO5_SimpleDocker', 'DO3_LinuxMonitoring_v1.0', 300);

INSERT INTO P2P (ID, "Check", CheckingPeer, State, Time)
VALUES
(1, 1, 'williamc', 'Start', '10:00:00'),
(2, 1, 'williamc', 'Success', '10:45:00'),
(3, 2, 'keygench', 'Start', '12:45:00'),
(4, 2, 'keygench', 'Fail', '14:00:00'),
(5, 3, 'lowellda', 'Start', '23:00:00'),
(6, 3, 'lowellda', 'Success', '23:30:00'),
(7, 4, 'brittnyc', 'Start', '01:00:00'),
(8, 4, 'brittnyc', 'Success', '01:37:00'),
(9, 5, 'maplesar', 'Start', '13:00:00'),
(10, 5, 'maplesar', 'Success', '13:52:00'),
(11, 6, 'brittnyc', 'Start', '22:00:00'),
(12, 6, 'brittnyc', 'Success', '22:34:00'),
(13, 7, 'lowellda', 'Start', '15:00:00'),
(14, 7, 'lowellda', 'Success', '15:45:00'),
(15, 8, 'maplesar', 'Start', '15:40:00'),
(16, 8, 'maplesar', 'Fail', '16:19:00'),
(17, 9, 'williamc', 'Start', '17:40:00'),
(18, 9, 'williamc', 'Success', '18:09:00');

INSERT INTO Verter (ID, "Check", State, Time)
VALUES
(1, 1, 'Start', '10:46:00'),
(2, 1, 'Success', '10:52:00'),
(3, 3, 'Start', '14:01:00'),
(4, 3, 'Success', '14:10:00'),
(5, 4, 'Start', '01:38:00'),
(6, 4, 'Success', '01:50:00'),
(7, 5, 'Start', '13:55:00'),
(8, 5, 'Success', '14:10:00'),
(9, 6, 'Start', '22:38:00'),
(10, 6, 'Success', '22:50:00'),
(11, 7, 'Start', '16:00:00'),
(12, 7, 'Fail', '16:29:00'),
(13, 9, 'Start', '18:10:00'),
(14, 9, 'Success', '18:20:00');

INSERT INTO Checks (ID, Peer, Task, Date)
VALUES
(1, 'brittnyc', 'DO3_LinuxMonitoring_v1.0', '2023-06-05'),
(2, 'maplesar', 'DO1_Linux', '2023-06-29'),
(3, 'keygench', 'DO5_SimpleDocker', '2023-07-01'),
(4, 'williamc', 'DO4_LinuxMonitoring_v2.0', '2023-07-03'),
(5, 'lowellda', 'DO2_LinuxNetwork', '2023-07-05'),
(6, 'maplesar', 'DO2_LinuxNetwork', '2023-07-05'),
(7, 'williamc', 'CPP1_s21_matrixplus', '2023-02-03'),
(8, 'keygench', 'CPP1_s21_matrixplus', '2023-01-01'),
(9, 'brittnyc', 'CPP1_s21_matrixplus', '2023-03-20');

INSERT INTO TransferredPoints (ID, CheckingPeer, CheckedPeer, PointsAmount)
VALUES
(1, 'williamc', 'brittnyc', 1),
(2, 'keygench', 'maplesar', 2),
(3, 'lowellda', 'keygench', 2),
(4, 'brittnyc', 'williamc', 1),
(5, 'maplesar', 'lowellda', 1),
(6, 'brittnyc', 'maplesar', 1);

INSERT INTO Friends (ID, Peer1, Peer2)
VALUES
(1, 'brittnyc', 'williamc'),
(2, 'lowellda', 'maplesar'),
(3, 'maplesar', 'keygench'),
(4, 'williamc', 'lowellda'),
(5, 'keygench', 'brittnyc');

INSERT INTO Recommendations (ID, Peer, RecommendedPeer)
VALUES
(1, 'brittnyc', 'lowellda'),
(2, 'keygench', 'maplesar'),
(3, 'williamc', 'keygench'),
(4, 'maplesar', 'brittnyc'),
(5, 'lowellda', 'williamc'),
(6, 'williamc', 'maplesar');

INSERT INTO XP (ID, "Check", XPAmount)
VALUES
(1, 1, 300),
(2, 3, 250),
(3, 4, 152),
(4, 5, 350),
(5, 6, 200),
(6, 9, 300);

INSERT INTO TimeTracking (ID, Peer, Date, Time, State)
VALUES
(1, 'brittnyc', '2023-07-03', '04:20:00', 1),
(2, 'brittnyc', '2023-07-04', '06:09:00', 2),
(3, 'williamc', '2023-07-04', '07:00:00', 1),
(4, 'williamc', '2023-07-05', '08:23:00', 2),
(5, 'lowellda', '2023-07-03', '09:07:00', 1),
(6, 'lowellda', '2023-07-03', '18:12:00', 2);

CREATE OR REPLACE PROCEDURE export_to_csv(IN table_name varchar, IN path text, IN separator char(1))
AS $$ BEGIN
EXECUTE format('COPY %s TO %L DELIMITER %L CSV HEADER;', table_name, path, separator);
END;
$$ LANGUAGE PLPGSQL;

--CALL export_to_csv('P2P', '/Users/info/inf21/src/tables/p2p.csv', ',');
--CALL export_to_csv('Peers', '/Users/info/inf21/src/tables/peers.csv', ',');
--CALL export_to_csv('Tasks', '/Users/info/inf21/src/tables/tasks.csv', ',');
--CALL export_to_csv('Verter', '/Users/info/inf21/src/tables/verter.csv', ',');
--CALL export_to_csv('XP', '/Users/info/inf21/src/tables/XP.csv', ',');
--CALL export_to_csv('TransferredPoints', '/Users/info/inf21/src/tables/transferredpoints.csv', ',');
--CALL export_to_csv('Frineds', '/Users/info/inf21/src/tables/friends.csv', ',');
--CALL export_to_csv('Checks', '/Users/info/inf21/src/tables/checks.csv', ',');
--CALL export_to_csv('Recommendations', '/Users/info/inf21/src/tables/recommendations.csv', ',');
--CALL export_to_csv('TimeTracking', '/Users/info/inf21/src/tables/timetracking.csv', ',');

CREATE OR REPLACE PROCEDURE import_from_csv(IN table_name varchar, IN path text, IN separator char(1))
AS $$ BEGIN
EXECUTE format('COPY %s FROM %L DELIMITER %L CSV HEADER;', table_name, path, separator);
END;
$$ LANGUAGE PLPGSQL;

--CALL import_to_csv('P2P', '/Users/info/inf21/src/tables/p2p.csv', ',');
--CALL import_to_csv('Peers', '/Users/info/inf21/src/tables/peers.csv', ',');
--CALL import_to_csv('Tasks', '/Users/info/inf21/src/tables/tasks.csv', ',');
--CALL import_to_csv('Verter', '/Users/info/inf21/src/tables/verter.csv', ',');
--CALL import_to_csv('XP', '/Users/info/inf21/src/tables/XP.csv', ',');
--CALL import_to_csv('TransferredPoints', '/Users/info/inf21/src/tables/transferredpoints.csv', ',');
--CALL import_to_csv('Frineds', '/Users/info/inf21/src/tables/friends.csv', ',');
--CALL import_to_csv('Checks', '/Users/info/inf21/src/tables/checks.csv', ',');
--CALL import_to_csv('Recommendations', '/Users/info/inf21/src/tables/recommendations.csv', ',');
--CALL import_to_csv('TimeTracking', '/Users/info/inf21/src/tables/timetracking.csv', ',');