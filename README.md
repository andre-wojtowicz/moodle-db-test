# Database-course test grader for Moodle

This PowerShell module provides routines to automate database-course
T-SQL test grading and exporting grades to Moodle e-learning system.
This approach might be desireable for lecturers and teaching assistants 
who do not have e.g. [CodeRunner](https://coderunner.org.nz/)
installed on their Moodle platform.

During a test a student have to write, say, five `SELECT` statements 
for a particular database. Each statement must use some SQL structure
(e.g. subquery, join, grouping, aggregate functions, etc.) provided in
description of tasks. Now, if you have 200 students, then it is impossible
to hinestly check 1000 queries by hand. This module aims to automate
this process. Tasks are graded in the approach "all or nothing".

The solution works on both Windows and Linux systems.

## Technical prerequisites

* PowerShell with [SqlServer module](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module)
* [T-SQL checker](https://github.com/andre-wojtowicz/tsql-checker)
* Running SQL Server instance

## Example test

In this example we will perform 2 tests (groups) for 4 students on the same database. Each test will have 5 questions.

In the following steps we will describe meanings of files and how to
obtain the target directory structure.

Let us say that we work on Windows, our login is `foo` and the target directory is
placed on `Desktop` in `bar`, i.e. `C:\Users\foo\Desktop\bar`.

### Moodle

All questions refer to [Bookstore](/tests/bookstore-create-insert.sql)
database. The database should be either available for students
on a server or a student creates a database locally during a test.

For each group of students we create `Assignment` on Moodle. The body
should indicate what must be done by a student (see 
[group 1](/tests/group-1/tasks.md) and [group 2](/tests/group-1/tasks.md))
(it is recommended to insert SQL output, so that student are able to
compare their results with the desired result).
Moreover, in the description of the assignment we provide 5 empty files
in the given naming convention, say `t-01.sql`, `t-02.sql`, etc. Students
must download these files, fill them, and upload to Assignment as the final
solutions.

After the test, in each test on Moodle we choose `Download all submissions`.
Now we can create initial directory structure:

```plaintext
└── tests
    ├── group-1
    │   ├── Alice Smith_1972_assignsubmission_file_
    │   │   ├── t-01.sql
    │   │   ├── t-02.sql
    │   │   ├── t-03.sql
    │   │   ├── t-04.sql
    │   │   └── t-05.sql
    │   └── John Doe_1853_assignsubmission_file_
    │       ├── t-01.sql
    │       ├── t-02.sql
    │       ├── t-03.sql
    │       ├── t-04.sql
    │       └── t-05.sql
    └── group-2
        ├── Bob Engels_2012_assignsubmission_file_
        │   ├── t-01.sql
        │   ├── t-02.sql
        │   ├── t-03.sql
        │   ├── t-04.sql
        │   └── t-05.sql
        └── Zoe Terry_1864_assignsubmission_file_
            ├── t-01.sql
            ├── t-03.sql
            ├── t-04.sql
            └── t-05.sql
```

We may see that Zoe did not included `t-02.sql` since she did not know
how to solve a task and Moodle does not accept empty files.

For each group we must download a grader matrix to fill and further import.
That is, on Moodle panel we choose
`Grades > (top dropdown menu) Export > Plain text file`, we select test
Assignment for group 1, we tick `Include feedback in export` and choose
comma as a separator. We download a CSV file and do the same steps for group 2. A single file may look as follows (it does not matter whether there are extra students who did not solve a particular test):

```plaintext
Name  Surname id     Instiution Department E-mail         Test (Points) Test (Feedback) Last download
----  ------- --     ---------- ---------- ------         ------------- --------------- -------------
John  Doe     510810                       jd@invalid.com -                             1554370916
Bob   Engels  510827                       be@invalid.com -                             1554370916
Kate  Moore   510831                       km@invalid.com -                             1554370916
Alice Smith   510833                       as@invalid.com -                             1554370916
Bill  Torp    498919                       bt@invalid.com -                             1554370916
Zoe   Terry   510837                       zt@invalid.com -                             1554370916
```

We put CSV files directly in `group-*` directories (students' directories
are collapsed):

```plaintext
└── tests
    ├── group-1
    │   ├── CS201DB Grades-20190505_0941-comma_separated.csv
    │   ├── Alice Smith_1972_assignsubmission_file_
    │   │   └── ... (sql files)
    │   └── John Doe_1853_assignsubmission_file_
    │       └── ... (sql files)
    └── group-2
        ├── CS201DB Grades-20190505_0941-comma_separated.csv
        ├── Bob Engels_2012_assignsubmission_file_
        │   └── ... (sql files)
        └── Zoe Terry_1864_assignsubmission_file_
            └── ... (sql files)
```

### PowerShell module configuration

In root directory we put three files:

1. PowerShell module file `moodle-db-test.psm1` (to automate grading routines),
2. [T-SQL checker](https://github.com/andre-wojtowicz/tsql-checker) binary
   (`tsql-checker.exe` for Windows or `tsql-checker.bin` for Linux; to 
   get T-SQL tokens and grammar used in `.sql` file),
3. PowerShell module config file `config.psd1`.

In `config.psd1` we setup paths to T-SQL checker binary and tests.
We also provide server address and credentials, in order to connect SQL Sever
with tests' databases. Finally, we specify how is organized exported CSV Moodle
grades file (delimiter and number of columns for name, surname, points and feedback,
iterated from 0).

```plaintext
@{
    TsqlCheckerPath = ".\tsql-checker.exe"   # or ".\tsql-checker.bin"
    TestsRootDir    = ".\tests"
    Sqlcmd = @{
        Server            = 'localhost'
        WindowsAuth       = $false
        User              = 'sa'
        Password          = 'P@s$w0rd'
        ConnectionTimeout = 5
        QueryTimeout      = 5
    }
    MoodleCsv = @{
        Delimiter  = ','
        IdName     = 0
        IdSurname  = 1
        IdPoints   = 6
        IdComments = 7
    }
}
```

Now our directory structure looks as follows:

```plaintext
├── config.psd1
├── moodle-db-test.psm1
├── tsql-checker.exe (or tsql-checker.bin)
└── tests
    ├── group-1
    │   ├── CS201DB Grades-20190505_0941-comma_separated.csv
    │   ├── Alice Smith_1972_assignsubmission_file_
    │   │   └── ... (sql files)
    │   └── John Doe_1853_assignsubmission_file_
    │       └── ... (sql files)
    └── group-2
        ├── CS201DB Grades-20190505_0941-comma_separated.csv
        ├── Bob Engels_2012_assignsubmission_file_
        │   └── ... (sql files)
        └── Zoe Terry_1864_assignsubmission_file_
            └── ... (sql files)
```

We can start PowerShell and navigate to our target directory:

```powershell
PS> cd ~\Desktop\bar
```

We import PowerShell module:

```powershell
PS> Import-Module .\moodle-db-test.psm1
```
```plaintext
Loading default config from config.psd1 ...
```

By default `config.psd1` is automatically loaded when it is
in working directory. The config file can be loaded manually by
`Import-MdtConfig [<Path>]`.

Current config can be displayed in a readable form by 
`Get-MdtConfig | ConvertTo-Json`.

The module loads `SqlServer` module. If it is not installed, then 
an error will be shown. Module installation is decribed on
[SqlServer module page](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module).

If there is a need to reload module, then firstly it must be
removed by `Remove-Module moodle-db-test` command, and re-imported
by `Import-Module .\moodle-db-test.psm1`.

When we import the module, then we can check whether we can connect
to SQL Server:

```powershell
PS> Test-MdtSqlConnection
```
```plaintext
Success
```

### Model test answers

In each `tests\group-*` directory we must provide "gold standard" answers.
That is, we put `t-01.sql`, `t-02.sql`, etc., filled with valid `SELECT`
statements.

Moreover, each `tests\group-*` directory must have test configuration in 
`cfg.psd1`. It may look as follows:

```plaintext
@{
    Database = 'Bookstore'
    Points = @{
        't-01' = 2
        't-02' = 2
        't-03' = 3
        't-04' = 4
        't-05' = 5
    }
    SortingInsignificant = @{
        't-01' = $false
        't-02' = $true
        't-03' = $true
        't-04' = $true
        't-05' = $true
    }
    QueryStructure = @{
        't-01' = 'order_by_clause'
        't-02' = 'table_source_item_joined'
        't-03' = 'aggregate_windowed_function,subquery'
        't-04' = 'group_by_item'
        't-05' = 'table_source_item_joined,null_notnull'
    }
    QueryWords = @{
        't-04' = 'HAVING'
    }
    ForbiddenClauses = @{
        't-03' = 'top_clause'
    }
}
```

* `Database` - where are tables and data for a given test,
* `Points` - points for each particular task in the test,
* `SortingInsignificant` - whether order of rows matter 
   when comapring student's result to "gold answer",
* `QueryStructure` - desired T-SQL grammar elements in
  student's ansewer,
* `QueryWords` - desired T-SQL tokens in student's answer,
* `ForbiddenClauses` - forbidden T-SQL grammar elements in
  student's ansewer.
  
Values in `QueryStructure`, `QueryWords` and `ForbiddenClauses`
hashtables can have multiple elements, separated by commas.
The module uses ANTLR T-SQL grammar, hence, list of all available
tokens and grammar elements are in
[`TSqlLexer.g4`](https://github.com/antlr/grammars-v4/blob/master/tsql/TSqlLexer.g4)
and
[`TSqlParser.g4`](https://github.com/antlr/grammars-v4/blob/master/tsql/TSqlParser.g4),
respectively. A short list of the most common-use elements is below:

| Desired SQL structure | Token    | Grammar element               |
| --------------------- | -------- | ----------------------------- |
| row sorting           |          | `order_by_clause`             |
| join                  |          | `table_source_item_joined`    |
| aggregate function    |          | `aggregate_windowed_function` |
| subquery              |          | `subquery`                    |
| grouping              |          | `group_by_item`               |
| grouping with filter  | `HAVING` | `group_by_item`               |
| existence in subquery | `EXISTS` |                               |
| `IS (NOT) NULL`       |          | `null_notnull`                |
| `TOP`                 |          | `top_clause`                  |
| `TOP`                 | `TOP`    |                               |

Now our directory structure looks as follows:

```plaintext
├── config.psd1
├── moodle-db-test.psm1
├── tsql-checker.exe (or tsql-checker.bin)
└── tests
    ├── group-1
    │   ├── cfg.psd1
    │   ├── CS201DB Grades-20190505_0941-comma_separated.csv
    │   ├── t-01.sql
    │   ├── t-02.sql
    │   ├── t-03.sql
    │   ├── t-04.sql
    │   ├── t-05.sql
    │   ├── Alice Smith_1972_assignsubmission_file_
    │   │   └── ... (sql files)
    │   └── John Doe_1853_assignsubmission_file_
    │       └── ... (sql files)
    └── group-2
        ├── cfg.psd1
        ├── CS201DB Grades-20190505_0941-comma_separated.csv
        ├── t-01.sql
        ├── t-02.sql
        ├── t-03.sql
        ├── t-04.sql
        ├── t-05.sql
        ├── Bob Engels_2012_assignsubmission_file_
        │   └── ... (sql files)
        └── Zoe Terry_1864_assignsubmission_file_
            └── ... (sql files)
```

### Get model output

Before we check student solutions, we must cache results 
of our model answers.

```powershell
PS> Get-ModelOutput
```
```plaintext
Directories matched:
group-1
group-2
Processing:
group-1
Executing 5 queries on Bookstore ...
t-01.sql finished
t-02.sql finished
t-03.sql finished
t-04.sql finished
t-05.sql finished
group-2
Executing 5 queries on Bookstore ...
t-01.sql finished
t-02.sql finished
t-03.sql finished
t-04.sql finished
t-05.sql finished
```

By default all directories in `tests` will be scanned. We can select
particular tests by giving a pattern:

```powershell
Get-ModelOutput -TestDirPattern [<Pattern>]
```

Now each directory `tests\group-*` for each task `t-0*.sql` have extra files
with extensions `.grammar`, `.tokens`, `.sql_output` and `.sql_output_ps`:

* `.grammar` - you may check which elements of T-SQL grammar are
  used by your "gold answer" and, in case of need, insert some of them
  in test config file `cfg.ps1`,
* `.tokens` - list of tokens used in the query,
* `.sql_output` - plaintext output of the query, which might be used 
  in tasks description,
* `.sql_output_ps` - XML output of the query, which is used to compare
  with students' results.

### Test student sanity

Just before we start investigating students' solutions, we check
whether each student put `.sql` files on Moodle in the valid form.

```powershell
PS> Test-StudentSanity
```
```plaintext
Directories matched:
group-1
group-2
Processing:
group-1
Alice Smith_1972_assignsubmission_file_ OK
John Doe_1853_assignsubmission_file_ OK
group-2
Bob Engels_2012_assignsubmission_file_ OK
Zoe Terry_1864_assignsubmission_file_ OK
All directories OK
```

If there are some errors (e.g. student put files in folder, changed names,
zipped files, etc.), we must correct them by hand.

You can filter tests and students by providing patterns:

```powershell
Test-StudentSanity -TestDirPattern [<Pattern>] -StudentDirPattern [<Pattern>]
```

### Get student output

Now we can investigate students's solutions:

```powershell
PS> Get-StudentOutput
```
```plaintext
Directories matched:
group-1
group-2
Processing:
group-1
Alice Smith_1972_assignsubmission_file_
t-01.sql finished
t-02.sql finished
t-03.sql finished
t-04.sql finished
t-05.sql finished
John Doe_1853_assignsubmission_file_
t-01.sql finished
t-02.sql has security grammar element: ddl_clause
t-03.sql has parsing errors, skipping
t-04.sql finished
t-05.sql finished
group-2
Bob Engels_2012_assignsubmission_file_
t-01.sql has parsing errors, skipping
t-02.sql has multiple SQL clauses, skipping
t-03.sql finished
t-04.sql has security grammar element: another_statement
t-04.sql has security grammar element: execute_statement
t-04.sql has security grammar element: execute_body
t-05.sql finished
Zoe Terry_1864_assignsubmission_file_
t-01.sql has multiple SQL clauses, skipping
t-03.sql finished
t-04.sql finished
t-05.sql finished
```

For a given student's answer, for a given task we check whether `.sql` file:

1. exists and has a proper name,
2. is not empty,
3. parses correctly,
4. has not multiple `SELECT` statements,
5. does not use suspicious SQL clauses like DDL, `EXECUTE`, authorization statements, etc,
6. executes correctly.

As in the previous step, several auxiliary files are created.

We can filter tests and students by providing patterns:

```powershell
Test-StudentSanity -TestDirPattern [<Pattern>] -StudentDirPattern [<Pattern>]
```

### Get grades

Now we can get grades for each test:

```powershell
PS> Get-Grades
```
```plaintext
Directories matched:
group-1
group-2
Processing:
group-1
Alice Smith_1972_assignsubmission_file_
t-01: [2] OK
t-02: [2] OK
t-03: [3] OK
t-04: [4] OK
t-05: [5] OK
Points: 16
John Doe_1853_assignsubmission_file_
t-01: [0] missing SQL statement structure: order_by_clause
t-02: [0] security clause detected
t-03: [0] SQL parse error
t-04: [0] missing SQL word: HAVING
t-05: [0] missing SQL word: EXISTS
Points: 0
Saving grades in group-1\grades.csv ...
group-2
Bob Engels_2012_assignsubmission_file_
t-01: [0] SQL parse error
t-02: [0] multiple SQL statements
t-03: [0] forbidden SQL clause: top_clause
t-04: [0] security clause detected
t-05: [5] OK
Points: 5
Zoe Terry_1864_assignsubmission_file_
t-01: [0] multiple SQL statements
t-02: [0] no SQL file
t-03: [3] OK
t-04: [4] OK
t-05: [0] missing SQL statement structure: null_notnull
Points: 7
Saving grades in group-2\grades.csv ...
```

Tasks are graded in the approach "all or nothing", i.e. a student for a given task may get all points (results are the same with these produced by "gold answer" and query structure is valid) or zero points (errors, wrong answer, etc.). The grades are saved in `tests\group-*\grades.csv` files. By default resulting CSV file contains only rows with students who attempted the test, e.g. for `group-1`:

```plaintext
Name  Surname id     Instiution Department E-mail         Test (Points) Test (Feedback)
----  ------- --     ---------- ---------- ------         ------------- ---------------
John  Doe     510810                       jd@invalid.com 0             t-01: [0] missing SQL statement structure: order_by_clause<b...
Alice Smith   510833                       as@invalid.com 16            t-01: [2] OK<br>t-02: [2] OK<br>t-03: [3] OK<br>t-04: [4] OK...
```

Finally, out  arget directory looks as follows (auxiliary files omitted):

```plaintext
├── config.psd1
├── moodle-db-test.psm1
├── tsql-checker.exe (or tsql-checker.bin)
└── tests
    ├── group-1
    │   ├── cfg.psd1
    │   ├── CS201DB Grades-20190505_0941-comma_separated.csv
    │   ├── grades.csv
    │   ├── t-01.sql
    │   ├── t-02.sql
    │   ├── t-03.sql
    │   ├── t-04.sql
    │   ├── t-05.sql
    │   ├── Alice Smith_1972_assignsubmission_file_
    │   │   └── ... (sql files)
    │   └── John Doe_1853_assignsubmission_file_
    │       └── ... (sql files)
    └── group-2
        ├── cfg.psd1
        ├── CS201DB Grades-20190505_0941-comma_separated.csv
        ├── grades.csv
        ├── t-01.sql
        ├── t-02.sql
        ├── t-03.sql
        ├── t-04.sql
        ├── t-05.sql
        ├── Bob Engels_2012_assignsubmission_file_
        │   └── ... (sql files)
        └── Zoe Terry_1864_assignsubmission_file_
            └── ... (sql files)
```

We can filter tests and students by providing patterns; we can also
save all students' records in CSV file; if it is e.g. second attempt
for some students, we can set max. points to obtain in tests:

```powershell
Get-Grades -TestDirPattern [<Pattern>] -StudentDirPattern [<Pattern>]
           -SaveOnlyEvaluatedStudents [<Bool>] -MaxPoints [<Integer>]
```

### Uploading grades to Moodle

Now we can upload `grades.csv` files to Moodle. On Moodle panel we choose
`Grades > (top dropdown menu) Import > CSV file`, we upload a file, choose comma as a separator and if we want to overwrite result then we select `Force import`.

### Cleanup

We can remove all generated files (output from model answers, students' answers and grades):

```powershell
PS> Remove-ModelOutput
PS> Remove-StudentOutput
PS> Remove-Grades
```

We can filter tests and students by providing patterns:

```powershell
Remove-ModelOutput -TestDirPattern [<Pattern>]
Remove-StudentOutput -TestDirPattern [<Pattern>] -StudentDirPattern [<Pattern>]
Remove-Grades -TestDirPattern [<Pattern>]
```
