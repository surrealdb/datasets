-- Query 9: using a custom fuction for currency conversion
SELECT 
	product_name,
	fn::pound_to_usd(price) AS price_usd
FROM order LIMIT 4;