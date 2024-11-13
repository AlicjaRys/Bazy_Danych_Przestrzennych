CREATE EXTENSION IF NOT EXISTS postgis;

--import danych w wierszu polecen
shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2018_KAR_GERMANY/T2018_KAR_BUILDINGS.shp" T2018_KAR_BUILDINGS | psql -h localhost -p 5432 -U postgres -d Buildings
shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2019_KAR_GERMANY/T2019_KAR_BUILDINGS.shp" T2019_KAR_BUILDINGS | psql -h localhost -p 5432 -U postgres -d Buildings

shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2018_KAR_GERMANY/T2018_KAR_POI_TABLE.shp" T2018_KAR_POI_TABLE | psql -h localhost -p 5432 -U postgres -d Buildings
shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2019_KAR_GERMANY/T2019_KAR_POI_TABLE.shp" T2019_KAR_POI_TABLE | psql -h localhost -p 5432 -U postgres -d Buildings

shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2019_KAR_GERMANY/T2019_KAR_STREETS.shp" T2019_KAR_STREETS  | psql -h localhost -p 5432 -U postgres -d Buildings

shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2019_KAR_GERMANY/T2019_KAR_STREET_NODE.shp" T2019_KAR_STREET_NODE  | psql -h localhost -p 5432 -U postgres -d Buildings

shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2019_KAR_GERMANY/T2019_KAR_LAND_USE_A.shp" T2019_KAR_LAND_USE_A  | psql -h localhost -p 5432 -U postgres -d Buildings

shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2019_KAR_GERMANY/T2019_KAR_RAILWAYS.shp" T2019_KAR_RAILWAYS  | psql -h localhost -p 5432 -U postgres -d Buildings
shp2pgsql.exe "C:/RYS/Dokumenty/STUDIA/V semestr/Bazy Danych Przestrzennych/Ćwiczenia/4_cwiczenia/Karlsruhe_Germany_Shapefile/T2019_KAR_GERMANY/T2019_KAR_WATER_LINES.shp" T2019_KAR_WATER_LINES | psql -h localhost -p 5432 -U postgres -d Buildings

--1. Zmiana pomiedzy 2018 a 2019
CREATE TABLE new_buildings AS
SELECT b.gid, b.geom
FROM T2019_KAR_BUILDINGS b
LEFT JOIN T2018_KAR_BUILDINGS a 
ON ST_Equals(a.geom, b.geom)
WHERE a.gid IS NULL;

CREATE TABLE renovated_buildings AS
SELECT b.gid AS gid_2019, a.gid AS gid_2018, b.geom AS geom_2019, a.geom AS geom_2018
FROM T2018_KAR_BUILDINGS a
JOIN T2019_KAR_BUILDINGS b 
ON a.gid = b.gid
WHERE NOT ST_Equals(a.geom, b.geom);

CREATE TABLE changed_buildings AS
SELECT gid, 'new' AS change_type, geom FROM new_buildings
UNION ALL
SELECT gid_2019 AS id, 'renovated' AS change_type, geom_2019 AS geom FROM renovated_buildings;

SELECT * FROM changed_buildings
ORDER BY gid;

--2. nowe POI w promieniu 500m (ST buffer st_intersects)
CREATE TABLE new_pois AS
SELECT b.*
FROM t2019_kar_poi_table b
LEFT JOIN t2018_kar_poi_table a 
ON ST_Equals(a.geom, b.geom)
WHERE a.gid IS NULL;

SELECT p.type, COUNT(*) AS new_poi_count
FROM new_pois p
JOIN changed_buildings b 
ON ST_Intersects(ST_Buffer(b.geom, 500), p.geom)
GROUP BY p.type
ORDER BY new_poi_count DESC;

--3. Tabela i transformacja do ukladu wspolrzednych (create table streets_reprojected as selecr * from T2019_KAR_STREETS; transformacja (st_setsrid = 3068)
SELECT DISTINCT ST_SRID(geom) FROM T2019_KAR_STREETS;

UPDATE T2019_KAR_STREETS
SET geom = ST_SetSRID(geom, 4326)
WHERE ST_SRID(geom) = 0;

CREATE TABLE streets_reprojected AS
SELECT 
    gid, 
    link_id, 
    st_name, 
    ref_in_id, 
    nref_in_id, 
    func_class, 
    speed_cat, 
    fr_speed_l, 
    to_speed_l, 
    dir_travel, 
    ST_Transform(geom, 3068) AS geom
FROM 
    T2019_KAR_STREETS;

SELECT * FROM streets_reprojected

--4. Tabela z punktami X i Y
CREATE TABLE input_points (
    id SERIAL PRIMARY KEY,
    geom geometry(Point, 4326)
);

INSERT INTO input_points (geom)
VALUES
    (ST_SetSRID(ST_MakePoint(8.36093, 49.03174), 4326)),
    (ST_SetSRID(ST_MakePoint(8.39876, 49.00644), 4326));

SELECT id, ST_SRID(geom) FROM input_points;

--5. Aktualizacja danych w tabeli
ALTER TABLE input_points
  ALTER COLUMN geom TYPE geometry(Point, 3068)
  USING ST_Transform(geom, 3068);

UPDATE input_points
SET geom = ST_Transform(geom, 3068);

--6. Skrzyzowania 200m od linii (st_buffer, st_makeline, st_contains)
UPDATE T2019_KAR_STREET_NODE
SET geom = ST_SetSRID(geom, 4326)
WHERE ST_SRID(geom) = 0;

SELECT node.gid, node.geom
FROM T2019_KAR_STREET_NODE AS node
JOIN (
    SELECT ST_Buffer(ST_MakeLine(ST_Transform(geom, 3068) ORDER BY id), 200) AS buffer_geom
    FROM input_points
) AS line_buffer
ON ST_Contains(line_buffer.buffer_geom, ST_Transform(node.geom, 3068));


--7. Sklepy sportowe (st_buffer, st_intersects)
SELECT COUNT(*) AS sport_store_count
FROM T2019_KAR_POI_TABLE AS poi
JOIN T2019_KAR_LAND_USE_A AS park
ON ST_Intersects(ST_Buffer(park.geom, 300), poi.geom)
WHERE poi.type = 'Sporting Goods Store';

--8. Punkty przecięcia torów kolejowych (st_intersects)
CREATE TABLE T2019_KAR_BRIDGES AS
SELECT ST_Intersection(rail.geom, water.geom) AS geom
FROM T2019_KAR_RAILWAYS AS rail
JOIN T2019_KAR_WATER_LINES AS water
ON ST_Intersects(rail.geom, water.geom);

