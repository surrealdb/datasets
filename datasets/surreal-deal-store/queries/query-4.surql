-- Query 4: Conditional filtering using relationships.
SELECT * FROM review
WHERE ->product.sub_category ?= "Activewear" LIMIT 4;