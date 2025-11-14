-- Query 1: Using record links to select from the seller table 
SELECT
	name,
	seller.name
FROM product LIMIT 4;