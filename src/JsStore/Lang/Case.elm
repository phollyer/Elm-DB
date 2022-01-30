module JsStore.Lang.Case exposing
    ( Branch(..)
    , Case
    , CompareWith(..)
    , Default(..)
    , Encoder(..)
    , ReplaceWith(..)
    , Then
    , encode
    )

{-|

@docs Branch
@docs Case
@docs CompareWith
@docs Default
@docs Encoder
@docs ReplaceWith
@docs Then
@docs encode

-}

import Json.Encode as JE exposing (Value)


{-| -}
type alias Case a =
    ( List (Branch a), Default a )


{-| Build the criteria for one branch of the `case` statement.

Example 1 - Replace "cat" with "pfft"

    EQ (CompareWith "cat") (Then (ReplaceWith "pfft"))

Example 2 - Replace all values `>=` 101 with 100

    GT_EQ (CompareWith 101) (Then (ReplaceWith 100))

Sometimes you just want to return the stored value unchanged, there are two
slightly different forms available, choose your preference.

Example 3 - The short hand

    EQ (CompareWith "dog") Nothing

Example 4 - longer, but more readable

    EQ (CompareWith "dog") (Then StoredValue)

-}
type Branch a
    = EQ (CompareWith a) (Then (ReplaceWith a))
    | GT (CompareWith a) (Then (ReplaceWith a))
    | GT_EQ (CompareWith a) (Then (ReplaceWith a))
    | LT (CompareWith a) (Then (ReplaceWith a))
    | LT_EQ (CompareWith a) (Then (ReplaceWith a))
    | NOT_EQ (CompareWith a) (Then (ReplaceWith a))


{-| The value to compare against.
-}
type CompareWith a
    = CompareWith a


{-| The replacement value to use if the comparison matched.
-}
type ReplaceWith a
    = ReplaceWith a
    | StoredValue


{-| A type alias for `Maybe` provided to help readability when constructing the
[Criteria](#Criteria).

Choose your preference.

-}
type alias Then a =
    Maybe a


{-| The default value to use if none of the [Criteria](#Criteria) match.
-}
type Default a
    = Default a
    | Null


{-| -}
type Encoder a
    = Encoder (a -> Value)



{- Encoders -}


{-| -}
encode : (a -> Value) -> Case a -> Value
encode encoder ( branches, default ) =
    let
        defaultEncoded =
            JE.object
                [ ( "then"
                  , case default of
                        Default default_ ->
                            encoder default_

                        Null ->
                            JE.null
                  )
                ]

        criteria =
            List.map (branchEncoder encoder) branches
    in
    JE.list identity (criteria ++ [ defaultEncoded ])


branchEncoder : (a -> Value) -> Branch a -> Value
branchEncoder encoder expression =
    let
        toJson : String -> CompareWith a -> Maybe (ReplaceWith a) -> Value
        toJson key (CompareWith s) maybeReplacement =
            JE.object
                [ ( key, encoder s )
                , ( "then"
                  , case maybeReplacement of
                        Just (ReplaceWith replacement) ->
                            encoder replacement

                        Just StoredValue ->
                            JE.null

                        Nothing ->
                            JE.null
                  )
                ]
    in
    case expression of
        EQ searchValue maybeReplacement ->
            toJson "=" searchValue maybeReplacement

        GT searchValue maybeReplacement ->
            toJson ">" searchValue maybeReplacement

        GT_EQ searchValue maybeReplacement ->
            toJson ">=" searchValue maybeReplacement

        LT searchValue maybeReplacement ->
            toJson "<" searchValue maybeReplacement

        LT_EQ searchValue maybeReplacement ->
            toJson "<=" searchValue maybeReplacement

        NOT_EQ searchValue maybeReplacement ->
            toJson "!=" searchValue maybeReplacement
