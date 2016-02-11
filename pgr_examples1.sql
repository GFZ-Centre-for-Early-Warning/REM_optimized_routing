------------------------------------------------------------------------------------------------------------------------------
--PGROUTING: 1. create routable streetnetwork
--	     2. create route stops from sample points
--	     3. order stops using TSP based on street length (with custom costmatrix)
--	     4. compute shortest path across all ordered stops
--INPUT:     streets table (use grass v.clean with break function before)
--	     point table with stops (in same crs as streets table)
--DEPENDS:   pgr_customfunctions.sql
--DESCR:     computes shortest route through a set of ordered stops using a custom cost matrix (with length as cost attribute)
------------------------------------------------------------------------------------------------------------------------------
--Author: M. Wieland
--Last modified: 20.6.14
------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
--1. create a routable streetnetwork 
--(note: streets table should at least contain the columns "gid" and "the_geom". Geometry should be cleaned beforehand (e.g. with GRASS v.clean))
------------------------------------------------------------------------------------------------------
SELECT * FROM pgr_createnetwork('routing.osm_streets');

------------------------------------------------------------------------------------------------------
--2. create route stops from sample points 
--(note: a random subset of the sample points is used. sample points should have same SRID as streetnetwork)
------------------------------------------------------------------------------------------------------
SELECT * FROM pgr_createroutestops('routing.osm_streets_vertices_pgr', 'routing.samplepoints_sp001', 150);

------------------------------------------------------------------------------------------------------
--3. order route stops using TSP with street length as cost attribute
--(note: use route stops id minus one to define start and stop point = index of points in cost matrix - see tsp with cost matrix documentation)
------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS routing.route_stops_tsp;
SELECT seq, a.id+1 as id, b.node as id2, b.the_geom INTO routing.route_stops_tsp FROM pgr_tsp(
	(SELECT dmatrix from pgr_makecostmatrix('routing.route_stops', 'routing.osm_streets', 'length'))::float8[], 
		0) a LEFT JOIN routing.route_stops b ON (a.id+1 = b.id);	

------------------------------------------------------------------------------------------------------
--4. compute shortest path across all ordered stops
------------------------------------------------------------------------------------------------------
SELECT * FROM pgr_dijkstramulti('routing.routestops_sp001_tsp', 'routing.osm_streets', 'length');

