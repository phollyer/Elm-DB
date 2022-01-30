module JsStore.SQL exposing
    ( Query(..)
    , Result(..)
    , Aggregator(..)
    , Encoder(..)
    , JoinType(..)
    , Option(..)
    , SortDirection(..)
    )

{-|

@docs Query
@docs Result
@docs Aggregator
@docs Encoder
@docs JoinType
@docs Option
@docs SortDirection

-}

import JsStore.Lang exposing (..)
import JsStore.Lang.Case exposing (Case, CompareWith(..), Default(..), ReplaceWith(..))
import JsStore.Lang.Where exposing (Where(..))
import JsStore.Schema as Schema
import Json.Encode exposing (Value)


{-| The Database Api. Use this to build your 'Sql like' statements.
-}
type Query a
    = INSERT Into Value (List (Option a))
    | SELECT From (List (Option a))
    | UNION From (List (Where a))
    | INTERSECT From (List (Where a))
    | COUNT From (List (Where a))
    | UPDATE In Set (List (Option a))
    | CLEAR Schema.TableName
    | REMOVE From (List (Where a))


{-| -}
type Result
    = Inserted (Maybe String) Value
    | Selected (Maybe String) Value
    | Union (Maybe String) Value
    | Intersect (Maybe String) Value
    | Counted (Maybe String) Value
    | Updated (Maybe String) Value
    | Cleared (Maybe String) Value
    | Removed (Maybe String) Value



{- Options -}


{-| Additional options available when `Insert`ing rows into tables.

  - **Return** - Return the records after they have been inserted. This is useful if
    [autoIncrement](JsStore.DB.Column#autoIncrement) is used on the column and it
    is necessary to retrieve the value.

    **Default:** `False`

  - **Upsert** - If the data being inserted already exists, update it, otherwise insert it.

    **Default:** `False`

  - **Validation** - Validate data - or not. If set to `False` this can speed up the insert
    operation by not checking data types.

    **Default:** `True`

  - **SkipDataCheck** - If set to `True` then checking the data type and
    auto-incrementing the `autoIncrement` column are not performed. This can
    speed up the insert operation.

    **Default:** False

  - **Ignore** - If an error occurs when inserting data the whole transaction is aborted.
    To prevent this, set `ignore` to `True` which allows valid rows to be inserted and
    invalid rows that throw errors to be ignored.

    **Default:** `False`

    Additional options available when `Select`ing rows in a table.

  - **Join** - Add some [Join](JsStore.CRUD.Join#Join)s.

  - **Where** - Add some [Where](JsStore.Query.Where) filters.

  - **Case** - Add some [Case](JsStore.CRUD.Case#Case) statements.

  - **Order** - Sort the data into ascending or descending order based on one
    or more columns.

  - **GroupBy** - Group results by one or more columns.

  - **Distinct** - Filter out duplicate records.

  - **Limit** - Set the maximum number of records to return.

  - **Skip** - Set the number of records to skip.

  - **Aggregate** - Perform
    [Aggregate](JsStore.CRUD.Aggregate#Aggregate) functions on the
    columns.

  - **Aggregates** - Add some [Aggregate](JsStore.CRUD.Aggregate)
    functions.

  - **Flatten** -Turn a record with a column of type `array` into an `array` of records.

    `flatten == False`:

    ```js
        {
        name = "Slow Joe",
        hobbies = [ "Acting", "Lying" ]
        }
    ```

    `flatten == True`:

    ```js
        [{
        name = "Slow Joe",
        hobbies = "Acting"
        },
        {
        name = "Slow Joe",
        hobbies = "Lying"
        }]
    ```

    **Default:** `False`

  - **As** - Rename a column to avoid conflicts.

        Join.with (Schema.TableName "Customers") <|
            On "Orders.customerId=Customers.customerId" <|
                [ As [ ( Schema.ColumnName "conflictingColumnName", "newColumnName" ) ] ]

  - **Type** - Set the type of `Join`.

-}
type Option a
    = -- Insert
      Return Bool
    | Upsert Bool
    | Validation Bool
    | SkipDataCheck Bool
    | Ignore Bool
      -- Select
    | Join (List ( With, On, List (Option a) ))
    | Case (List ( Schema.ColumnName, Encoder a, Case a ))
    | Order (List ( By, SortDirection, List (Option a) ))
    | GroupBy (List Schema.ColumnName)
    | Distinct Bool
    | Limit Int
    | Skip Int
    | Aggregate Aggregator Schema.ColumnNames
    | Flatten Bool
    | As (List ( Schema.ColumnName, String ))
    | Type_ JoinType
    | IdbSorting Bool
      -- Update
    | MapSet String
      -- Select & Update
    | Where (List (Where a))


{-| -}
type Encoder a
    = Encoder (a -> Value)


{-| -}
type SortDirection
    = ASC
    | DESC


{-| The type of `Join`.
[JsStore](https://jsstore.net/tutorial/select/join/) supports two types of
join - Left and Inner.

**Default:** `Left`

-}
type JoinType
    = Inner
    | Left


{-| -}
type Aggregator
    = Count
    | Sum
    | Avg
    | Max
    | Min
