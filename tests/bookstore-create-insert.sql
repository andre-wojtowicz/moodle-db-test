USE master;
GO

DROP DATABASE IF EXISTS Bookstore;
GO

CREATE DATABASE Bookstore;
GO

USE Bookstore;
GO

-------- DROP TABLES --------

DROP TABLE IF EXISTS Books;
DROP TABLE IF EXISTS Authors;

--------- CREATE TABLES AND FOREIGN KEYS --------

CREATE TABLE Authors
(
    id_author INT PRIMARY KEY,
    name      VARCHAR(30),
    country   VARCHAR(10)
);

CREATE TABLE Books
(
    id_book     INT PRIMARY KEY IDENTITY(1,1),
    author      INT REFERENCES Authors(id_author),
    title       VARCHAR(50),
    price       FLOAT,
    print_year  INT,
    category    VARCHAR(30)
);

GO

---------- INSERT DATA --------

INSERT INTO Authors VALUES
(1, 'Abiteboul',   'USA'),
(2, 'Shakespeare', 'England'),
(3, 'Sapkowski',   'Poland'),
(4, 'Yen',         'USA'),
(5, 'Cervantes',   'Spain');

INSERT INTO Books VALUES
(1, 'Quering XML',              60, 1997, 'computer science'),
(1, 'Data on the web',          75, 2000, 'computer science'),
(2, 'The Taming of the Shrew',  32, 1999, 'drama'),
(3, 'The Last Wish',            25, 1993 ,'sf'),
(3, 'The Tower of the Swallow', 30, 1997, 'sf'),
(3, 'Narrenturm',               20, 2002, 'sf'),
(4, 'Fuzzy Logic',              55, 1999, 'computer science');

------------ SELECT --------

SELECT * FROM Authors;
SELECT * FROM Books;
