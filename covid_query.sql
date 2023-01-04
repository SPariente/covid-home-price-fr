-- Extract the weekly number of new cases and deaths for France
SELECT
DATE_PART('year', report_date) AS report_year,
DATE_PART('week', report_date) AS report_week,
SUM(new_cases) AS new_cases,
SUM(new_deaths) AS new_deaths
FROM covid_cases
WHERE
country='France'
GROUP BY
report_year, report_week
;