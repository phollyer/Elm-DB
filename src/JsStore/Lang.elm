module JsStore.Lang exposing
    ( By(..)
    , From(..)
    , In(..)
    , Into(..)
    , DB_Name(..)
    , On(..)
    , Operator(..)
    , Set(..)
    , With(..)
    , operatorToString
    )

{-|

@docs By
@docs From
@docs In
@docs Into
@docs DB_Name
@docs On
@docs Operator
@docs Set
@docs With
@docs operatorToString

-}

import JsStore.Schema as Schema
import Json.Encode exposing (Value)



{- General -}


{-| -}
type From
    = From String


{-| -}
type DB_Name
    = DB_Name String



{- Insert -}


{-| -}
type Into
    = Into String



{- Update -}


{-| -}
type In
    = In String


{-| -}
type Set
    = Set (List ( Schema.ColumnName, Value ))
    | WithOperator (List ( Schema.ColumnName, Operator, Value ))


{-| -}
type Operator
    = Add
    | Subtract
    | Multiply
    | Divide
    | Push


{-| -}
operatorToString : Operator -> String
operatorToString operator_ =
    case operator_ of
        Add ->
            "+"

        Subtract ->
            "-"

        Multiply ->
            "*"

        Divide ->
            "/"

        Push ->
            "{push}"



{- TODO: Organise!! -}


{-| The join condition.

    On "table1.common_field=table2.common_field"

-}
type On
    = On String


{-| -}
type With
    = With String


{-| -}
type By
    = By Schema.ColumnName
