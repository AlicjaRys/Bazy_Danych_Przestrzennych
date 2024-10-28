--1
SELECT matchid, player
FROM gole
WHERE teamid = 'POL';

--2
SELECT * 
FROM mecze 
WHERE id = 1004;

--3
SELECT player, gole.teamid, stadium, mdate 
FROM mecze 
JOIN gole ON mecze.id = gole.matchid 
WHERE gole.teamid = 'POL';


--4
SELECT team1, team2, player 
FROM mecze 
JOIN gole ON mecze.id = gole.matchid 
WHERE player LIKE 'Mario%';


--5
SELECT gole.player, gole.teamid, druzyny.coach, gole.gtime 
FROM gole 
JOIN druzyny ON gole.teamid = druzyny.id 
WHERE gole.gtime <= 10;


--6
SELECT druzyny.teamname, mecze.mdate 
FROM druzyny 
JOIN mecze ON druzyny.id = mecze.team1 OR druzyny.id = mecze.team2 
WHERE druzyny.coach = 'Franciszek Smuda';


--7
SELECT player 
FROM gole 
JOIN mecze ON gole.matchid = mecze.id 
WHERE mecze.stadium = 'National Stadium, Warsaw';


--8
SELECT player, gtime 
FROM mecze 
JOIN gole ON mecze.id = gole.matchid 
WHERE (team1 = 'GER' AND gole.teamid != 'GER') 
   OR (team2 = 'GER' AND gole.teamid != 'GER');


--9
SELECT druzyny.teamname, COUNT(gole.player) AS liczba_goli 
FROM druzyny 
JOIN gole ON druzyny.id = gole.teamid 
GROUP BY druzyny.teamname 
ORDER BY liczba_goli DESC;


--10
SELECT mecze.stadium, COUNT(gole.player) AS liczba_goli 
FROM mecze 
JOIN gole ON mecze.id = gole.matchid 
GROUP BY mecze.stadium 
ORDER BY liczba_goli DESC;

