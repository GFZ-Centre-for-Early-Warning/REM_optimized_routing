##SENSUM=group
db_host<-"localhost"
db_user<-"postgres"
db_pw<-"postgres"
db_name<-"sensum_demo"
db_schema<-"routing"
db_tbl_street_vertices<-"cologne_streets_vertices_pgr"
db_tbl_samppts<-"samp_pts"
stops_count<-20
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
