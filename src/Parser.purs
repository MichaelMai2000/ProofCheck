-- module Parser (defaultMap, symbol, expression) where
module Parser where

import Prelude (($), (||), (&&), (/=), (<$>), (<>), (<<<), bind, pure)
import Control.Alt ((<|>))
import Data.Array as A
import Data.Char.Unicode as U
import Data.Either (Either(..))
import Data.Map (Map)
import Data.Map as M
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits (fromCharArray)
import Data.Tuple (Tuple(..))
import Text.Parsing.Parser (Parser)
import Text.Parsing.Parser as P
import Text.Parsing.Parser.Combinators ((<?>))
import Text.Parsing.Parser.Combinators as PC
import Text.Parsing.Parser.String as PS
import Text.Parsing.Parser.Token as PT

import WFF (UnaryOp, BinaryOp, WFF)
import WFF as WFF

type SymbolMap = Map String (Either UnaryOp BinaryOp)

defaultMap :: SymbolMap
defaultMap = M.fromFoldable
    [ Tuple "&" $ Right WFF.andOp
    , Tuple "|" $ Right WFF.orOp
    , Tuple "->" $ Right WFF.impliesOp
    , Tuple "~" $ Left WFF.negOp
    ]

symbol :: Parser String String
symbol = fromCharArray <$> A.some
    ( PS.satisfy
        ((U.isPunctuation || U.isSymbol) && (_ /= '(') && (_ /= ')'))
        <?> "Symbol or Punctuation"
    )

definedSymbol :: SymbolMap -> Parser String (Either UnaryOp BinaryOp)
definedSymbol m = do
    p <- P.position
    s <- symbol
    case M.lookup s m of
        Just o -> pure o
        Nothing -> P.failWithPosition ("Unrecognised symbol: " <> s) p

proposition :: Parser String (WFF String)
proposition = WFF.Prop <<< fromCharArray <$> A.some PT.letter

safeExpression :: SymbolMap -> Parser String (WFF String)
safeExpression m = proposition
    <|> PC.between (PS.char '(') (PS.char ')') (expression m)

unaryExpression :: SymbolMap -> Parser String (WFF String)
unaryExpression m = do
    p <- P.position
    o <- definedSymbol m
    contents <- safeExpression m
    case o of
        Left operator -> pure $ WFF.Unary { operator, contents }
        Right _ -> P.failWithPosition "Expected Unary Symbol" p


tailBinaryExpression :: SymbolMap ->
    Parser String { operator :: BinaryOp, right :: WFF String }
tailBinaryExpression m = do
    p <- P.position
    o <- definedSymbol m
    right <- safeExpression m
    case o of
        Right operator -> pure { operator, right }
        Left _ -> P.failWithPosition "Expected Binary Symbol" p

maybeBinaryExpression :: SymbolMap -> Parser String (WFF String)
maybeBinaryExpression m = do
    left <- safeExpression m
    rest <- PC.option Nothing $ Just <$> tailBinaryExpression m
    case rest of
        Nothing -> pure left
        Just {right, operator} -> pure $ WFF.Binary $ {left, operator, right}

expression :: SymbolMap -> Parser String (WFF String)
expression m = maybeBinaryExpression m <|> unaryExpression m
