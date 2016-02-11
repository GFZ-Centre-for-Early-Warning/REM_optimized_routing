------------------------------------------------------------------------------------------------------------------------------
--PGROUTING: 1. adjust routable streetnetwork (add weighted cost attribute)
--	     2. create route stops from sample points
--	     3. order stops using TSP based on weighted cost
--	     4. compute shortest path across all ordered stops
--INPUT:     streets table (use grass v.clean with break function before)
--	     route table that holds the line geometry of a previous survey route
--	     point table with stops (in same crs as streets table)
--DEPENDS:   pgr_customfunctions.sql
--DESCR:     computes shortest route through a set of ordered stops while reducing overlap with another route
------------------------------------------------------------------------------------------------------------------------------
--Author: M. Wieland
--Last modified: 9.7.14
------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
--1. add weighted cost attribute to streetnetwork (cost=length*weight*sqrt(count of previous visits))
------------------------------------------------------------------------------------------------------
ALTER TABLE routing.cologne_streets ADD COLUMN wcost_prev double precision;
UPDATE routing.cologne_streets SET wcost_prev = length;
UPDATE routing.cologne_streets 
	SET wcost_prev = length*2*sqrt(a.count) 
	FROM (SELECT DISTINCT gid, count(gid) as count FROM route_dijkstramulti GROUP BY gid) AS a 
	WHERE routing.cologne_streets.gid = a.gid;
--optional: define reverse travelling cost (only needed if specified in pgr function arguments)
ALTER TABLE routing.cologne_streets ADD COLUMN reverse_wcost double precision;
UPDATE routing.cologne_streets SET reverse_wcost = wcost_prev;

------------------------------------------------------------------------------------------------------
--2. create route stops from sample points 
--(note: a random subset of the sample points is used)
------------------------------------------------------------------------------------------------------
SELECT * FROM pgr_createroutestops('routing.cologne_streets_vertices_pgr', 'routing.samples_test', 100);

------------------------------------------------------------------------------------------------------
--3. order stops using TSP based on weighted cost
--(note: use route stops id minus one to define start and stop point = index of points in cost matrix - see tsp with cost matrix documentation)
------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS routing.route_stops_tsp;
SELECT seq, a.id+1 as id, b.node as id2, b.the_geom INTO routing.route_stops_tsp FROM pgr_tsp(
	(SELECT dmatrix from pgr_makecostmatrix('routing.route_stops', 'routing.cologne_streets', 'wcost_prev'))::float8[], 
		63) a LEFT JOIN routing.route_stops b ON (a.id+1 = b.id);
	
------------------------------------------------------------------------------------------------------
--4. compute shortest path across all ordered stops
------------------------------------------------------------------------------------------------------
SELECT * FROM pgr_dijkstramulti('routing.route_stops_tsp', 'routing.cologne_streets', 'wcost_prev');

