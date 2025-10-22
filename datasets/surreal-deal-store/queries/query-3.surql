-- Query 3: Conditional filtering based on an embedded object property.
SELECT 
	name,
	email 
FROM person 
WHERE address.country ?= "England" LIMIT 4;	