SELECT name
FROM   Authors
WHERE  id_author NOT IN (SELECT author 
                         FROM   Books);