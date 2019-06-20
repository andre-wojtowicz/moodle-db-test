SELECT B1.title
FROM   Books B1
       JOIN Books B2
         ON B2.title = 'Fuzzy Logic'
            AND B1.price > B2.price;
SELECT   category, 
         COUNT(*) num
FROM     Books
GROUP BY category;