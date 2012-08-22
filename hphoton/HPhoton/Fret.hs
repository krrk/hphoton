module HPhoton.Fret ( fretEfficiency
                    , proximityRatio
                    , gammaFromFret
                    , flipFrets
                    , module HPhoton.Fret.Types
                    ) where

import HPhoton.Fret.Types
  
-- | `fretEfficiency gamma fret` is the gamma-corrected FRET efficiency
-- for acceptor/donor intensities `fret`
fretEfficiency :: Gamma -> Fret Double -> FretEff
fretEfficiency gamma x = fretA x / (fretA x + fretD x)

-- | `proximityRatio fret` is the proximity ratio for acceptor/donor
-- intensities `fret`
proximityRatio :: Fret Double -> ProxRatio
proximityRatio = fretEfficiency 1
          
-- | `gammaFromFret proxRatio fretEff` is the gamma such that
-- `proxRatio` is shifted to `fretEff`
gammaFromFret :: ProxRatio -> FretEff -> Gamma
gammaFromFret proxRatio fretEff = (1/fretEff - 1) / (1/proxRatio - 1)

-- | Turn a 'Fret' of lists into a list of 'Fret's
-- TODO: Should/could this somehow be done with Traversable?
flipFrets :: Fret [a] -> [Fret a]
flipFrets (Fret a b) = zipWith Fret a b
