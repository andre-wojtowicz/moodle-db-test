SELECT DISTINCT A.name
FROM   Authors A
       JOIN Books B
         ON A.id_author = B.author
WHERE  B.category = 'computer science';