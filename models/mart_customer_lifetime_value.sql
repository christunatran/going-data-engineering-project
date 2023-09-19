WITH base AS (
  SELECT 
    c.customer_id,
    c.signup_date,
    SUM(i.amount) as total_spent
  FROM customers c
  JOIN invoices i ON c.customer_id = i.customer_id
  GROUP BY 1,2
)
SELECT 
  customer_id,
  signup_date,
  total_spent AS lifetime_value
FROM base