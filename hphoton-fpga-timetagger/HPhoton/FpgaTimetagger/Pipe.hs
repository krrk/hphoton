module HPhoton.FpgaTimetagger.Pipe ( decodeRecordsP
                                   , module HPhoton.FpgaTimetagger
                                   ) where

import           HPhoton.FpgaTimetagger
import           Control.Proxy as P
import qualified Control.Proxy.ByteString as PBS
import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BU

-- | Decode records
decodeRecordsP :: (Monad m, Proxy p) => () -> Pipe p BS.ByteString Record m ()
decodeRecordsP = P.runIdentityK (go BS.empty) where
    go bs
        | BS.length bs < 6 = \x -> do bs' <- P.request x
                                      go (bs `BS.append` bs') x
        | otherwise = \x -> do case decodeRecord $ BU.unsafeTake 6 bs of
                                   Just r  -> P.respond r >>= go (BU.unsafeDrop 6 bs)
                                   Nothing -> go (BU.unsafeDrop 6 bs) x
    
