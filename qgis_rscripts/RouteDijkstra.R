##SENSUM=group
db_host<-"localhost"
db_user<-"postgres"
db_pw<-"postgres"
db_name<-"sensum_demo"
db_schema<-"routing"
db_tbl_stops<-"route_stops_tsp"
db_tbl_streets<-"cologne_streets"
db_col_cost<-"length"
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
