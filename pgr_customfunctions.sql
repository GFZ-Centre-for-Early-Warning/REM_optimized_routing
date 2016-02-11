-------------------------------------------------------------------------------------------------------------------------------------
--PGROUTING: custom functions
--	     1. pgr_dijkstra(varchar, integer, integer): wrapper for a simple dijkstra function with geometry output
--	     2. pgr_dijkstramulti(varchar, varchar): function to run dijkstra iteratively on a sequence of nodes
--	     3. pgr_makecostmatrix(varchar, varchar, text): function to create a custom cost matrix (e.g. for TSP with street length)
--	     4. pgr_createnetwork(varchar): function to create a routable street network
--	     5. pgr_createroutestops(varchar, integer): function to create route stops from a set of sample points
--DEPENDS:   pgrouting 2.0, postgis 2.0
--DESCR:     adds custom functions to the standard pgrouting functionality
-------------------------------------------------------------------------------------------------------------------------------------
--Author: M. Wieland
--Last modified: 20.6.14
------------------------------------------------------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgrouting;
CREATE SCHEMA routing;

-----------------------------------------------------------
--wrapper for simple dijkstra function with geometry output
-----------------------------------------------------------
CREATE OR REPLACE FUNCTION pgr_dijkstra(
                IN tbl varchar,
                IN col_cost text,
                IN source integer,
                IN target integer,
                OUT seq integer,
                OUT gid integer,
                OUT cost double precision,
                OUT geom geometry
        )
        RETURNS SETOF record AS
$BODY$
DECLARE
        sql     text;
        rec     record;
BEGIN
        seq     := 0;
        sql     := 'SELECT gid,cost,the_geom FROM ' ||
                        'pgr_dijkstra(''SELECT gid as id, source::int, target::int, '
                                        || quote_ident(col_cost) || '::float AS cost FROM '
                                        || tbl || ''', '
                                        || quote_literal(source) || ', '
                                        || quote_literal(target) || ' , false, false), '
                                || tbl || ' WHERE id2 = gid ORDER BY seq';

        FOR rec IN EXECUTE sql
        LOOP
                seq     := seq + 1;
                gid     := rec.gid;
                cost	:= rec.cost;
                geom    := rec.the_geom;
                RETURN NEXT;
        END LOOP;
        RETURN;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


-------------------------------------------------------------------------------------------------------------------
--run dijkstra function multiple times to output shortest path through multiple stops (e.g. sorted points from TSP)
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgr_dijkstramulti(
		IN tbl_stops varchar,
		IN tbl_streets varchar,
		IN col_cost text,
		OUT route_dijkstramulti varchar
        )
        RETURNS varchar AS
$BODY$
DECLARE
        sql     text;
        rec 	record;
BEGIN
	DROP TABLE IF EXISTS routing.route_dijkstramulti;
	CREATE TABLE routing.route_dijkstramulti (seq integer, gid integer, cost double precision, geom geometry);
        FOR rec IN EXECUTE 'SELECT seq FROM ' || tbl_stops || ';' LOOP
	    EXECUTE 'INSERT INTO routing.route_dijkstramulti SELECT * FROM pgr_dijkstra(''' || tbl_streets || ''', ''' || col_cost || ''', (SELECT id2 FROM ' || tbl_stops || ' WHERE seq='|| rec.seq ||'), (SELECT id2 FROM ' || tbl_stops || ' WHERE seq='|| rec.seq+1 ||'));';
	END LOOP;
        RETURN;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


--------------------------------------------------------
--Create custom cost matrix
--In: tbl_stops: table that holds the stops to be visited (should have at least id, node fields where id is a serial and node identifies the network nodes of the stops)
--    tbl_streets: table that holds the routing network (should have at least a cost field - e.g. length - and be created with pgr_topology to have source and target fields)
--    col_cost: specifies which field in tbl_streets to use as cost factor
--------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pgr_makecostmatrix(
		IN tbl_stops varchar, 
		IN tbl_streets varchar,
		IN col_cost text,
		OUT dmatrix double precision[], 
		OUT ids integer[]
	)
	RETURNS record AS
$BODY$
DECLARE
    sql text;
    r record; 
BEGIN
    dmatrix := array[]::double precision[];
    ids := array[]::integer[];

    sql := 'with nodes as (SELECT id, node FROM ' || tbl_stops || ')
        select i, array_agg(dist) as arow from (
            select a.id as i, b.id as j, (SELECT sum(cost) FROM pgr_dijkstra(''
                SELECT gid AS id,
                         source::integer,
                         target::integer,
                         ' || col_cost || '::double precision AS cost
                        FROM ' || tbl_streets || ''',
                a.node, b.node, false, false)) as dist
              from nodes a, nodes b
             order by a.id, b.id
           ) as foo group by i order by i';

    for r in execute sql loop
        dmatrix := array_cat(dmatrix, array[r.arow]);
        ids := ids || array[r.i];
    end loop;

END;
$BODY$
  LANGUAGE plpgsql STABLE COST 10;

----------------------------------------------------------------------------------------------------------------
--create routable streetnetwork (note: input table should have at least the following columns - gid, the_geom)--
----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgr_createnetwork(
		IN tbl_streets varchar,
		OUT pgr_network varchar
        )
        RETURNS varchar AS
$BODY$
BEGIN
	EXECUTE 
	'--add "source" and "target" column
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN "source" integer;
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN "target" integer;
	 --create length column
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN "length" double precision;
	 UPDATE ' || tbl_streets || ' SET length = ST_Length(ST_Transform(the_geom,32635));
	 --create pgr topology
	 SELECT pgr_createTopology(''' || tbl_streets || ''', 0.00001, ''the_geom'', ''gid'');
	 --create indices
	 CREATE INDEX source_idx ON ' || tbl_streets || ' ("source");
	 CREATE INDEX target_idx ON ' || tbl_streets || ' ("target");
	
	 --option1: analyse network topology (note: check messages for errors) - http://docs.pgrouting.org/2.0/en/doc/src/tutorial/analytics.html#analytics
	 SELECT pgr_analyzeGraph(''' || tbl_streets || ''', 0.00001, ''the_geom'', ''gid'');
	
	 --option2: define reverse travelling cost (only needed if specified in pgr function arguments)
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN reverse_cost double precision;
	 UPDATE ' || tbl_streets || ' SET reverse_cost = length;
	';
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


------------------------------------------
--create route stops from sample points --
------------------------------------------
CREATE OR REPLACE FUNCTION pgr_createroutestops(
		IN tbl_streets_vertices varchar,
		IN tbl_samples varchar,
		IN nr_stops integer,
		OUT pgr_stops varchar
        )
        RETURNS varchar AS
$BODY$
BEGIN
	--create a random subset of a larger set of sample_points
	CREATE TABLE routing.sample_points (id serial, the_geom geometry);
	EXECUTE 'INSERT INTO routing.sample_points (the_geom) SELECT the_geom FROM ' || tbl_samples || ' ORDER BY random() limit ' || nr_stops || ';';
	--create table that holds the route stops
	DROP TABLE IF EXISTS routing.route_stops cascade;
	CREATE TABLE routing.route_stops (id serial, x double precision, y double precision, node integer, the_geom geometry);
	INSERT INTO routing.route_stops (id) select id from routing.sample_points;
	--get nearest network node to sample point and write its id as node to stops table
	EXECUTE 'UPDATE routing.route_stops SET node = c.node FROM(
		 SELECT DISTINCT ON (a.id) a.id as sample, b.id as node, ST_Distance(a.the_geom, b.the_geom) as distance
		 FROM routing.sample_points as a, ' || tbl_streets_vertices || ' as b group by sample, node, distance ORDER BY sample, distance asc) c
		 WHERE id = c.sample;';
	--delete duplicate nodes from stops table (it can happen that several stops have the same nearest node. in this case only use the node once as stop)
	DELETE FROM routing.route_stops
	WHERE id IN (SELECT id
		    FROM (SELECT id,
				 row_number() over (partition by node order by id) as rnum
		       FROM routing.route_stops) t
		WHERE t.rnum > 1);
	--clean id column
	ALTER TABLE routing.route_stops DROP column id;
	ALTER TABLE routing.route_stops ADD column id serial;
	--add also the_geom to the route stops and calculate x and y coordinates
	EXECUTE 'UPDATE routing.route_stops SET the_geom = ' || tbl_streets_vertices ||'.the_geom FROM ' || tbl_streets_vertices || ' WHERE routing.route_stops.node = ' || tbl_streets_vertices ||'.id;';
	UPDATE routing.route_stops SET x = st_x(the_geom), y = st_y(the_geom);
	--drop sample_points table
	DROP TABLE routing.sample_points;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;
