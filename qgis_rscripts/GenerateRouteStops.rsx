##SENSUM=group
##db_host=string localhost
##db_user=string postgres
##db_pw=string
##db_name=string sensum_demo
##db_schema=string routing
##db_tbl_street_vertices=string cologne_streets_vertices_pgr
##db_tbl_samppts=string samp_pts
##stops_count=number 20
library(RPostgreSQL)

#connect to database
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, host=db_host, user=db_user, password=db_pw, dbname=db_name)

#create route stops from sampling points
sql <- paste0("SELECT * FROM pgr_createroutestops('",db_schema,".",db_tbl_street_vertices,"','",db_schema,".",db_tbl_samppts,"',",stops_count,");")
post <- dbGetQuery(con, statement = sql)

#disconnect from database and unload driver
dbDisconnect(con)
dbUnloadDriver(drv)
