-- Query 5: Count orders based on order status
SELECT count() FROM order
WHERE order_status IN [ "processed", "shipped"]
GROUP ALL LIMIT 4;