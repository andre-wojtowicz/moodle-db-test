SELECT A.name
FROM   Authors A
WHERE  NOT EXISTS (SELECT * 
                   FROM   Books B
                   WHERE  A.id_author = B.author);