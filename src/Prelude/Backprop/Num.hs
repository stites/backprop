{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- |
-- Module      : Prelude.Backprop.Num
-- Copyright   : (c) Justin Le 2018
-- License     : BSD3
--
-- Maintainer  : justin@jle.im
-- Stability   : experimental
-- Portability : non-portable
--
-- Provides the exact same API as "Prelude.Backprop", except requiring
-- 'Num' instances for all types involved instead of 'Backprop' instances.
--
-- @since 0.2.0.0

module Prelude.Backprop.Num (
  -- * Foldable and Traversable
    sum
  , product
  , length
  , minimum
  , maximum
  , traverse
  -- * Functor and Applicative
  , fmap
  , (<$>)
  , pure
  , liftA2
  , liftA3
  -- * Misc
  , coerce
  ) where

import           Numeric.Backprop.Num
import           Prelude              (Num(..), Fractional(..), Eq(..), Ord(..), Functor, Foldable, Traversable, Applicative, (.), ($))
import qualified Control.Applicative  as P
import qualified Data.Coerce          as C
import qualified Data.Foldable        as P
import qualified Prelude              as P

-- | Lifted 'P.sum'
sum :: forall t a s. (Foldable t, Functor t, Num (t a), Num a, Reifies s W)
    => BVar s (t a)
    -> BVar s a
sum = liftOp1 . op1 $ \xs ->
    ( P.sum xs
    , (P.<$ xs)
    )
{-# INLINE sum #-}

-- | Lifted 'P.pure'.
pure
    :: forall t a s. (Foldable t, Applicative t, Num (t a), Num a, Reifies s W)
    => BVar s a
    -> BVar s (t a)
pure = liftOp1 . op1 $ \x ->
    ( P.pure x
    , P.sum
    )
{-# INLINE pure #-}

-- | Lifted 'P.product'
product
    :: forall t a s. (Foldable t, Functor t, Num (t a), Fractional a, Reifies s W)
    => BVar s (t a)
    -> BVar s a
product = liftOp1 . op1 $ \xs ->
    let p = P.product xs
    in ( p
       , \d -> (\x -> p * d / x) P.<$> xs
       )
{-# INLINE product #-}

-- | Lifted 'P.length'.
length
    :: forall t a b s. (Foldable t, Num (t a), Num b, Reifies s W)
    => BVar s (t a)
    -> BVar s b
length = liftOp1 . op1 $ \xs ->
    ( P.fromIntegral (P.length xs)
    , P.const 0
    )
{-# INLINE length #-}

-- | Lifted 'P.minimum'.  Undefined for situations where 'P.minimum' would
-- be undefined.
minimum
    :: forall t a s. (Foldable t, Functor t, Num a, Ord a, Num (t a), Reifies s W)
    => BVar s (t a)
    -> BVar s a
minimum = liftOp1 . op1 $ \xs ->
    let m = P.minimum xs
    in  ( m
        , \d -> (\x -> if x == m then d else 0) P.<$> xs
        )
{-# INLINE minimum #-}

-- | Lifted 'P.maximum'.  Undefined for situations where 'P.maximum' would
-- be undefined.
maximum
    :: forall t a s. (Foldable t, Functor t, Num a, Ord a, Num (t a), Reifies s W)
    => BVar s (t a)
    -> BVar s a
maximum = liftOp1 . op1 $ \xs ->
    let m = P.maximum xs
    in  ( m
        , \d -> (\x -> if x == m then d else 0) P.<$> xs
        )
{-# INLINE maximum #-}

-- | Lifted 'P.fmap'.  Lifts backpropagatable functions to be
-- backpropagatable functions on 'Traversable' 'Functor's.
fmap
    :: forall f a b s. (Traversable f, Num a, Num b, Num (f b), Reifies s W)
    => (BVar s a -> BVar s b)
    -> BVar s (f a)
    -> BVar s (f b)
fmap f = collectVar . P.fmap f . sequenceVar
{-# INLINE fmap #-}

-- | Alias for 'fmap'.
(<$>)
    :: forall f a b s. (Traversable f, Num a, Num b, Num (f b), Reifies s W)
    => (BVar s a -> BVar s b)
    -> BVar s (f a)
    -> BVar s (f b)
(<$>) = fmap
{-# INLINE (<$>) #-}

-- | Lifted 'P.traverse'.  Lifts backpropagatable functions to be
-- backpropagatable functions on 'Traversable' 'Functor's.
traverse
    :: forall t f a b s. (Traversable t, Applicative f, Foldable f, Num a, Num b, Num (f (t b)), Num (t b), Reifies s W)
    => (BVar s a -> f (BVar s b))
    -> BVar s (t a)
    -> BVar s (f (t b))
traverse f = collectVar
           . P.fmap collectVar
           . P.traverse f
           . sequenceVar
{-# INLINE traverse #-}

-- | Lifted 'P.liftA2'.  Lifts backpropagatable functions to be
-- backpropagatable functions on 'Traversable' 'Applicative's.
liftA2
    :: forall f a b c s.
       ( Traversable f
       , Applicative f
       , Num a, Num b, Num c, Num (f c)
       , Reifies s W
       )
    => (BVar s a -> BVar s b -> BVar s c)
    -> BVar s (f a)
    -> BVar s (f b)
    -> BVar s (f c)
liftA2 f x y = collectVar $ f P.<$> sequenceVar x
                              P.<*> sequenceVar y
{-# INLINE liftA2 #-}

-- | Lifted 'P.liftA3'.  Lifts backpropagatable functions to be
-- backpropagatable functions on 'Traversable' 'Applicative's.
liftA3
    :: forall f a b c d s.
       ( Traversable f
       , Applicative f
       , Num a, Num b, Num c, Num d, Num (f d)
       , Reifies s W
       )
    => (BVar s a -> BVar s b -> BVar s c -> BVar s d)
    -> BVar s (f a)
    -> BVar s (f b)
    -> BVar s (f c)
    -> BVar s (f d)
liftA3 f x y z = collectVar $ f P.<$> sequenceVar x
                                P.<*> sequenceVar y
                                P.<*> sequenceVar z
{-# INLINE liftA3 #-}

-- | Coerce items inside a 'BVar'.
coerce
    :: forall a b s. C.Coercible a b
    => BVar s a
    -> BVar s b
coerce = coerceVar
{-# INLINE coerce #-}
