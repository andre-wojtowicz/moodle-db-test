##### Task 1

[2 pts] Find non-Polish authors.

Query structure: **rows sorting**

```plaintext
name         country
------------ ----------
Abiteboul    USA
Cervantes    Spain
Shakespeare  England
Yen          USA
```

##### Task 2

[2 pts] Find authors of computer science books.

Query structure: **join**

```plaintext
name
----------
Abiteboul
Yen
```

##### Task 3

[3 pts] Find average price of Sapkowski's books.

Query structure: **subquery**, **agregate function**

```plaintext
avg price
----------
25
```

##### Task 4

[3 pts] Find authors who have written at least 2 books after 1996.

Query structure: **grouping**

```plaintext
name       no_books
---------- ---------
Abiteboul  2
Sapkowski  2
```

##### Task 5

[5 pts] Find an author whose books are not in the database.

Query structure: `EXISTS`

```plaintext
name
----------
Cervantes
```
