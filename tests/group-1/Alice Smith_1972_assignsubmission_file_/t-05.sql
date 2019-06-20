SELECT A.name
FrOm   Authors A
where  not exists (select * 
                   from   books b
                   where  A.id_author = B.author);