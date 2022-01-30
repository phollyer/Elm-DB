module JsStore.DB exposing
    ( Request(..)
    , Response(..)
    )

{-|

@docs Request
@docs Response

-}

import JsStore.Schema exposing (Schema)
import Json.Encode exposing (Value)


{-| -}
type Request
    = INIT Schema
    | TERMINATE
    | DROP


{-| -}
type Response
    = Created (Maybe String) Value
    | Opened (Maybe String) Value
    | Upgraded (Maybe String) Value
    | Terminated (Maybe String) Value
    | Dropped (Maybe String) Value
