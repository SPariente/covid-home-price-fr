SELECT
*,
CASE WHEN --Outlier detection on each location using Tukey fences, with 1.5 IQR range
	price_sqm BETWEEN GREATEST(q1-1.5*(q3-q1),0)
								  AND q3+1.5*(q3-q1)
	THEN 1
ELSE 0
END AS outlier
FROM
(
	WITH sqm_query AS
	(
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
				SUM(nombre_pieces_principales) AS nb_rooms,
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
					LOWER(nom_commune) LIKE ANY (
						ARRAY['paris %', 'lyon %', 'marseille %']
					)
				) AS loc_query
				WHERE id_mutation IN (
					SELECT id_mutation FROM fr_home_sales -- Only include simple sales of residential house and apartments
					WHERE type_local IN ('Appartement', 'Maison')
					AND nature_mutation='Vente'
				)
				GROUP BY id_mutation, sale_year, sale_week
			)

			SELECT 
			*, 
			CASE -- Consider the total surface as proxy for carrez_surface if the latter is missing (should be a maximizer)
				WHEN carrez_surface>0 THEN carrez_surface
				WHEN NOT carrez_surface>0 AND total_surface>0 THEN total_surface
				ELSE NULL
			END AS paid_surface
			FROM subquery	
		) AS main_query
	)
	SELECT
	sqm_query.id_mutation AS id_mutation,
	sqm_query.price AS price,
	sqm_query.price_sqm AS price_sqm,
	sqm_query.nb_rooms AS nb_rooms,
	sqm_query.paid_surface AS paid_surface,
	sqm_query.sale_year AS sale_year,
	sqm_query.sale_week AS sale_week,
	sqm_query.id_parcelle AS id_parcelle,
	sqm_query.nom_commune AS nom_commune,
	quart_query.q1 AS q1,
	quart_query.q3 AS q3
	FROM
	sqm_query LEFT JOIN
	(
		SELECT
		nom_commune,
		MAX(CASE WHEN quartile = 1 THEN price_sqm END) AS q1,
		MAX(CASE WHEN quartile = 2 THEN price_sqm END) AS median,
		MAX(CASE WHEN quartile = 3 THEN price_sqm END) AS q3
		FROM
		(
			SELECT 
			nom_commune,
			price_sqm,
			NTILE(4) OVER (PARTITION BY nom_commune ORDER BY price_sqm) AS quartile
			FROM sqm_query
		) AS quart_query
		GROUP BY nom_commune
	) AS quart_query
	ON sqm_query.nom_commune = quart_query.nom_commune
) AS tukey_query
;