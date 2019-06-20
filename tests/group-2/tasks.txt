##### Task 1

[2 pts] Find books with "the" in titles.

Query structure: **rows sorting**

```plaintext
title
-------------------------
Data on the web
The Last Wish
The Taming of the Shrew
The Tower of the Swallow
```

##### Task 2

[2 pts] Find books which are more expensive than "Fuzzy Logic".

Query structure: **join**

```plaintext
title
----------------
Quering XML
Data on the web
```

##### Task 3

[3 pts] Find the cheapest book from "computer science" category. Do not use `TOP`.

Query structure: **subquery**, **agregate function**

```plaintext
title
------------
Fuzzy Logic
```

##### Task 4

[3 pts] Find number of of books in each category.

Query structure: **grouping**

```plaintext
category          num
----------------- ----
computer science  3
drama             1
sf                3
```

##### Task 5

[5 pts] Find an author whose books are not in the database.

Query structure: **outer join**, `IS NULL`

```plaintext
name
----------
Cervantes
```
