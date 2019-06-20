SELECT AVG(price) [avg price]
FROM   Books
       AND  author = (SELECT id_author
                      FROM   Authors
                      WHERE  name = 'Sapkowski');