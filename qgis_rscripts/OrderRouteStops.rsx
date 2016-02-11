##SENSUM=group
##db_host=string localhost
##db_user=string postgres
##db_pw=string
##db_name=string sensum_demo
##db_schema=string routing
##db_tbl_stops=string route_stops
##db_tbl_streets=string cologne_streets
##db_col_cost=string length
##start_id=number 1
##stop_id=number 0
##loop=boolean TRUE
library(RPostgreSQL)

#connect to database
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, host=db_host, user=db_user, password=db_pw, dbname=db_name)

#create route stops from sampling points
sql <- paste0("DROP TABLE IF EXISTS ",db_schema,".route_stops_tsp;")
post <- dbGetQuery(con, statement = sql)

#adjust start and stop values to use id-1 for routing
start_id<-start_id-1
stop_id<-stop_id-1

if (loop)
{
  #option1: order stops in a loop only using start_id
  sql <- paste0("SELECT seq, a.id+1 as id, b.node as id2, b.the_geom INTO ",db_schema,".route_stops_tsp ","FROM pgr_tsp((SELECT dmatrix from pgr_makecostmatrix('",db_schema,".",db_tbl_stops,"','",db_schema,".",db_tbl_streets,"','",db_col_cost,"'))::float8[],",start_id,") a LEFT JOIN ",db_schema,".",db_tbl_stops," b ON (a.id+1 = b.id);")
  post <- dbGetQuery(con, statement = sql)
} else
{
  #option2: order stops between start and stop id
  sql <- paste0("SELECT seq, a.id+1 as id, b.node as id2, b.the_geom INTO ",db_schema,".route_stops_tsp ","FROM pgr_tsp((SELECT dmatrix from pgr_makecostmatrix('",db_schema,".",db_tbl_stops,"','",db_schema,".",db_tbl_streets,"','",db_col_cost,"'))::float8[],",start_id,",",stop_id,") a LEFT JOIN ",db_schema,".",db_tbl_stops," b ON (a.id+1 = b.id);")
  post <- dbGetQuery(con, statement = sql)
}

#disconnect from database and unload driver
dbDisconnect(con)
dbUnloadDriver(drv)
