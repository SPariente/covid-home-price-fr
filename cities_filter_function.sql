CREATE OR REPLACE FUNCTION filter_cities(VARIADIC cities_name TEXT[] = NULL)
-- Function to extract specific cities from the entire table
RETURNS SETOF fr_home_sales
AS $$
	SELECT * FROM fr_home_sales
	WHERE 
		LOWER(nom_commune) LIKE ANY(cities_name)
$$ LANGUAGE SQL;