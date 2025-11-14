-- Query 2: Using graph relations to select from the person and product table
SELECT
	time.created_at as order_date,
	product_name,
	<-person.name as person_name,
	->product.details
FROM order LIMIT 4;