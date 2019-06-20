SELECT   category, 
         COUNT(*) num
FROM     Books
GROUP BY category;