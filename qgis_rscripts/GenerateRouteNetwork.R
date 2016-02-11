##SENSUM=group
db_host<-"localhost"
db_user<-"postgres"
db_pw<-"postgres"
db_name<-"sensum_demo"
db_schema<-"test"
db_tbl_streets<-"cologne_streets"
library(RPostgreSQL)

#connect to database
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, host=db_host, user=db_user, password=db_pw, dbname=db_name)

#create route network from streets table
sql <- paste0("SELECT * FROM pgr_createnetwork('",db_schema,".",db_tbl_streets,"');")
post <- dbGetQuery(con, statement = sql)
sql

#disconnect from database and unload driver
dbDisconnect(con)
dbUnloadDriver(drv)
