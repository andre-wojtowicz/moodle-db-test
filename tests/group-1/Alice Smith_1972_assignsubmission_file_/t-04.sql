SELECT   A.name, 
         COUNT(*) [no_books]
FROM     Books B
         JOIN Authors A
           ON B.author = A.id_author
WHERE    B.print_year > 1996
GROUP BY A.name
HAVING   COUNT(*) >= 2;