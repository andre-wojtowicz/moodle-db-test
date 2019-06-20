select avg(price) as "avg price"
from   books
where  author = (select id_author
                 from   authors
                 where  name = 'Sapkowski');