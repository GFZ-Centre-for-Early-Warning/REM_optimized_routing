##SENSUM=group
##db_host=string localhost
##db_user=string postgres
##db_pw=string
##db_name=string sensum_demo
##db_schema=string routing
##db_tbl_stops=string route_stops_tsp
##db_tbl_streets=string cologne_streets
##db_col_cost=string length
library(RPostgreSQL)

#connect to database
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, host=db_host, user=db_user, password=db_pw, dbname=db_name)

#create route stops from sampling points
sql <- paste0("SELECT * FROM pgr_dijkstramulti('",db_schema,".",db_tbl_stops,"','",db_schema,".",db_tbl_streets,"','",db_col_cost,"');")
post <- dbGetQuery(con, statement = sql)

#disconnect from database and unload driver
dbDisconnect(con)
dbUnloadDriver(drv)
