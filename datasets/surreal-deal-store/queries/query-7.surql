-- Query 7: Get the average price per product category
SELECT 
	->product.category AS product_category,
	math::mean(price) AS avg_price
FROM order
GROUP BY product_category
ORDER BY avg_price DESC LIMIT 4;