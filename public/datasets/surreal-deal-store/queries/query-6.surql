-- Query 6: Get a deduplicated list of products that were ordered
SELECT 
	array::distinct(product_name) as ordered_products
FROM order
GROUP ALL LIMIT 4;