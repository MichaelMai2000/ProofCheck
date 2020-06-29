module Sequent
    ( Sequent(..)
    , render
    , match
    , matchLift
    , verifyTypes
    ) where

import Prelude
    ( class Eq, class Ord
    , (<>), (<$>), ($), (==), (<<<), (&&)
    , bind, pure, otherwise)
import Data.Array as A
import Data.Foldable (fold, foldMap, all)
import Data.String.Common (joinWith)
import Data.Tuple (Tuple(..))
import Data.Traversable (traverse)
import Data.Maybe (Maybe(..))

import WFF (WFF)
import WFF as WFF

data Sequent pred free bound = Sequent
    { ante :: Array (WFF pred free bound)
    , conse :: WFF pred free bound
    }

derive instance eqSequent :: (Eq pred, Eq free, Eq bound) =>
    Eq (Sequent pred free bound)
derive instance ordSequent :: (Ord pred, Ord free, Ord bound) =>
    Ord (Sequent pred free bound)

render :: Sequent String String String -> String
render (Sequent s) =
    joinWith "," (WFF.render <$> s.ante) <> " ⊢ " <> WFF.render s.conse

-- Match a sequent to one after substitutions were applied
match1 :: forall a b c x y z. Ord a => Ord b => Eq x => Ord y =>
    Sequent a b c -> Sequent x y z -> WFF.Matches a b x y
match1 (Sequent small) (Sequent big) =
    fold (A.zipWith WFF.match small.ante big.ante)
    <> WFF.match small.conse big.conse

permute :: forall a. Eq a => Array a -> Array (Array a)
permute [] = [[]]
permute l = do
    h <- l
    t <- permute $ A.delete h l
    pure $ A.cons h t

-- Match a sequent to one after substitutions were applied and the antecedents
-- permuted, returning all possible inverse permutations
match :: forall a b c x y z i.
    Ord a => Ord b => Eq x => Ord y => Eq z => Eq i =>
    Array i -> Sequent a b c -> Sequent x y z -> Array (Array i)
match indices (Sequent small) (Sequent big)
    | A.length small.ante == A.length big.ante = do
        let indexedAnte = A.zip indices big.ante
        Tuple permutation bigantes <- A.unzip <$> permute indexedAnte
        let WFF.Matches m =
                match1 (Sequent small) $ Sequent $ big { ante = bigantes }
        substitution <- m
        pure permutation
    | otherwise = []

-- Match a sequent to one after substitutions were applied and the formulas
-- lifted uniformly, returning all possible inverse permutations
-- Probably won't work with multiple antecedents and alpha equivalent quantifiers
matchLift :: forall a b c x y z i.
    Ord a => Ord b => Eq x => Ord y => Eq z => Eq i =>
    Array i -> Sequent a b c -> Sequent x y z -> Array (Array i)
matchLift indices small (Sequent big) =
    plainMatch (Sequent big) <> case big.conse of
        WFF.Unary u -> case traverse fromUnary big.ante of
            Just uantes | all ((_ == u.operator) <<< _.operator) uantes ->
                recurseMatch $
                    Sequent { ante : _.contents <$> uantes, conse : u.contents }
            _ -> []
        WFF.Binary b -> case traverse fromBinary big.ante of
            Just bantes | all
                ((_ == b.left) <<< _.left && (_ == b.operator) <<< _.operator)
                bantes ->
                    recurseMatch $
                        Sequent { ante : _.right <$> bantes, conse : b.right }
            Just bantes | all
                ((_ == b.right) <<< _.right && (_ == b.operator) <<< _.operator)
                bantes ->
                    recurseMatch $
                        Sequent { ante : _.left <$> bantes, conse : b.left }
            _ -> []
        WFF.Quant q -> case traverse fromQuant big.ante of
            Just qantes | all ((_ == q.operator) <<< _.operator) qantes ->
                recurseMatch $
                    Sequent { ante : _.contents <$> qantes, conse : q.contents }
            _ -> []
        _ -> []
    where
        plainMatch = match indices small
        recurseMatch = matchLift indices small
        fromUnary (WFF.Unary u) = Just u
        fromUnary _ = Nothing
        fromBinary (WFF.Binary b) = Just b
        fromBinary _ = Nothing
        fromQuant (WFF.Quant q) = Just q
        fromQuant _ = Nothing

verifyTypes :: forall a. Ord a => Sequent a a a -> Boolean
verifyTypes (Sequent s) =
    WFF.isWellTyped $ foldMap WFF.getTyping s.ante <> WFF.getTyping s.conse
