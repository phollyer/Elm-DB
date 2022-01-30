module JsStore.Vendor exposing
    ( Request(..)
    , Response(..)
    , Data(..)
    , FuncName(..)
    , ImportScripts(..)
    , IsWorker(..)
    , Method(..)
    , Tables(..)
    )

{-|

@docs Request
@docs Response
@docs Data
@docs FuncName
@docs ImportScripts
@docs IsWorker
@docs Method
@docs Tables

-}

import JsStore.Lang exposing (DB_Name(..))
import JsStore.Schema as Schema
import Json.Encode exposing (Value)


{-| -}
type Request
    = TRANSACTION Tables Method Data ImportScripts
    | ADD_MIDDLEWARE (List ( FuncName, IsWorker ))
    | ADD_PLUGINS (List String)
    | SET ( String, Value )
    | GET String
    | GET_DB_LIST
    | LOG_STATUS Bool


{-| -}
type Response
    = Transaction (Maybe String) Value
    | Set (Maybe String) Value
    | Get (Maybe String) Value
    | GotDbList (Maybe String) Value
    | RequestQueueEmpty (Maybe String) Value
    | RequestQueueFilled (Maybe String) Value



{- Middleware -}


{-| -}
type FuncName
    = FuncName String


{-| -}
type IsWorker
    = IsWorker Bool



{- Transaction -}


{-| -}
type Data
    = Data Value


{-| -}
type Method
    = Method String


{-| -}
type Tables
    = Tables (List Schema.TableName)


{-| -}
type ImportScripts
    = ImportScripts (Maybe String)
