import Html exposing (Html, div, text, button, span, textarea)
import Html.Attributes exposing (id, class, disabled, classList, value)
import Html.Events exposing (onClick, onInput)

import Json.Encode exposing (encode)
import Json.Decode exposing (decodeString)

import Proof exposing (Proof, DeductionRule(..), empty, addSequent, addSymbol)
import ProofUI exposing
    (NewLine, LineMsg(..), renderLines, blank, updateNewLine, submitLine)
import SequentUI exposing
    (NewSequent, SequentMsg, blank, updateSeq, renderSequents, submitSeq)
import SymbolUI exposing
    (NewSymbol, SymbolMsg, blank, updateSym, renderSymbols, submitSym)
import ProofJson exposing (..)

main : Program Never Model Msg
main = Html.beginnerProgram
    { model = start
    , view = view
    , update = update
    }

type alias Model =
    { proof : Proof
    , history : List Proof
    , future : List Proof
    , latestError : Maybe String
    , newLine : NewLine
    , newSeq : NewSequent
    , newSym : NewSymbol
    , activeWindow : Window
    , importText : Maybe String
    }

start : Model
start =
    { proof = empty
    , history = []
    , future = []
    , latestError = Nothing
    , newLine = ProofUI.blank
    , newSeq = SequentUI.blank
    , newSym = SymbolUI.blank
    , activeWindow = NoWindow
    , importText = Nothing
    }

type Msg
    = Lines LineMsg
    | SubmitLine
    | NewSeq SequentMsg
    | AddSequent
    | NewSym SymbolMsg
    | AddSymbol
    | New
    | Undo
    | Redo
    | Open Window
    | NewImport String
    | Import

type Window
    = NoWindow
    | SequentWindow
    | SymbolWindow
    | ImExWindow

update : Msg -> Model -> Model
update msg model = case msg of
    Lines linemsg -> { model | newLine = updateNewLine linemsg model.newLine }
    SubmitLine -> case submitLine model.proof model.newLine of
        Err s -> { model | latestError = Just s }
        Ok p ->
            { model
            | history = model.proof :: model.history
            , future = []
            , proof = p
            , latestError = Nothing
            , newLine = ProofUI.blank
            , importText = Nothing
            }
    NewSeq seqmsg -> { model | newSeq = updateSeq model.newSeq seqmsg }
    AddSequent -> case submitSeq model.proof model.newSeq of
        Err s -> { model | latestError = Just s }
        Ok n ->
            { model
            | history = model.proof :: model.history
            , future = []
            , proof = addSequent n model.proof
            , latestError = Nothing
            , newSeq = SequentUI.blank
            , importText = Nothing
            }
    NewSym symmsg -> { model | newSym = updateSym model.newSym symmsg }
    AddSymbol -> case submitSym model.proof model.newSym of
        Err s -> { model | latestError = Just s }
        Ok n ->
            { model
            | history = model.proof :: model.history
            , future = []
            , proof = addSymbol n model.proof
            , latestError = Nothing
            , newSym = SymbolUI.blank
            , importText = Nothing
            }
    New ->
        if model.proof == Proof.empty then
            model
        else
            { start | history = model.proof :: model.history }
    Undo -> case model.history of
        [] -> model
        (x::xs) ->
            { model
            | history = xs
            , future = model.proof::model.future
            , proof = x
            , importText = Nothing
            }
    Redo -> case model.future of
        [] -> model
        (x::xs) ->
            { model
            | history = model.proof::model.history
            , future = xs
            , proof = x
            , importText = Nothing
            }
    Open x -> { model | activeWindow = x }
    NewImport s -> { model | importText = Just s }
    Import -> case model.importText of
        Nothing -> model
        Just s -> case decodeString fromjson s of
            Err e ->
                { model
                | latestError = Just <| "Error importing proof: " ++ e
                }
            Ok proof ->
                { start
                | history = model.proof :: model.history
                , proof = proof
                }


closeButton : Html Msg
closeButton = button
    [ onClick <| Open NoWindow
    , id "close-button"
    ] [ text "X" ]

sequentBox : Model -> Html Msg
sequentBox model = div [ class "floating", id "sequent-box" ]
    [ Html.map NewSeq <| renderSequents model.proof model.newSeq
    , button [ onClick AddSequent, id "add-sequent" ] [ text "Add Sequent" ]
    , closeButton
    ]

symbolBox : Model -> Html Msg
symbolBox model = div [ class "floating", id "symbol-box" ]
    [ Html.map NewSym <| renderSymbols model.proof model.newSym
    , button [ onClick AddSymbol, id "add-symbol" ] [ text "Add Symbol" ]
    , closeButton
    ]

imexText : Model -> String
imexText model = case (tojson model.proof, model.importText) of
    (_, Just s) -> s
    (Err e, Nothing) -> "Error exporting proof: " ++ e
    (Ok json, Nothing) -> encode 0 json

imexBox : Model -> Html Msg
imexBox model = div [ class "floating", id "import-export-box" ]
    [ text "Copy this to save proof, or paste here to import proof"
    , textarea
        [ onInput NewImport
        , id "json-input"
        , value <| imexText model
        ] []
    , button
        [ onClick Import
        , id "import-button"
        , disabled <| model.importText == Nothing
        ] [ text "Import" ]
    , closeButton
    ]

activeBox : Model -> Html Msg
activeBox model = case model.activeWindow of
    NoWindow -> text ""
    SequentWindow -> sequentBox model
    SymbolWindow -> symbolBox model
    ImExWindow -> imexBox model

proofBox : Model -> Html Msg
proofBox model = div [ id "proof-box" ]
    [ Html.map Lines <| renderLines model.proof model.newLine
    , button [ onClick SubmitLine, id "add-line" ] [ text "Add Line" ]
    ]

menu : Model -> Html Msg
menu model = div [ id "menu" ]
    [ div
        [ classList
            [ ("menu-button", True)
            , ("disabled", model.proof == Proof.empty)
            ]
        , id "new-button"
        , onClick New
        ] [ text "New" ]
    , div
        [ classList
            [ ("menu-button", True)
            , ("disabled", model.history == [])
            ]
        , id "undo-button"
        , onClick Undo
        ] [ text "Undo" ]
    , div
        [ classList
            [ ("menu-button", True)
            , ("disabled", model.future == [])
            ]
        , id "redo-button"
        , onClick Redo
        ] [ text "Redo" ]
    , div
        [ class "menu-button"
        , id "symbol-window-button"
        , onClick <| Open SymbolWindow
        ] [ text "Symbols" ]
    , div
        [ class "menu-button"
        , id "sequent-window-button"
        , onClick <| Open SequentWindow
        ] [ text "Sequents" ]
    , div
        [ class "menu-button"
        , id "import-export-window-button"
        , onClick <| Open ImExWindow
        ] [ text "Import/Export" ]
    ]

view : Model -> Html Msg
view model = div [ id "main" ]
    [ menu model
    , activeBox model
    , proofBox model
    , case model.latestError of
        Nothing -> text ""
        Just e -> div [ id "error" ] [ text e ]
    ]
