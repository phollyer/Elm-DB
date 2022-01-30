module JsStore.Lang.Where exposing
    ( Where(..), Encoder(..), Option(..)
    , Low(..), High(..), Predicate(..)
    , maybeEncode
    )

{-|

@docs Where, Encoder, Option
@docs Low, High, Predicate
@docs maybeEncode

-}

import JsStore.Schema as Schema
import Json.Encode as JE exposing (Value)



{- Build -}


{-| -}
type Where a
    = Where ( Schema.ColumnName, Encoder a, List (Option a) )


{-| -}
type Encoder a
    = Encoder (Maybe (a -> Value))


{-| -}
type Option a
    = EQ_TO a
    | Like Like
    | In (List a)
    | Or (List (Where a))
    | Predicates (List (Predicate a))


{-| -}
type Like
    = StartsWith String
    | EndsWith String
    | Contains String


{-| -}
type Predicate a
    = GT a
    | GT_EQ a
    | LT a
    | LT_EQ a
    | NOT_EQ a
    | BETWEEN Low High


{-| -}
type Low
    = Low Int


{-| -}
type High
    = High Int



{- Encoders -}


{-| -}
maybeEncode : List (Where a) -> List ( String, Value ) -> List ( String, Value )
maybeEncode whereList list =
    case whereList of
        [] ->
            list

        _ ->
            ( "where"
            , JE.object <|
                encode whereList []
            )
                :: list


encode : List (Where a) -> List ( String, Value ) -> List ( String, Value )
encode whereList list =
    case whereList of
        [] ->
            list

        (Where ( Schema.ColumnName columnName, Encoder maybeEncoder, options )) :: rest ->
            let
                foundEqTo =
                    List.filter
                        (\option ->
                            case option of
                                EQ_TO _ ->
                                    True

                                _ ->
                                    False
                        )
                        options

                foundOr =
                    List.filter
                        (\option ->
                            case option of
                                Or _ ->
                                    True

                                _ ->
                                    False
                        )
                        options
            in
            encode rest <|
                case ( foundEqTo, foundOr, maybeEncoder ) of
                    ( (EQ_TO eqTo) :: _, (Or or_) :: _, Just encoder ) ->
                        [ ( columnName, encoder eqTo )
                        , ( "or"
                          , JE.object <|
                                encode or_ []
                          )
                        ]
                            ++ list

                    ( (EQ_TO eqTo) :: _, [], Just encoder ) ->
                        ( columnName, encoder eqTo ) :: list

                    ( [], (Or or_) :: _, Just encoder ) ->
                        [ ( columnName
                          , JE.object <|
                                encodeOptions encoder options []
                          )
                        , ( "or"
                          , JE.object <|
                                encode or_ []
                          )
                        ]
                            ++ list

                    ( [], [], Just encoder ) ->
                        ( columnName
                        , JE.object <|
                            encodeOptions encoder options []
                        )
                            :: list

                    ( [], [], Nothing ) ->
                        let
                            foundLike =
                                List.filter
                                    (\option ->
                                        case option of
                                            Like _ ->
                                                True

                                            _ ->
                                                False
                                    )
                                    options
                        in
                        case foundLike of
                            (Like like) :: _ ->
                                ( columnName
                                , JE.object <|
                                    [ ( "like"
                                      , JE.string <|
                                            case like of
                                                StartsWith val ->
                                                    "%" ++ val

                                                EndsWith val ->
                                                    val ++ "%"

                                                Contains val ->
                                                    "%" ++ val ++ "%"
                                      )
                                    ]
                                )
                                    :: list

                            _ ->
                                list

                    _ ->
                        list


encodeOptions : (a -> Value) -> List (Option a) -> List ( String, Value ) -> List ( String, Value )
encodeOptions encoder options list =
    case options of
        [] ->
            list

        option :: rest ->
            encodeOptions encoder rest <|
                encodeOption encoder option list


encodeOption : (a -> Value) -> Option a -> List ( String, Value ) -> List ( String, Value )
encodeOption encoder option list =
    case option of
        Like like ->
            ( "like"
            , JE.string <|
                case like of
                    StartsWith val ->
                        "%" ++ val

                    EndsWith val ->
                        val ++ "%"

                    Contains val ->
                        "%" ++ val ++ "%"
            )
                :: list

        In inList ->
            ( "in"
            , JE.list encoder inList
            )
                :: list

        Predicates predicateList ->
            encodePredicates encoder predicateList list

        _ ->
            list


encodePredicates : (a -> Value) -> List (Predicate a) -> List ( String, Value ) -> List ( String, Value )
encodePredicates encoder predicates list =
    case predicates of
        [] ->
            list

        predicate :: rest ->
            encodePredicates encoder rest <|
                case predicate of
                    GT val ->
                        ( ">", encoder val ) :: list

                    GT_EQ val ->
                        ( ">=", encoder val ) :: list

                    LT val ->
                        ( "<", encoder val ) :: list

                    LT_EQ val ->
                        ( "<=", encoder val ) :: list

                    NOT_EQ val ->
                        ( "!=", encoder val ) :: list

                    BETWEEN (Low low) (High high) ->
                        ( "-"
                        , JE.object
                            [ ( "low", JE.int low )
                            , ( "high", JE.int high )
                            ]
                        )
                            :: list
