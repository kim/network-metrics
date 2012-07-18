-- |
-- Module      : Network.Metrics.Statsd
-- Copyright   : (c) 2012 Brendan Hay <brendan@soundcloud.com>
-- License     : This Source Code Form is subject to the terms of
--               the Mozilla Public License, v. 2.0.
--               A copy of the MPL can be found in the LICENSE file or
--               you can obtain it at http://mozilla.org/MPL/2.0/.
-- Maintainer  : Brendan Hay <brendan@soundcloud.com>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--

module Network.Metrics.Statsd (
    -- * Sink Functions
      open
    , MetricSink(push, close)

    -- * Re-exports
    , Group
    , Bucket
    , Value
    , MetricType(..)
    , Metric(..)
    ) where

import Control.Monad  (liftM)
import Network.Socket (SocketType(..))
import System.Random  (randomRIO)
import Network.Metrics.Internal

import qualified Data.ByteString.Char8      as BS
import qualified Data.ByteString.Lazy.Char8 as BL

-- | An internal record used to describe a Statsd metric
data StatsdMetric = StatsdMetric
    { type'  :: MetricType
    , bucket :: BS.ByteString
    , value  :: BS.ByteString
    , rate   :: Double
    } deriving (Show)

-- | The sample status of a metric
data Sampled = Sampled | Exact | Ignore

-- | A handle to a Statsd sink
data Statsd = Statsd Handle deriving (Show)

instance MetricSink Statsd where
    push m (Statsd h) = encode m >>= flip hPush h
    close  (Statsd h) = hClose h

--
-- API
--

-- | Open a new Statsd sink
open :: String -> String -> IO Sink
open host port = liftM (Sink . Statsd) (hOpen Datagram host port)

--
-- Private
--

-- | Encode a metric into the Statsd format
encode :: Metric -> IO BL.ByteString
encode (Metric t g b v) = liftM bstr (randomRIO (0.0, 1.0))
  where
    metric = StatsdMetric t (BS.concat [g, ".", b]) v 1.0
    bstr   = BL.fromChunks . chunks metric . sample (rate metric)

sample :: Double -> Double -> Sampled
sample rate rand | rate < 1.0 && rand <= rate = Sampled
                 | rate == 1.0                = Exact
                 | otherwise                  = Ignore

chunks :: StatsdMetric -> Sampled -> [BS.ByteString]
chunks StatsdMetric{..} sampled = case sampled of
    Sampled -> base ++ ["@", BS.pack $ show rate]
    Exact   -> base
    Ignore  -> []
  where
    base = [bucket, ":", value, "|", suffix type']

suffix :: MetricType -> BS.ByteString
suffix typ = case typ of
    Counter -> "c"
    Gauge   -> "g"
    Timer   -> "ms"
