SELECT
id_mutation,
MAX(valeur_fonciere) AS price,
nature_mutation,
SUM(surface_reelle_bati) AS total_surface,
SUM(
	COALESCE(lot1_surface_carrez, 0)+
	COALESCE(lot2_surface_carrez, 0)+
	COALESCE(lot3_surface_carrez, 0)+
	COALESCE(lot4_surface_carrez, 0)+
	COALESCE(lot5_surface_carrez, 0)
) AS carrez_surface,
DATE_PART('year', date_mutation) AS sale_year,
DATE_PART('week', date_mutation) AS sale_week,
MAX(id_parcelle) AS id_parcelle,
MAX(nom_commune) AS nom_commune
FROM fr_home_sales
WHERE 
	LOWER(nom_commune) LIKE 'lyon %'
AND id_mutation IN (
	SELECT id_mutation FROM fr_home_sales
	WHERE type_local IN ('Appartement', 'Maison')
	AND nature_mutation='Vente'
)
GROUP BY id_mutation, nature_mutation, sale_year, sale_week
;