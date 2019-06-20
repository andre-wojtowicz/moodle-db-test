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
    }
    QueryWords = @{
        't-04' = 'HAVING'
        't-05' = 'EXISTS'
    }
    ForbiddenClauses = @{
    }
}
