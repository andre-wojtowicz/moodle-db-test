Select DISTINCT name
FROM   Authors
       JOIN Books ON id_author = author
WHERE  category = 'computer science';