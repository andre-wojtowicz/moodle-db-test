Import-Module SqlServer
if ($(Get-Module -ListAvailable -Name SqlServer) -eq $null)
{
    Write-Error -Message ("Install SqlServer module: " +
    "https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module") `
    -ErrorAction Stop
}

$cfg = $null

$default_config_file = "cfg.psd1"

#______________________________________________________________________________

function Import-MdtConfig
{
    param
    (
        [string] $ConfigFile = $default_config_file
    )

    $script:cfg = Import-PowerShellDataFile $ConfigFile

    if (-not $(Test-Path $cfg.TsqlCheckerPath -PathType Leaf))
    {
        Write-Host -ForegroundColor Red "T-SQL checker does not exists in specified path:"
        Write-Host -ForegroundColor Yellow $cfg.TsqlCheckerPath
    }
}

function Get-MdtConfig
{
    $cfg
}

function Test-SqlConnection
{
    try
    {
        Invoke-Sqlcmd -ServerInstance    $cfg.Sqlcmd.Server `
                      -UserName          $cfg.Sqlcmd.User `
                      -Password          $cfg.Sqlcmd.Password `
                      -Query             " " `
                      -ConnectionTimeout $cfg.Sqlcmd.ConnectionTimeout `
                      -QueryTimeout      $cfg.Sqlcmd.QueryTimeout `
                      -ErrorAction       Stop

        Write-Host -ForegroundColor Green Success
    } catch { 
        Write-Host -ForegroundColor Red $_.Exception.Message
    }
}

function Get-ModelSqlTokensAndGrammar
{
    param
    (
        [string] $TestDirPattern = ".*"
    )
    
    $dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue $cfg.TestsRootDir |`
            Where-Object {$_.Name -match "$TestDirPattern"}
    
    if ($dirs -eq $null)
    {
        Write-Host -ForegroundColor Green "No directories matched"
        return
    }
    
    Write-Host -ForegroundColor Green "Directories matched:"
    Write-Host -Separator "`n" $dirs.Name
    
    
    Write-Host -ForegroundColor Green "Processing:"
    ForEach ($dir in $dirs)
    {
        Write-Host -ForegroundColor Yellow $dir.Name
        
        $sqls = Get-ChildItem -File $(Join-Path $dir.FullName "*.sql")
        
        ForEach ($sql in $sqls)
        {
            & $cfg.TsqlCheckerPath $sql.FullName
            
            if ($LastExitCode -eq 0)
            {
                Write-Host -ForegroundColor Gray $sql.Name
            } 
            else
            {
                Write-Host -ForegroundColor Red $sql.Name
                return 1
            }
        }
    }
}

function Get-ModelSqlOutput
{
    param
    (
        [string] $TestDirPattern = ".*"
    )
    
    $dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue $cfg.TestsRootDir |`
            Where-Object {$_.Name -match "$TestDirPattern"}
    
    if ($dirs -eq $null)
    {
        Write-Host -ForegroundColor Green "No directories matched"
        return
    }
    
    Write-Host -ForegroundColor Green "Directories matched:"
    Write-Host -Separator "`n" $dirs.Name
    
    
    Write-Host -ForegroundColor Green "Processing:"
    ForEach ($dir in $dirs)
    {
        Write-Host -ForegroundColor Yellow $dir.Name
        
        $test_cfg = Import-PowerShellDataFile $(Join-Path $dir.FullName cfg.psd1)
        $db_name = $test_cfg.Database
        
        $sqls = Get-ChildItem -File $(Join-Path $dir.FullName "*.sql")
        
        Write-Host -ForegroundColor Gray "Executing $($sqls.Length) queries on $db_name ..."
        
        ForEach ($sql in $sqls)
        {
            $file_full_name_no_ext = Join-Path $dir.FullName [IO.Path]::GetFileNameWithoutExtension($sql.Name)

            try
            {
                $p = Invoke-Sqlcmd -ServerInstance        $cfg.Sqlcmd.Server `
                                    -UserName             $cfg.Sqlcmd.User `
                                    -Database             $db_name `
                                    -Password             $cfg.Sqlcmd.Password `
                                    -InputFile            $sql.FullName `
                                    -ConnectionTimeout    $cfg.Sqlcmd.ConnectionTimeout `
                                    -QueryTimeout         $cfg.Sqlcmd.QueryTimeout `
                                    -IncludeSqlUserErrors `
                                    -ErrorAction          Stop
                                    -DisableCommands
                                    -DisableVariables

                $p | Format-Table | Out-File -Encoding utf8 "$($file_full_name_no_ext).sql_output"
                $p | Export-CliXml "$($file_full_name_no_ext).sql_output_ps"
                Remove-Item -ErrorAction Ignore "$($file_full_name_no_ext).sql_errors"
                Write-Host -ForegroundColor Gray $sql.Name finished
            }
            catch
            { 
                $_.Exception.Message | Out-File -Encoding utf8 "$($file_full_name_no_ext).sql_errors"
            
                Write-Host -ForegroundColor Red $file.Name finished with errors
                Write-Host -ForegroundColor Red $_.Exception.Message
                return 1
            }
        }
    }
}

function Test-StudentSqlSanity
{
    param
    (
        [string] $TestDirPattern = ".*",
        [string] $StudentDirPattern = ".*"
    )
    
    $dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue $cfg.TestsRootDir |`
            Where-Object {$_.Name -match "$TestDirPattern"}
    
    if ($dirs -eq $null)
    {
        Write-Host -ForegroundColor Green "No directories matched"
        return
    }
    
    Write-Host -ForegroundColor Green "Directories matched:"
    Write-Host -Separator "`n" $dirs.Name
    
    $dirs_to_check = @()
    
    
    Write-Host -ForegroundColor Green "Processing:"
    ForEach ($dir in $dirs)
    {
        Write-Host -ForegroundColor Yellow $dir.Name
        
        $model_sqls = Get-ChildItem -File $(Join-Path $dir.FullName "*.sql")
        
        $students_dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue "$($dir.FullName)" | `
                         Where-Object {$_.Name -match "$StudentDirPattern"}
        
        if ($students_dirs -eq $null)
        {
            Write-Host -ForegroundColor Green "No students directories matched"
            continue
        }
        
        ForEach ($student_dir in $students_dirs)
        {
            Write-Host -ForegroundColor Gray -NoNewline "$($student_dir.Name) "
            
            $student_sqls = Get-ChildItem -File $(Join-Path $student_dir.FullName "*.sql")
            
            if ($student_sqls -eq $null)
            {
                Write-Host -ForegroundColor Red "No .sql files"
                $_dsep_ = [IO.Path]::DirectorySeparatorChar
                $dirs_to_check += ($($student_dir.FullName).Split($_dsep_) | Select-Object -Last 2) -Join $_dsep_
                continue
            }
            
            $cmp = Compare-Object $model_sqls.Name $student_sqls.Name -PassThru -IncludeEqual -ExcludeDifferent
            
            if ($cmp.Count -eq 0)
            {
                Write-Host -ForegroundColor Red "No valid .sql files"
                $_dsep_ = [IO.Path]::DirectorySeparatorChar
                $dirs_to_check += ($($student_dir.FullName).Split($_dsep_) | Select-Object -Last 2) -Join $_dsep_
                continue
            }
            
            Write-Host -ForegroundColor Green "OK"
        }
    }
    
    if ($dirs_to_check.Length -gt 0)
    {
        Write-Host -ForegroundColor Cyan "Directories to check:"
        Write-Host -ForegroundColor Red -Separator "`n" $dirs_to_check
        return 1
    }
    else
    {
        Write-Host -ForegroundColor Green "All directories OK"
    }   
}

function Get-StudentSqlOutFiles
{    
    param
    (
        [string] $TestDirPattern = ".*",
        [string] $StudentDirPattern = ".*"
    )
    
    $dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue $cfg.TestsRootDir |`
            Where-Object {$_.Name -match "$TestDirPattern"}
    
    if ($dirs -eq $null)
    {
        Write-Host -ForegroundColor Green "No directories matched"
        return
    }
    
    Write-Host -ForegroundColor Green "Directories matched:"
    Write-Host -Separator "`n" $dirs.Name
    
    
    Write-Host -ForegroundColor Green "Processing:"
    ForEach ($dir in $dirs)
    {
        Write-Host -ForegroundColor Yellow $dir.Name

        $test_cfg = Import-PowerShellDataFile $(Join-Path $dir.FullName cfg.psd1)
        $db_name = $test_cfg.Database
        
        $model_sqls = Get-ChildItem -File $(Join-Path $dir.FullName "*.sql")
        
        $students_dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue "$($dir.FullName)" | `
                         Where-Object {$_.Name -match "$StudentDirPattern"}
        
        if ($students_dirs -eq $null)
        {
            Write-Host -ForegroundColor Green "No students directories matched"
            continue
        }
        
        ForEach ($student_dir in $students_dirs)
        {
            Write-Host -ForegroundColor Gray $student_dir.Name
            
            $student_sqls = Get-ChildItem -File $(Join-Path $student_dir.FullName "*.sql")
            
            if ($student_sqls -eq $null)
            {
                Write-Host -ForegroundColor Magenta "No .sql files"
                continue
            }
            
            $cmp = Compare-Object $model_sqls.Name $student_sqls.Name -PassThru -IncludeEqual -ExcludeDifferent
            
            if ($cmp.Count -eq 0)
            {
                Write-Host -ForegroundColor Magenta "No valid .sql files"
                continue
            }
            
            ForEach($sql_file in $cmp)
            {
                $sql_file_full_path = Join-Path $student_dir.FullName $sql_file
                $sql_file_full_path_no_ext = Join-Path $student_dir.FullName [IO.Path]::GetFileNameWithoutExtension($sql_file)
            
                # parse
                
                $parse_error_full_path = "$($sql_file_full_path_no_ext).parse_errors"
                $parse_query = "SET PARSEONLY ON;`n" + [IO.File]::ReadAllText($sql_file_full_path)
                
                try
                {
                    Invoke-Sqlcmd -ServerInstance    $cfg.Sqlcmd.Server `
                                  -UserName          $cfg.Sqlcmd.User `
                                  -Database          $db_name `
                                  -Password          $cfg.Sqlcmd.Password `
                                  -Query             $parse_query `
                                  -ConnectionTimeout $cfg.Sqlcmd.ConnectionTimeout `
                                  -QueryTimeout      $cfg.Sqlcmd.QueryTimeout `
                                  -ErrorAction       Stop
                                  -DisableCommands
                                  -DisableVariables
                }
                catch
                { 
                    $_.Exception.Message | Out-File -Encoding utf8 $parse_error_full_path
                }
                
                if ([System.IO.File]::Exists($parse_error_full_path))
                {
                    Write-Host -ForegroundColor Yellow "$sql_file has parsing errors, skipping"
                    continue
                }
                
                # get tokens and grammar
                
                $tsqlchecker_full_path = "$($sql_file_full_path_no_ext).tsqlchecker"
                
                $utf8encoding = "utf8NoBOM"
                if ($PSVersionTable.PSVersion.Major -lt 6)
                {
                    $utf8encoding = "utf8"
                }
                
                & $cfg.TsqlCheckerPath $sql_file_full_path 2>&1 | Out-File $tsqlchecker_full_path -Encoding $utf8encoding
            
                if ($LastExitCode -ne 0)
                {
                    Write-Host -ForegroundColor Red "$sql_file crashed T-SQL checker"
                    return 1
                }
                
                if ((Get-Content $tsqlchecker_full_path).Length -eq 0)
                {
                    Remove-Item $tsqlchecker_full_path -Force
                }
                else
                {
                    Write-Host -ForegroundColor Yellow "Check $([IO.Path]::GetFileName($tsqlchecker_full_path))"
                }
                
                # check multiple sql statements
                
                $multiple_sql_full_path = "$($sql_file_full_path_no_ext).multiple_sql"
                
                $m1 = Select-String -InputObject $(Get-Content "$($sql_file_full_path_no_ext).grammar") -Pattern "sql_clause " -AllMatches
                
                $m2 = Select-String -InputObject $(Get-Content "$($sql_file_full_path_no_ext).tokens") -Pattern "SELECT" -AllMatches
                
                if ($m1.Matches.Count -gt 1 -and $m2.Matches.Count -gt 1)
                {
                    "Multiple SQL clauses" | Out-File -Encoding utf8 $multiple_sql_full_path
                    Write-Host -ForegroundColor Yellow "$sql_file has multiple SQL clauses, skipping"
                    continue
                }
                
                # check security patterns
                
                $security_check_full_path = "$($sql_file_full_path_no_ext).security_check"
                
                $sec_grammar = @("ddl_clause", "cfl_statement", "dbcc_clause", "empty_statement",
                                 "another_statement", "backup_statement", "execute_statement", "execute_body")
                      
                $fe_flag = $false
                ForEach($patt in $sec_grammar)
                {
                    $sm = Select-String -InputObject $(Get-Content "$($sql_file_full_path_no_ext).grammar") -Pattern "$patt " -AllMatches
                    
                    if ($sm.Matches.Count -gt 0)
                    {
                        "Security grammar element: $patt" | Out-File -Append -Encoding utf8 $security_check_full_path
                        Write-Host -ForegroundColor Red "$sql_file has security grammar element: $patt"
                        $fe_flag = $true
                    }
                }
                if ($fe_flag)
                {
                    continue
                }

                $sec_tokens = @("INTO", "GRANT", "REVOKE", "DENY")
                
                $fe_flag = $false
                ForEach($patt in $sec_tokens)
                {
                    $sm = Select-String -InputObject $(Get-Content "$($sql_file_full_path_no_ext).tokens") -Pattern "$patt " -AllMatches
                    
                    if ($sm.Matches.Count -gt 0)
                    {
                        "Security token: $patt" | Out-File -Append -Encoding utf8 $security_check_full_path
                        Write-Host -ForegroundColor Red "$sql_file has security token: $patt"
                        $fe_flag = $true
                    }
                }
                if ($fe_flag)
                {
                    continue
                }
                
                # get sql output
                
                try
                {
                    $p = Invoke-Sqlcmd -ServerInstance       $cfg.Sqlcmd.Server `
                                       -UserName             $cfg.Sqlcmd.User `
                                       -Database             $db_name `
                                       -Password             $cfg.Sqlcmd.Password `
                                       -InputFile            $sql_file_full_path `
                                       -ConnectionTimeout    $cfg.Sqlcmd.ConnectionTimeout `
                                       -QueryTimeout         $cfg.Sqlcmd.QueryTimeout `
                                       -IncludeSqlUserErrors `
                                       -ErrorAction          Stop
                                       -DisableCommands
                                       -DisableVariables

                    $p | Format-Table | Out-File -Encoding utf8 "$($sql_file_full_path_no_ext).sql_output"
                    $p | Export-CliXml "$($sql_file_full_path_no_ext).sql_output_ps"
                }
                catch
                { 
                    New-Item "$($sql_file_full_path_no_ext).sql_output" -ItemType file -Force | Out-Null # query fail
                    $_.Exception.Message | Out-File -Encoding utf8 "$($sql_file_full_path_no_ext).sql_errors"
                }
                
                Write-Host -ForegroundColor Gray "$sql_file finished"
            }
        }
    }
}

function Get-StudentGrades
{
    param
    (
        [string] $TestDirPattern = ".*",
        [string] $StudentDirPattern = ".*",
        [bool]   $SaveOnlyEvaluatedStudents = $true,
        [int]    $MaxPoints = $null
    )
    
    $dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue $cfg.TestsRootDir |`
            Where-Object {$_.Name -match "$TestDirPattern"}
    
    if ($dirs -eq $null)
    {
        Write-Host -ForegroundColor Green "No directories matched"
        return
    }
    
    Write-Host -ForegroundColor Green "Directories matched:"
    Write-Host -Separator "`n" $dirs.Name
    
    
    Write-Host -ForegroundColor Green "Processing:"
    ForEach ($dir in $dirs)
    {
        Write-Host -ForegroundColor Yellow $dir.Name
        
        $csv_to_fill_path = Join-Path $dir.FullName "*-comma_separated.csv"
        $csv_to_fill = Import-Csv -Delimiter ',' -ErrorAction SilentlyContinue $csv_to_fill_path
        
        if ($csv_to_fill -eq $null)
        {
            Write-Host -ForegroundColor Red "Unable to read CSV file to fill: $csv_to_fill_path"
            return 1
        }
        
        $test_cfg = Import-PowerShellDataFile $(Join-Path $dir.FullName cfg.psd1)
        $db_name = $test_cfg.Database
        
        $model_sqls = Get-ChildItem -File $(Join-Path $dir.FullName "*.sql")
        
        $students_dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue "$($dir.FullName)" | `
                         Where-Object {$_.Name -match "$StudentDirPattern"}
        
        if ($students_dirs -eq $null)
        {
            Write-Host -ForegroundColor Green "No students directories matched"
            continue
        }
        
        $students_list = @()
        $csv_col_name     = $csv_to_fill[0].psobject.properties.name[$cfg.MoodleCsv.IdName]
        $csv_col_surname  = $csv_to_fill[0].psobject.properties.name[$cfg.MoodleCsv.IdSurname]
        $csv_col_points   = $csv_to_fill[0].psobject.properties.name[$cfg.MoodleCsv.IdPoints]
        $csv_col_comments = $csv_to_fill[0].psobject.properties.name[$cfg.MoodleCsv.IdComments]

        ForEach ($student_dir in $students_dirs)
        {
            Write-Host -ForegroundColor Gray $student_dir.Name
            
            $points  = 0
            $comment = ""
            
            $student_sqls = Get-ChildItem -File $(Join-Path $student_dir.FullName "*.sql")
            
            ForEach($model_sql in $model_sqls)
            {
                $question_id = [IO.Path]::GetFileNameWithoutExtension($model_sql)
                
                $comment += "$($question_id): "
            
                $student_sql = $student_sqls | Where-Object {$_.Name -eq $model_sql.Name}
                
                if ($student_sql)
                {
                    if ($student_sql.Length -eq 0)
                    {
                        $comment += "[0] empty SQL file<br>"
                        continue
                    }
                
                    $chk_root_name = Join-Path $student_dir.FullName $question_id
                
                    if ([System.IO.File]::Exists("$chk_root_name.parse_errors"))
                    {
                        $comment += "[0] SQL parse error<br>"
                        continue
                    }
                    if ([System.IO.File]::Exists("$chk_root_name.multiple_sql"))
                    {
                        $comment += "[0] multiple SQL statements<br>"
                        continue
                    }
                    if ([System.IO.File]::Exists("$chk_root_name.security_check"))
                    {
                        $comment += "[0] security clause detected<br>"
                        continue
                    }
                    if ([System.IO.File]::Exists("$chk_root_name.sql_errors"))
                    {
                        $comment += "[0] SQL runtime error<br>"
                        continue
                    }
                    
                    $student_answer_obj = Import-Clixml "$chk_root_name.sql_output_ps"

                    if (-not $student_answer_obj)
                    {
                        $comment += "[0] empty SQL output<br>"
                        continue
                    }
                    
                    if ($test_cfg.ForbiddenClauses.ContainsKey($question_id))
                    {
                        $student_grammar = Get-Content "$chk_root_name.grammar"

                        $clauses_raw = $test_cfg.ForbiddenClauses.$question_id

                        $fe_flag = $false
                        ForEach ($clause in $clauses_raw.Split(','))
                        {
                            if ($student_grammar.Contains($clause))
                            {
                                $comment += "[0] forbidden SQL clause: $clause<br>"

                                $fe_flag = $true
                                break
                            }
                        }
                        if ($fe_flag)
                        {
                            continue
                        }
                    }
                    
                    if ($test_cfg.QueryStructure.ContainsKey($question_id))
                    {
                        $student_grammar = Get-Content "$chk_root_name.grammar"

                        $structs_raw = $test_cfg.QueryStructure.$question_id

                        $fe_flag = $false
                        ForEach ($struct in $structs_raw.Split(','))
                        {
                            if (-not $student_grammar.Contains($struct))
                            {
                                $comment += "[0] missing SQL statement structure: $struct<br>"
                            
                                $fe_flag = $true
                                break
                            }
                        }
                        if ($fe_flag)
                        {
                            continue
                        }
                    }
                    
                    if ($test_cfg.QueryWords.ContainsKey($question_id))
                    {
                        $student_tokens = Get-Content "$chk_root_name.tokens"

                        $words_raw = $test_cfg.QueryWords.$question_id

                        $fe_flag = $false
                        ForEach ($word in $words_raw.Split(','))
                        {
                            if (-not $student_tokens.Contains($word))
                            {
                                $comment += "[0] missing SQL word: $word<br>"
                            
                                $fe_flag = $true
                                break
                            }
                        }
                        if ($fe_flag)
                        {
                            continue
                        }
                    }
                    
                    $model_answer_obj = Import-Clixml $(Join-Path $model_sql.Directory "$question_id.sql_output_ps")
                    
                    $model_answer_colnames = ($model_answer_obj | Get-Member `
                                              -MemberType Properties).Name | Sort-Object
                    $student_answer_colnames = ($student_answer_obj | Get-Member `
                                                -MemberType Properties).Name | Sort-Object

                    $model_answer_s = $model_answer_obj | Select-Object $model_answer_colnames
                    $student_answer_s = $student_answer_obj | Select-Object $student_answer_colnames
                    
                    if ($test_cfg.SortingInsignificant.$question_id) # yup, it's correct
                    {
                        $model_answer_s   = $model_answer_s | Sort-Object $model_answer_colnames
                        $student_answer_s = $student_answer_s | Sort-Object $student_answer_colnames
                    }
                    
                    $answers_comparison = Compare-Object $model_answer_s $student_answer_s -PassThru
                    
                    if ($answers_comparison -eq $null)
                    {
                        $pts = $test_cfg.Points.$question_id
                    
                        $comment += "[$pts] OK<br>"
                        $points  += $pts
                    }
                    else
                    {
                        $comment += "[0] wrong answer<br>"
                    }
                }
                else
                {
                    $comment += "[0] no SQL file<br>"
                }
             }
         
             $comment = $comment.Substring(0, $comment.Length - 4)

             Write-Host -ForegroundColor Cyan $comment.Replace("<br>", "`n")
             
             if ($MaxPoints -ne $null -and $points -gt $MaxPoints)
             {
                Write-Host -ForegroundColor Cyan "Points: $MaxPoints ($points)"
                $points = $MaxPoints
             }
             else
             {
                Write-Host -ForegroundColor Cyan "Points: $points"
             }

             $student_n_list = $student_dir.Name.Split('_')[0].Split(' ')
             
             $students_list += $student_n_list[0] + " " + $student_n_list[1]

             $rid = $csv_to_fill.IndexOf($($csv_to_fill | ? {$_."$csv_col_name" -eq $student_n_list[0] -and $_."$csv_col_surname" -eq $student_n_list[1]}))

             if ($rid -lt 0)
             {
                Write-Host -ForegroundColor Red "Unable to find unique record of $($student_n_list[0]) $($student_n_list[1]) in CSV file"
                return 1
             }

             $csv_to_fill[$rid]."$csv_col_points"   = $points
             $csv_to_fill[$rid]."$csv_col_comments" = $comment
         }
         
         if ($SaveOnlyEvaluatedStudents -eq $true)
         {
            $csv_to_fill = $csv_to_fill | Where-Object {$students_list.Contains($_."$csv_col_name" + " " + $_."$csv_col_surname")}
         }


         $csv_path = Join-Path $dir.FullName "grades.csv"

         $_dsep_ = [IO.Path]::DirectorySeparatorChar
         $csv_short_path += ($csv_path.Split($_dsep_) | Select-Object -Last 2) -Join $_dsep_
         
         Write-Host -ForegroundColor Yellow "Saving grades in $csv_short_path ..."
         
         if ($PSVersionTable.PSVersion.Major -ge 6)
         {
            $csv_to_fill | Select-Object * | Export-Csv  -Encoding "utf8NoBOM" -Delimiter ',' -Path $csv_path -Force
         }
         else
         {
            
            $csv_to_fill | Select-Object * | Export-Csv  -Encoding "utf8" -Delimiter ',' -Path $csv_path -NoTypeInformation -Force
            $csv_content = Get-Content $csv_path
            [System.IO.File]::WriteAllLines($csv_path, $csv_content) # convert to UTF8 without BOM
         }
    }
}

function Remove-ModelOutFiles
{
    param
    (
        [string] $TestDirPattern = ".*"
    )
    
    $dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue $cfg.TestsRootDir |`
            Where-Object {$_.Name -match "$TestDirPattern"}
    
    if ($dirs -eq $null)
    {
        Write-Host -ForegroundColor Green "No directories matched"
        return
    }
    
    Write-Host -ForegroundColor Green "Directories matched:"
    Write-Host -Separator "`n" $dirs.Name
    
    
    Write-Host -ForegroundColor Green "Processing:"
    ForEach ($dir in $dirs)
    {
        Write-Host -ForegroundColor Yellow $dir.Name

        $files = Get-ChildItem -Path $(Join-Path $dir.FullName "*") -File `
                 -Include ('*.grammar', '*.tokens', '*.sql_output', '*.sql_output_ps')
        
        ForEach ($file in $files)
        {
            Remove-Item $file.FullName -Force
            Write-Host -ForegroundColor Gray $file.Name
        }
    }
}

function Remove-StudentOutFiles
{
    param
    (
        [string] $TestDirPattern = ".*",
        [string] $StudentDirPattern = ".*"
    )
    
    $dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue $cfg.TestsRootDir |`
            Where-Object {$_.Name -match "$TestDirPattern"}
    
    if ($dirs -eq $null)
    {
        Write-Host -ForegroundColor Green "No directories matched"
        return
    }
    
    Write-Host -ForegroundColor Green "Directories matched:"
    Write-Host -Separator "`n" $dirs.Name
    
    
    Write-Host -ForegroundColor Green "Processing:"
    ForEach ($dir in $dirs)
    {
        Write-Host -ForegroundColor Yellow $dir.Name
        
        $students_dirs = Get-ChildItem -Directory -ErrorAction SilentlyContinue "$($dir.FullName)" | `
                         Where-Object {$_.Name -match "$StudentDirPattern"}
        
        if ($students_dirs -eq $null)
        {
            Write-Host -ForegroundColor Green "No students directories matched"
            continue
        }
        
        ForEach ($student_dir in $students_dirs)
        {
            Write-Host -ForegroundColor Gray $student_dir.Name
        
            $files = Get-ChildItem -Path $(Join-Path $student_dir.FullName "*") -File -Include `
                     ('*.grammar', '*.tokens', '*.sql_output', '*.sql_output_ps', '*.sql_errors', `
                      '*.multiple_sql', '*.parse_errors', '*.security_check', '*.tsqlchecker')
        
            ForEach ($file in $files)
            {
                Remove-Item $file.FullName -Force
                Write-Host -ForegroundColor Gray $file.Name
            }
        }
    }
}

#______________________________________________________________________________

if ($(Test-Path $default_config_file -PathType Leaf))
{
    Write-Host "Loading default config from $default_config_file ..."
    Import-MdtConfig
}

#______________________________________________________________________________

Export-ModuleMember -Function Import-MdtConfig, Get-MdtConfig, 
                              Test-SqlConnection, Get-ModelSqlTokensAndGrammar,
                              Get-ModelSqlOutput, Test-StudentSqlSanity,
                              Get-StudentSqlOutFiles, Get-StudentGrades,
                              Remove-ModelOutFiles, Remove-StudentOutFiles
