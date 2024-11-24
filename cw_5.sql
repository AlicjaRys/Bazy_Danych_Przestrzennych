-- Tworzenie tabeli 
CREATE TABLE obiekty (
	id INTEGER PRIMARY KEY, 
	name VARCHAR(255), 
	geom GEOMETRY
);

--1. Dodawanie obiektów
INSERT INTO obiekty VALUES
(1, 'obiekt1', ST_GeomFromText('COMPOUNDCURVE((0 1, 1 1), CIRCULARSTRING(1 1, 2 0, 3 1),
CIRCULARSTRING(3 1, 4 2, 5 1), (5 1, 6 1) )', 0)),
(2, 'obiekt2', ST_GeomFromText('GEOMETRYCOLLECTION(LINESTRING(10 2, 10 6, 14 6),
CIRCULARSTRING(14 6, 16 4, 14 2), CIRCULARSTRING(14 2, 12 0, 10 2),
CIRCULARSTRING(11 2, 12 3, 13 2),CIRCULARSTRING(13 2, 12 1, 11 2) )', 0)),
(3, 'obiekt3', ST_GeomFromText('LINESTRING(10 17, 12 13, 7 15, 10 17)', 0)),
(4, 'obiekt4', ST_GeomFromText('LINESTRING(20 20, 25 25, 27 24, 25 22, 26 21, 22 19, 20.5 19.5)', 0)),
(5, 'obiekt5', ST_GeomFromText('GEOMETRYCOLLECTION(POINTZ(30 30 59),POINTZ(38 32 234) )', 0)),
(6, 'obiekt6', ST_Collect( ST_GeomFromText('LINESTRING(1 1, 3 2)', 0), ST_GeomFromText('POINT(4 2)', 0)));


--2. Wyznacz pole powierzchni bufora o wielkości 5 jednostek, który został utworzony wokół najkrótszej linii łączącej obiekt 3 i 4. 
SELECT ST_Area( ST_Buffer( ST_ShortestLine(o3.geom, o4.geom), 5))
FROM (SELECT * FROM obiekty WHERE id=3) AS o3,
	 (SELECT * FROM obiekty WHERE id=4) AS o4;

--3. Zamień obiekt4 na poligon. Warunek: obiekt domknięty
UPDATE obiekty
SET geom = ST_Union(geom, ST_GeomFromText('LINESTRING(20.5 19.5, 20 20)', 0))
WHERE id=4 AND ST_IsClosed(geom) = false;

UPDATE obiekty
SET geom = ST_MakePolygon(ST_LineMerge(geom))
WHERE id=4;

--4. Obiekt7 złożony z obiektu 3 i obiektu 4
INSERT INTO obiekty VALUES
(7, 'obiekt7', ST_UNION( (SELECT geom FROM obiekty WHERE id=3),
                         (SELECT geom FROM obiekty WHERE id=4)));

--5. Pole powierzchni
SELECT SUM(ST_Area( ST_Buffer(geom, 5)))
FROM obiekty
WHERE ST_HasArc(geom) = false;
