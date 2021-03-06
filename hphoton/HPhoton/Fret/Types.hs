module HPhoton.Fret.Types ( FretChannel(..)
                          , Fret(..)
                          , getFretChannel
                          -- * Useful type synonyms
                          , FretEff, ProxRatio
                          , Gamma, Crosstalk
                          ) where

import Data.Foldable
import Data.Monoid
import Data.Traversable
import Control.Applicative
import Control.DeepSeq

type FretEff = Double
type ProxRatio = Double
type Gamma = Double

-- | The crosstalk parameter
-- .
-- defined as the ratio of intensities @Ia / Id@ for emissions from a
-- donor dye
type Crosstalk = Double

data FretChannel = Donor | Acceptor deriving (Show, Eq)

data Fret a = Fret { fretA, fretD :: !a } deriving (Show, Eq)

instance NFData a => NFData (Fret a) where
  rnf (Fret x y) = rnf x `seq` rnf y

instance Functor Fret where
  fmap f (Fret x y) = Fret (f x) (f y)

instance Foldable Fret where
  foldMap f (Fret x y) = f x <> f y

instance Applicative Fret where
  pure x = Fret x x
  (Fret a b) <*> (Fret x y) = Fret (a x) (b y)

instance Traversable Fret where
  traverse f (Fret x y) = Fret <$> f x <*> f y

instance Monoid a => Monoid (Fret a) where
  mempty = pure mempty
  a `mappend` b = mappend <$> a <*> b

getFretChannel :: Fret a -> FretChannel -> a
getFretChannel f Donor    = fretD f
getFretChannel f Acceptor = fretA f
