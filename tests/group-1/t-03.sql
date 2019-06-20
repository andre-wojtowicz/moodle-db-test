SELECT AVG(price) [avg price]
FROM   Books
WHERE  author = (SELECT id_author
                 FROM   Authors
                 WHERE  name = 'Sapkowski');