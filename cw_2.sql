--2
CREATE DATABASE City;

--3
CREATE EXTENSION postgis;

--4
CREATE TABLE buildings (
    id SERIAL PRIMARY KEY,
    geometry GEOMETRY(POLYGON),
    name VARCHAR(255)
);

CREATE TABLE roads (
    id SERIAL PRIMARY KEY,
    geometry GEOMETRY(LINESTRING),
    name VARCHAR(255)
);

CREATE TABLE poi (
    id SERIAL PRIMARY KEY,
    geometry GEOMETRY(POINT),
    name VARCHAR(255)
);

--5
-- Buildings
INSERT INTO buildings (id, geometry, name) VALUES
    (1, ST_GeomFromText('POLYGON((8 1.5, 10.5 1.5, 10.5 4, 8 4, 8 1.5))'), 'BuildingA'),
    (2, ST_GeomFromText('POLYGON((4 7, 6 7, 6 5, 4 5, 4 7))'), 'BuildingB'),
    (3, ST_GeomFromText('POLYGON((3 6, 5 6, 5 8, 3 8, 3 6))'), 'BuildingC'),
    (4, ST_GeomFromText('POLYGON((9 8, 10 8, 10 9, 9 9, 9 8))'), 'BuildingD'),
    (5, ST_GeomFromText('POLYGON((1 1, 2 1, 2 2, 1 2, 1 1))'), 'BuildingF');

-- Roads
INSERT INTO roads (id, geometry, name) VALUES
    (1, ST_GeomFromText('LINESTRING(0 4.5, 12 4.5)'), 'RoadX'),
    (2, ST_GeomFromText('LINESTRING(7.5 0, 7.5 10.5)'), 'RoadY');

-- Points of Interest (POI)
INSERT INTO poi (id, geometry, name) VALUES
    (1, ST_GeomFromText('POINT(1 3.5)'), 'G'),
    (2, ST_GeomFromText('POINT(5.5 1.5)'), 'H'),
    (3, ST_GeomFromText('POINT(9.5 6)'), 'I'),
    (4, ST_GeomFromText('POINT(6.5 6)'), 'J'),
    (5, ST_GeomFromText('POINT(6 9.5)'), 'K');

-- 6
   
--a
   SELECT SUM(ST_Length(geometry)) AS total_length FROM roads;
--b
  SELECT ST_AsText(geometry) AS wkt_geometry, 
       ST_Area(geometry) AS area, 
       ST_Perimeter(geometry) AS perimeter 
  FROM buildings 
  WHERE name = 'BuildingA';
--c
 SELECT name, ST_Area(geometry) AS area 
FROM buildings 
ORDER BY name;
--d
SELECT name, ST_Perimeter(geometry) AS perimeter 
FROM buildings 
ORDER BY ST_Area(geometry) DESC 
LIMIT 2;
--e
SELECT ST_Distance(b.geometry, p.geometry) AS shortest_distance 
FROM buildings b, poi p 
WHERE b.name = 'BuildingC' AND p.name = 'K';
--f
SELECT ST_Area(ST_Difference(bc.geometry, ST_Buffer(bb.geometry, 0.5))) AS area_difference
FROM buildings bc, buildings bb 
WHERE bc.name = 'BuildingC' AND bb.name = 'BuildingB';
--g
SELECT b.name
FROM buildings b
JOIN roads r ON r.name = 'RoadX'
WHERE ST_Y(ST_Centroid(b.geometry)) > ST_Y(ST_Centroid(r.geometry));
--h
 SELECT ST_Area(ST_SymmetricDifference(
                bc.geometry, 
                ST_GeomFromText('POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))')
              )) AS non_common_area
FROM buildings bc 
WHERE bc.name = 'BuildingC';

