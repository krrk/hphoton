module HPhoton.Utils ( zeroTime
                     , zeroTimes
                     , timesToInterarrivals
                     , combineChannels
                     , spansPhotons
                     ) where

import qualified Data.Vector.Unboxed as V
import Data.Vector.Algorithms.Merge (sort)
import Control.Monad.Trans.State
import HPhoton.Types

-- | Find the earliest time of a set of photon arrival times
zeroTime :: [V.Vector Time] -> Time
zeroTime = minimum . map V.head

-- | Offset a set of arrival times such that the first photon arrives at t=0
zeroTimes :: [V.Vector Time] -> [V.Vector Time]
zeroTimes times = map (V.map (\t->t-zeroTime times)) times

-- | Map a list of arrival times to the corresponding interarrival times
timesToInterarrivals :: V.Vector Time -> V.Vector TimeDelta
timesToInterarrivals times = V.zipWith (-) (V.tail times) times

-- | Combine multiple timestamp channels
combineChannels :: [V.Vector Time] -> IO (V.Vector Time)
combineChannels chs = do stamps <- V.thaw $ V.concat chs
                         sort stamps
                         stamps' <- V.freeze stamps
                         return stamps'

-- | 'spansPhotons ts spans' returns the photons in a set of spans
spansPhotons :: V.Vector Time -> [(Time,Time)] -> [V.Vector Time]
spansPhotons ts spans = evalState (mapM f spans) ts
  where f :: (Time,Time) -> State (V.Vector Time) (V.Vector Time)
        f (start,end) = do ts <- get
                           let (a,b) = V.span (<=end) $ V.dropWhile (<start) ts
                           put b
                           return a