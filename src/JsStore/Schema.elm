module JsStore.Schema exposing
    ( Schema(..), Version(..), Tables(..), Table(..), TableName(..), Columns(..), Column(..), ColumnName(..), ColumnNames(..), Attributes(..), Attribute(..), DataType(..), Alter(..), Action(..)
    , tableName, tableNames, columnName, tables
    , encode
    )

{-|

@docs Schema, Version, Tables, Table, TableName, Columns, Column, ColumnName, ColumnNames, Attributes, Attribute, DataType, Alter, Action
@docs tableName, tableNames, columnName, tables
@docs encode

-}

import Json.Encode as JE exposing (Value)



{- Build -}


{-| -}
type Schema
    = Schema ( Version, Tables )


{-| -}
type Version
    = Version Int


{-| -}
type Tables
    = Tables (List Table)


{-| -}
type TableName
    = TableName String


{-| -}
type Table
    = Table ( TableName, Columns, List Alter )


{-| -}
type Columns
    = Columns (List Column)


{-| -}
type Column
    = Column ( ColumnName, Attributes )


{-| -}
type ColumnName
    = ColumnName String


{-| -}
type ColumnNames
    = ColumnNames (List ColumnName)


{-| -}
type Attributes
    = Attributes (List Attribute)


{-| -}
type Attribute
    = PrimaryKey Bool
    | NotNull Bool
    | DataType DataType
    | AutoIncrement Bool
    | Unique Bool
    | MultiEntry Bool
    | EnableSearch Bool
    | KeyPath (List String)


{-| -}
type DataType
    = String_
    | Number
    | DateTime
    | Object
    | Array
    | Boolean


{-| -}
type Alter
    = Alter ( Version, List Action )


{-| -}
type Action
    = Modify (List Column)
    | Add (List Column)
    | Drop (List Column)



{- Queries -}


{-| -}
tableName : TableName -> String
tableName (TableName name) =
    name


{-| -}
tableNames : Schema -> List String
tableNames =
    tables >> List.map (\(Table ( TableName name, _, _ )) -> name)


{-| -}
columnName : ColumnName -> String
columnName (ColumnName name) =
    name


{-| -}
tables : Schema -> List Table
tables (Schema ( _, Tables tables_ )) =
    tables_



{- Encoders -}


{-| -}
encode : String -> Schema -> Value
encode dbName (Schema ( Version version_, Tables tables_ )) =
    JE.object
        [ ( "name", JE.string dbName )
        , ( "version", JE.int version_ )
        , ( "tables", JE.list encodeTable tables_ )
        ]


encodeTable : Table -> Value
encodeTable (Table ( TableName name, Columns columns, alterList )) =
    JE.object
        [ ( "name", JE.string name )
        , ( "columns", (JE.object << List.map encodeColumn) columns )
        , ( "alter", (JE.object << List.map encodeAlter) alterList )
        ]


encodeColumn : Column -> ( String, Value )
encodeColumn (Column ( ColumnName name, Attributes attributes )) =
    ( name
    , JE.object <|
        List.map encodeAttribute attributes
    )


encodeAttribute : Attribute -> ( String, Value )
encodeAttribute attribute =
    case attribute of
        PrimaryKey bool ->
            ( "primaryKey", JE.bool bool )

        NotNull bool ->
            ( "notNull", JE.bool bool )

        DataType dataType ->
            ( "dataType"
            , JE.string <|
                case dataType of
                    String_ ->
                        "string"

                    Number ->
                        "number"

                    DateTime ->
                        "date_time"

                    Object ->
                        "object"

                    Array ->
                        "array"

                    Boolean ->
                        "boolean"
            )

        AutoIncrement bool ->
            ( "autoIncrement", JE.bool bool )

        Unique bool ->
            ( "unique", JE.bool bool )

        MultiEntry bool ->
            ( "multiEntry", JE.bool bool )

        EnableSearch bool ->
            ( "enableSearch", JE.bool bool )

        KeyPath keyPaths ->
            ( "keyPath", JE.list JE.string keyPaths )


encodeAlter : Alter -> ( String, Value )
encodeAlter (Alter ( Version version_, actions )) =
    ( String.fromInt version_
    , JE.object <|
        List.map encodeAction actions
    )


encodeAction : Action -> ( String, Value )
encodeAction action =
    case action of
        Modify columns ->
            ( "modify", (JE.object << List.map encodeColumn) columns )

        Add columns ->
            ( "add", (JE.object << List.map encodeColumn) columns )

        Drop columns ->
            ( "drop", (JE.object << List.map encodeColumn) columns )
