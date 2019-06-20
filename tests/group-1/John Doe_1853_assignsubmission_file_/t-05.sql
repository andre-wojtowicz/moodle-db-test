SELECT A.name
FROM   Authors A
       LEFT OUTER JOIN Books B
                    ON A.id_author = B.author
WHERE  B.title IS NULL;