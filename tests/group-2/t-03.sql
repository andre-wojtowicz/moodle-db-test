SELECT title
FROM   Books
WHERE  price = (SELECT MIN(price)
               FROM   Books
               WHERE  category = 'computer science')
       AND category = 'computer science';