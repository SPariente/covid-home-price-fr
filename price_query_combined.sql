SELECT
*,
CASE -- Compute price per sq. meter (NULL if impossible to compute)
	WHEN paid_surface>0 THEN price/paid_surface
	ELSE NULL
END AS price_sqm

FROM(
	WITH subquery as(
		SELECT
		id_mutation,
		MAX(valeur_fonciere) AS price,
		nature_mutation,
		SUM(surface_reelle_bati) AS total_surface,
		SUM(
			COALESCE(lot1_surface_carrez, 0)+ -- Avoid NULL values in SUM
			COALESCE(lot2_surface_carrez, 0)+
			COALESCE(lot3_surface_carrez, 0)+
			COALESCE(lot4_surface_carrez, 0)+
			COALESCE(lot5_surface_carrez, 0)
		) AS carrez_surface,
		DATE_PART('year', date_mutation) AS sale_year, -- Extract year
		DATE_PART('week', date_mutation) AS sale_week, -- Extract week in year
		MAX(id_parcelle) AS id_parcelle,
		MAX(nom_commune) AS nom_commune
		FROM ( -- Subquery to extract specific cities, creates time issues if part of main_query
			SELECT * FROM fr_home_sales
			WHERE -- Only focus on a few (large) cities for POC
			LOWER(nom_commune) LIKE 'paris %'
			OR LOWER(nom_commune) LIKE 'lyon %'
			OR LOWER(nom_commune) LIKE 'marseille %'
		) AS loc_query
		WHERE id_mutation IN (
			SELECT id_mutation FROM fr_home_sales -- Only include simple sales of residential house and apartments
			WHERE type_local IN ('Appartement', 'Maison')
			AND nature_mutation='Vente'
		)
		GROUP BY id_mutation, nature_mutation, sale_year, sale_week
	)
	
	SELECT 
	*, 
	CASE -- Consider the total surface as proxy for carrez_surface if the latter is missing (should be a maximizer)
		WHEN carrez_surface>0 THEN carrez_surface
		WHEN NOT carrez_surface>0 AND total_surface>0 THEN total_surface
		ELSE NULL
	END AS paid_surface
	FROM subquery	
) AS main_query;