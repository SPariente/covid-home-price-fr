#SQL access library
library(RPostgreSQL)
library(RPostgres)
library(DBI)
#Generic data manipulation library
library(tidyverse)
#Data frame ordering library
library(wrapr)


#This file aims to use the R 'segmented' library, offering more in-depth
#analyses of piecewise linear regressions than what is available in Python.

#Connect to PostgreSQL DB
db<-'fr_home_covid'
host_db<-'localhost'
db_port<-'5432'
#Hidden credentials
source("credentials.R")

con<-dbConnect(RPostgres::Postgres(),
               dbname=db, 
               host=host_db,
               port=db_port,
               user=db_user,
               password=db_password)

#Extract relevant data
sales_data_cities<-dbGetQuery(con, statement = read_file('price_query_combined.sql'))

#Get column names
colnames(sales_data_cities)

#Remove last week of year + last report week
max_year<-sales_data_cities %>% select(sale_year) %>% max()
max_year_lastweek<-sales_data_cities %>% filter(sale_year==max_year) %>% select(sale_week) %>% max()

sales_data_cities<-sales_data_cities %>% filter(
  sale_week<=52 
  & ((sale_year!=max_year)| (sale_week!=max_year_lastweek))
)

#We can check the dimensions to validate we have the same database in both R and Python
dim(sales_data_cities)

summary(sales_data_cities)

#Function to extract city name
city_name_func <- function(loc) {
  city_name <- str_replace(loc, "\\s.*", "");
  city_name
}

#Get location names
communes <- sales_data_cities %>% select(nom_commune)

#Add city names to data
sales_data_cities <- sales_data_cities %>% mutate(
  city = apply(communes, 1, city_name_func)
)

avg_price_data_city <- sales_data_cities %>%
  filter(
    outlier==1
    ) %>%
  group_by(
    sale_year, sale_week, city
    ) %>% 
  summarize(
    mean=mean(price_sqm)
    ) %>%
  ungroup()

for (loc in (avg_price_data_city %>% select(city) %>% unique())) {
  print(loc)
}

#Ensure increasing order for dates (years, weeks)
avg_price_data_city <- avg_price_data_city[
  order(avg_price_data_city$sale_year, avg_price_data_city$sale_week), ]


#Piecewise linear regression library
library(segmented)

#Get unique cities names
unique_cities <- avg_price_data_city$city %>%
  unique()

#Test for segmented linear regression, using Muggeo's approach
#implemented in the 'segmented' package
cities <- c()
pvals <- c()
breakpoints <- c()

#Define colors for plots
colors <- c("Observed values" = "black", "Segmented regression fit" = "red")

set.seed(50)
for (loc in unique_cities) {
  cities <- cities %>% append(loc)
  
  city_data <- avg_price_data_city %>% filter(city == loc)
  dati <- data.frame(x=1:dim(city_data)[1], y=city_data$mean)
  out.lm <- lm(y~x, data=dati)
  pvals <- pvals %>% append(davies.test(out.lm)$p.value)
  
  o<-segmented(out.lm)
  breakpoints <- breakpoints %>% append(summary.segmented(o)$psi[,2])
  
  p <- dati %>% mutate(
    fit_model = o$fitted.values) %>%
    ggplot(aes(x=x, y=y)) +
    geom_point(aes(color='Observed values')) +
    geom_line(aes(x=x, y=fit_model,
                  color='Segmented regression fit'),
              size = 1) + 
    labs(x = "Weeks since first observation",
         y = "Price per sq. meter",
         title = str_flatten(c(loc, "price per sq. meter over time,\n with segmented regression"), " "))+
    scale_color_manual(values = colors) +
    theme(legend.position="top")
  ggsave(str_flatten(c('plots/', loc, "_segm_plot.png"), ""))
}

#Format to data frame to export
breaks_df <- data.frame(
  cities = cities,
  pvals = pvals,
  breakpoints = breakpoints
)

breaks_df %>% write.csv(file="data/breakpoints.csv")
