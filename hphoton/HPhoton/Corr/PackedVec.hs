{-# LANGUAGE BangPatterns     #-}
{-# LANGUAGE FlexibleContexts #-}

module HPhoton.Corr.PackedVec ( Time
                              , PackedVec (PVec)
                              , packedVec, packedVec'
                              , index
                              , shiftVec
                              , map
                              , dot
                              , izipWith
                              ) where

import           Control.Monad.ST
import           Data.Function               (on)
import qualified Data.Vector.Algorithms.Heap as VA
import qualified Data.Vector.Unboxed         as V
import qualified Data.Vector.Generic         as G
import Data.Vector.Fusion.Stream.Monadic (Step(..), Stream(..))
import Data.Vector.Fusion.Stream.Size
import qualified Data.Vector.Fusion.Stream as S
import           HPhoton.Types
import           Prelude                     hiding (map)

-- | An unboxed sparse vector
newtype PackedVec i v = PVec (V.Vector (i,v))
                      deriving (Show, Eq)

-- | Construct a PackedVec, ensuring that the entries are sorted.
packedVec :: (Ord i, V.Unbox i, V.Unbox v) => V.Vector (i,v) -> PackedVec i v
packedVec v = PVec $ runST $ do
                  v' <- V.thaw v
                  VA.sortBy (compare `on` fst) v'
                  V.freeze v'
{-# INLINE packedVec #-}

-- | Construct a PackedVec assuming that the entries are already sorted.
packedVec' :: (V.Unbox i, V.Unbox v) => V.Vector (i,v) -> PackedVec i v
packedVec' = PVec

izipWith :: (Ord i, V.Unbox i, V.Unbox a, V.Unbox b, V.Unbox c)
         => (i -> a -> b -> c)
         -> PackedVec i a -> PackedVec i b -> PackedVec i c
izipWith f (PVec as) (PVec bs) =
    PVec $ G.unstream $ izipStreamsWith f (G.stream as) (G.stream bs)
{-# INLINE izipWith #-}

data ZipState sa sb i a b
    = ZipStart sa sb
    | ZipAdvanceL sa sb i a
    | ZipAdvanceR sa sb i b

izipStreamsWith
    :: (Monad m, Ord i)
    => (i -> a -> b -> c)
    -> Stream m (i,a) -> Stream m (i,b) -> Stream m (i,c)
izipStreamsWith f (Stream stepa sa0 na) (Stream stepb sb0 nb) =
    Stream step (ZipStart sa0 sb0) (smaller na nb)
  where
    step (ZipStart sa sb) = do
      r <- stepa sa
      return $ case r of 
        Yield (vi, va) sa' -> Skip (ZipAdvanceR sa' sb vi va)
        Skip sa'           -> Skip (ZipStart sa' sb)
        Done               -> Done
    step (ZipAdvanceR sa sb ia va) = do
      r <- stepb sb
      return $ case r of
        Yield (ib, vb) sb' -> go sa sb' ia va ib vb
        Skip sb'           -> Skip (ZipAdvanceR sa sb' ia va)
        Done               -> Done
    step (ZipAdvanceL sa sb ib vb) = do
      r <- stepa sa
      return $ case r of
        Yield (ia, va) sa' -> go sa' sb ia va ib vb
        Skip sa'           -> Skip (ZipAdvanceL sa' sb ib vb)
        Done               -> Done
    {-# INLINE [0] step #-}

    go sa sb ia va ib vb =
      case compare ia ib of
        LT   -> Skip (ZipAdvanceL sa sb ib vb)
        EQ   -> Yield (ia, f ia va vb) (ZipStart sa sb)
        GT   -> Skip (ZipAdvanceR sa sb ia va)
    {-# INLINE [0] go #-}
{-# INLINE [1] izipStreamsWith #-}

dotStream' :: (Ord i, Eq i, Num v, V.Unbox i, V.Unbox v)
     => V.Vector (i,v) -> V.Vector (i,v) -> v
dotStream' as bs =
    S.foldl' (+) 0 $ S.map snd $ izipStreamsWith (const (*)) (G.stream as) (G.stream bs)
{-# INLINE dotStream' #-}

-- | Sparse vector dot product
dot :: (Ord i, Num v, V.Unbox i, V.Unbox v)
    => PackedVec i v -> PackedVec i v -> v
dot (PVec as) (PVec bs) = dotStream' as bs
{-# INLINE dot #-}

-- | Fetch element i
index :: (Eq i, Num v, V.Unbox i, V.Unbox v) => PackedVec i v -> i -> v
index (PVec v) i =
    case V.find (\(x,_)->x==i) v of
        Just (x,y) -> y
        Nothing    -> 0
{-# INLINE index #-}

-- | Shift the abscissas in a sparse vector
shiftVec :: (Num i, V.Unbox i, V.Unbox v) => i -> PackedVec i v -> PackedVec i v
shiftVec shift (PVec v) = PVec $ V.map (\(a,o)->(a+shift, o)) v
{-# INLINE shiftVec #-}

-- | Zero elements until index i
dropUntil :: (Ord i, V.Unbox i, V.Unbox v) => i -> PackedVec i v -> PackedVec i v
dropUntil i (PVec v) = PVec $ V.dropWhile (\(a,o)->a < i) v
{-# INLINE dropUntil #-}

-- | Zero elements after index i
takeUntil :: (Ord i, V.Unbox i, V.Unbox v) => i -> PackedVec i v -> PackedVec i v
takeUntil i (PVec v) = PVec $ V.takeWhile (\(a,o)->a < i) v
{-# INLINE takeUntil #-}

-- | Map operation
-- Note that this will only map non-zero entries
map :: (V.Unbox i, V.Unbox v, V.Unbox v') => (v -> v') -> PackedVec i v -> PackedVec i v'
map f (PVec v) = PVec $ V.map (\(x,y)->(x, f y)) v
{-# INLINE map #-}

