module JsStore exposing
    ( Request(..)
    , run, ID(..), runWith
    , Response(..), decode
    , Error(..)
    )

{-|

@docs Request
@docs run, ID, runWith
@docs Response, decode

---


# Examples

---


## COUNT


### **SQL**

```sql
Select count(*) From Customers;
```


### **JsStore**

```js
const results = await connection.count({
    from: "Customers"
    }
});
```


### **Elm**

    run port dbName <|
        Count (From "Customers") []

---

-}

import JsStore.DB as DB exposing (..)
import JsStore.Lang as Lang exposing (..)
import JsStore.Lang.Case as Case
import JsStore.Lang.Where as Where exposing (Where(..))
import JsStore.SQL as SQL exposing (..)
import JsStore.Schema as Schema exposing (TableName(..))
import JsStore.Vendor as Vendor exposing (..)
import Json.Decode as JD
import Json.Decode.Extra exposing (andMap)
import Json.Encode as JE exposing (Value)


type alias Port msg =
    Value -> Cmd msg



{- Build -}


{-| The Database Api. Use this to build your 'Sql like' statements.
-}
type Request a
    = TO_DB DB.Request
    | SQL_QUERY (SQL.Query a)
    | TO_VENDOR Vendor.Request


{-| -}
type Response
    = FROM_DB DB.Response
    | SQL_RESULT SQL.Result
    | FROM_VENDOR Vendor.Response
    | ERROR Error


{-| -}
run : Port msg -> DB_Name -> Request a -> Cmd msg
run elmToDb dbName =
    elmToDb << encode dbName Nothing


{-| -}
type ID
    = ID String


{-| -}
runWith : Port msg -> DB_Name -> ID -> Request a -> Cmd msg
runWith elmToDb dbName id =
    elmToDb << encode dbName (Just id)


type Error
    = NOT_OPEN TableName
    | FailedEvent String
    | InvalidEvent String
    | UnknowError String



{- Transform -}


errorFromString : String -> Error
errorFromString error =
    case String.split ":" error of
        [ "NOT_OPEN", tableName ] ->
            NOT_OPEN (TableName tableName)

        [ "INVALID_EVENT", event ] ->
            InvalidEvent event

        _ ->
            UnknowError error



{- Decoders -}


{-| -}
decode : { event : String, payload : Value, requestId : Maybe String } -> Response
decode { event, payload, requestId } =
    case event of
        "Created" ->
            FROM_DB <|
                DB.Created requestId payload

        "Opened" ->
            FROM_DB <|
                DB.Opened requestId payload

        "Upgraded" ->
            FROM_DB <|
                DB.Upgraded requestId payload

        "Terminated" ->
            FROM_DB <|
                DB.Terminated requestId payload

        "Dropped" ->
            FROM_DB <|
                DB.Dropped requestId payload

        "Inserted" ->
            SQL_RESULT <|
                SQL.Inserted requestId payload

        "Selected" ->
            SQL_RESULT <|
                SQL.Selected requestId payload

        "Union" ->
            SQL_RESULT <|
                SQL.Union requestId payload

        "Intersect" ->
            SQL_RESULT <|
                SQL.Intersect requestId payload

        "Counted" ->
            SQL_RESULT <|
                SQL.Counted requestId payload

        "Updated" ->
            SQL_RESULT <|
                SQL.Updated requestId payload

        "Cleared" ->
            SQL_RESULT <|
                SQL.Cleared requestId payload

        "Removed" ->
            SQL_RESULT <|
                SQL.Removed requestId payload

        "Transaction" ->
            FROM_VENDOR <|
                Vendor.Transaction requestId payload

        "Set" ->
            FROM_VENDOR <|
                Vendor.Set requestId payload

        "Get" ->
            FROM_VENDOR <|
                Vendor.Get requestId payload

        "GotDbList" ->
            FROM_VENDOR <|
                Vendor.GotDbList requestId payload

        "RequestQueueEmpty" ->
            FROM_VENDOR <|
                Vendor.RequestQueueEmpty requestId payload

        "RequestQueueFilled" ->
            FROM_VENDOR <|
                Vendor.RequestQueueFilled requestId payload

        "Error" ->
            let
                decoder : JD.Decoder String
                decoder =
                    JD.succeed
                        identity
                        |> andMap (JD.field "event" JD.string)
            in
            case JD.decodeValue decoder payload of
                Ok event_ ->
                    ERROR (FailedEvent event_)

                Err e ->
                    ERROR <|
                        FailedEvent <|
                            JD.errorToString e

        _ ->
            ERROR <|
                errorFromString <|
                    "INVALID_EVENT:"
                        ++ event



{- Encoders -}


{-| -}
encode : DB_Name -> Maybe ID -> Request a -> Value
encode dbName maybeId request =
    let
        encoder : String -> Value -> Value
        encoder msg value =
            JE.object
                [ ( "msg", JE.string msg )
                , ( "data", value )
                , ( "requestId"
                  , case maybeId of
                        Just (ID id) ->
                            JE.string id

                        Nothing ->
                            JE.null
                  )
                ]
    in
    case request of
        TO_DB expr ->
            encodeDB dbName encoder expr

        SQL_QUERY expr ->
            encodeSQL dbName encoder expr

        TO_VENDOR expr ->
            encodeVendor dbName encoder expr



{- DB -}


{-| -}
encodeDB : DB_Name -> (String -> Value -> Value) -> DB.Request -> Value
encodeDB (DB_Name dbName) encoder db =
    case db of
        INIT schema ->
            encoder "Init" <|
                Schema.encode dbName schema

        TERMINATE ->
            encoder "Terminate" <|
                JE.object [ ( "dbName", JE.string dbName ) ]

        DROP ->
            encoder "Drop" <|
                JE.object [ ( "dbName", JE.string dbName ) ]



{- SQL -}


{-| -}
encodeSQL : DB_Name -> (String -> Value -> Value) -> SQL.Query a -> Value
encodeSQL (DB_Name dbName) encoder sql =
    case sql of
        INSERT (Into tableName) values options ->
            encoder "Insert" <|
                encodeInsert dbName tableName values options

        SELECT (From tableName) options ->
            encoder "Select" <|
                encodeSelect dbName tableName options

        UNION (From tableName) whereQueries ->
            encoder "Union" <|
                JE.object
                    ([ ( "dbName", JE.string dbName )
                     , ( "from", JE.string tableName )
                     ]
                        |> Where.maybeEncode whereQueries
                    )

        INTERSECT (From tableName) whereQueries ->
            encoder "Intersect" <|
                JE.object
                    ([ ( "dbName", JE.string dbName )
                     , ( "from", JE.string tableName )
                     ]
                        |> Where.maybeEncode whereQueries
                    )

        COUNT (From tableName) whereQueries ->
            encoder "Count" <|
                JE.object
                    ([ ( "dbName", JE.string dbName )
                     , ( "from", JE.string tableName )
                     ]
                        |> Where.maybeEncode whereQueries
                    )

        UPDATE (In tableName) set options ->
            encoder "Update" <|
                encodeUpdate dbName tableName set options

        CLEAR tableName ->
            encoder "Clear" <|
                JE.object
                    [ ( "dbName", JE.string dbName )
                    , ( "tableName", (JE.string << Schema.tableName) tableName )
                    ]

        REMOVE (From tableName) whereList ->
            encoder "Remove" <|
                JE.object
                    ([ ( "dbName", JE.string dbName )
                     , ( "from", JE.string tableName )
                     ]
                        |> Where.maybeEncode whereList
                    )



{- INSERT -}


{-| -}
encodeInsert : String -> String -> Value -> List (Option a) -> Value
encodeInsert dbName tableName values options =
    JE.object
        ([ ( "dbName", JE.string dbName )
         , ( "into", JE.string tableName )
         , ( "values", values )
         ]
            |> encodeInsertOptions options
        )


encodeInsertOptions : List (Option a) -> List ( String, Value ) -> List ( String, Value )
encodeInsertOptions options list =
    List.foldl
        (\option newList ->
            case option of
                Return bool ->
                    ( "return", JE.bool bool ) :: newList

                Upsert bool ->
                    ( "upsert", JE.bool bool ) :: newList

                Validation bool ->
                    ( "validation", JE.bool bool ) :: newList

                SkipDataCheck bool ->
                    ( "skipDataCheck", JE.bool bool ) :: newList

                Ignore bool ->
                    ( "ignore", JE.bool bool ) :: newList

                _ ->
                    list
        )
        list
        options



{- SELECT -}


{-| -}
encodeSelect : String -> String -> List (Option a) -> Value
encodeSelect dbName tableName options =
    JE.object
        ([ ( "dbName", JE.string dbName )
         , ( "from", JE.string tableName )
         ]
            |> encodeSelectOptions options
        )


encodeSelectOptions : List (Option a) -> List ( String, Value ) -> List ( String, Value )
encodeSelectOptions options list =
    List.foldl encodeSelectOption list options


encodeSelectOption : Option a -> List ( String, Value ) -> List ( String, Value )
encodeSelectOption option list =
    case option of
        Limit num ->
            ( "limit", JE.int num ) :: list

        Skip num ->
            ( "skip", JE.int num ) :: list

        Order order ->
            ( "order", JE.list encodeOrder order ) :: list

        Aggregate aggregator (Schema.ColumnNames columnNames) ->
            ( "aggregate"
            , JE.object
                [ ( aggregatorToString aggregator, JE.list (JE.string << Schema.columnName) columnNames ) ]
            )
                :: list

        GroupBy g ->
            ( "groupBy", JE.list (JE.string << Schema.columnName) g ) :: list

        Distinct bool ->
            ( "distinct", JE.bool bool ) :: list

        Case cases ->
            ( "case"
            , JE.object <|
                List.map
                    (\( Schema.ColumnName columnName, Encoder encoder, criteria ) ->
                        ( columnName
                        , Case.encode encoder criteria
                        )
                    )
                    cases
            )
                :: list

        Join joins ->
            case joins of
                [] ->
                    list

                _ ->
                    ( "join", JE.list encodeJoin joins ) :: list

        Flatten bool ->
            ( "flatten", JE.bool bool ) :: list

        SQL.Where w ->
            Where.maybeEncode w list

        As l ->
            ( "as"
            , JE.object <|
                List.map
                    (\( currentColumnName, newColumnName ) ->
                        ( Schema.columnName currentColumnName
                        , JE.string newColumnName
                        )
                    )
                    l
            )
                :: list

        Type_ type_ ->
            case type_ of
                Left ->
                    list

                Inner ->
                    ( "type", JE.string "inner" ) :: list

        IdbSorting bool ->
            ( "idbSorting", JE.bool bool ) :: list

        _ ->
            list


{-| -}
aggregatorToString : Aggregator -> String
aggregatorToString aggregator =
    case aggregator of
        Count ->
            "count"

        Sum ->
            "sum"

        Avg ->
            "avg"

        Max ->
            "max"

        Min ->
            "min"


encodeOrder : ( By, SortDirection, List (Option a) ) -> Value
encodeOrder ( By (Schema.ColumnName columnName), direction, options ) =
    JE.object
        (encodeSelectOptions options <|
            [ ( "by", JE.string columnName )
            , ( "type"
              , JE.string <|
                    case direction of
                        ASC ->
                            "asc"

                        DESC ->
                            "desc"
              )
            ]
        )


encodeJoin : ( With, On, List (Option a) ) -> Value
encodeJoin ( With with, On on_, options ) =
    JE.object
        ([ ( "with", JE.string with )
         , ( "on", JE.string on_ )
         ]
            |> encodeSelectOptions options
        )



{- UPDATE -}


{-| -}
encodeUpdate : String -> String -> Set -> List (Option a) -> Value
encodeUpdate dbName tableName set options =
    JE.object
        ([ ( "dbName", JE.string dbName )
         , ( "in", JE.string tableName )
         , ( "set", encodeSet set )
         ]
            |> encodeUpdateOptions options
        )


encodeSet : Set -> Value
encodeSet set =
    case set of
        Lang.Set list ->
            JE.object <|
                List.map
                    (\( columnName, value ) ->
                        ( Schema.columnName columnName, value )
                    )
                    list

        WithOperator list ->
            JE.object <|
                List.map
                    (\( columnName, operator, value ) ->
                        ( Schema.columnName columnName
                        , JE.object
                            [ ( operatorToString operator, value ) ]
                        )
                    )
                    list


encodeUpdateOptions : List (Option a) -> List ( String, Value ) -> List ( String, Value )
encodeUpdateOptions options list =
    List.foldl
        (\option acc ->
            case option of
                SQL.Where whereList ->
                    Where.maybeEncode whereList acc

                MapSet funcName ->
                    ( "mapSet", JE.string funcName ) :: acc

                _ ->
                    list
        )
        list
        options



{- Vendor -}


{-| -}
encodeVendor : DB_Name -> (String -> Value -> Value) -> Vendor.Request -> Value
encodeVendor (DB_Name dbName) encoder vendor =
    case vendor of
        TRANSACTION (Tables tables) (Method method) (Data data) (ImportScripts maybeImportScripts) ->
            let
                encodeImportScripts : Maybe String -> List ( String, Value ) -> List ( String, Value )
                encodeImportScripts maybeScript list =
                    case maybeScript of
                        Nothing ->
                            list

                        Just script ->
                            ( "importScripts", JE.string script ) :: list
            in
            encoder "Transaction" <|
                JE.object
                    ([ ( "dbName", JE.string dbName )
                     , ( "tables", JE.list (JE.string << Schema.tableName) tables )
                     , ( "method", JE.string method )
                     , ( "data", data )
                     ]
                        |> encodeImportScripts maybeImportScripts
                    )

        ADD_MIDDLEWARE middleware ->
            let
                middlewareEncoder : ( FuncName, IsWorker ) -> Value
                middlewareEncoder ( FuncName funcName, IsWorker isWorker ) =
                    JE.object
                        [ ( "funcName", JE.string funcName )
                        , ( "isWorker", JE.bool isWorker )
                        ]
            in
            encoder "AddMiddleware" <|
                JE.object
                    [ ( "dbName", JE.string dbName )
                    , ( "middleware", JE.list middlewareEncoder middleware )
                    ]

        ADD_PLUGINS plugins ->
            encoder "AddPlugins" <|
                JE.object
                    [ ( "dbName", JE.string dbName )
                    , ( "plugins", JE.list JE.string plugins )
                    ]

        SET ( key, value ) ->
            encoder "Set" <|
                JE.object
                    [ ( "dbName", JE.string dbName )
                    , ( "key", JE.string key )
                    , ( "value", value )
                    ]

        GET key ->
            encoder "Get" <|
                JE.object
                    [ ( "dbName", JE.string dbName )
                    , ( "key", JE.string key )
                    ]

        GET_DB_LIST ->
            encoder "GetDbList" <|
                JE.object
                    [ ( "dbName", JE.string dbName ) ]

        LOG_STATUS status ->
            encoder "LogStatus" <|
                JE.object
                    [ ( "dbName", JE.string dbName )
                    , ( "logStatus", JE.bool status )
                    ]
