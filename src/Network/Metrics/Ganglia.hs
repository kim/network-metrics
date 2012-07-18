-- |
-- Module      : Network.Metrics.Ganglia
-- Copyright   : (c) 2012 Brendan Hay <brendan@soundcloud.com>
-- License     : This Source Code Form is subject to the terms of
--               the Mozilla Public License, v. 2.0.
--               A copy of the MPL can be found in the LICENSE file or
--               you can obtain it at http://mozilla.org/MPL/2.0/.
-- Maintainer  : Brendan Hay <brendan@soundcloud.com>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--

module Network.Metrics.Ganglia (
    -- * Exported Types
      Slope(..)
    , GangliaType(..)
    , GangliaMetric(..)
    , Ganglia(..)

    -- * Defaults
    , defaultMetric

    -- * Binary Encoding
    , putMetaData
    , putValue

    -- * Sink Functions
    , open
    , MetricSink(push, close)

    -- * Re-exports
    , Group
    , Bucket
    , Value
    , MetricType(..)
    , Metric(..)
    ) where

import Control.Monad            (liftM)
import Data.Binary.Put
import Data.Bits                ((.&.))
import Data.Char                (toLower)
import Data.Data                (Data, Typeable)
import Data.Default             (Default, def)
import Data.Int                 (Int32)
import Data.Word                (Word32)
import Network.Socket           (SocketType(..))
import Network.Metrics.Internal

import qualified Data.ByteString            as B
import qualified Data.ByteString.Char8      as BS
import qualified Data.ByteString.Lazy.Char8 as BL

-- | Allows gmetad and the PHP webfrontend to efficiently separate
-- constant data metrics from volatile ones
data Slope = Zero | Positive | Negative | Both | Unspecified
      deriving (Data, Typeable, Show, Eq, Enum)

-- | Metric types supported by Ganglia
data GangliaType = String | Int8 | UInt8 | Int16 | UInt16 | Int32 | UInt32 | Float | Double
      deriving (Data, Typeable, Eq, Show)

-- | Concrete metric type used to emit metadata and value packets
data GangliaMetric = GangliaMetric
    { name  :: BS.ByteString
    , type' :: GangliaType
    , units :: BS.ByteString
    , value :: BS.ByteString
    , host  :: BS.ByteString
    , spoof :: BS.ByteString
    , group :: BS.ByteString
    , slope :: Slope
    , tmax  :: Word32
    , dmax  :: Word32
    } deriving (Show)

instance Default GangliaMetric where
    def = defaultMetric

-- | A handle to a Ganglia sink
data Ganglia = Ganglia Handle deriving (Show)

instance MetricSink Ganglia where
    push m (Ganglia h) = hPush (encode m) h
    close  (Ganglia h) = hClose h

--
-- API
--

-- | Sensible defaults for a GangliaMetric
defaultMetric :: GangliaMetric
defaultMetric = GangliaMetric
    { name  = ""
    , type' = Int32
    , units = ""
    , value = ""
    , host  = ""
    , spoof = ""
    , group = ""
    , slope = Both
    , tmax  = 60
    , dmax  = 0
    }

-- | Open a new Ganglia sink
open :: String -> String -> IO Sink
open host port = liftM (Sink . Ganglia) (hOpen Datagram host port)

-- | Encode a GangliaMetric's metadata into a Binary.Put monad
--
-- The format for this can be found in either:
-- * gm_protocol.x in the Ganglia 3.1 sources
-- * https://github.com/lookfirst/jmxtrans
putMetaData :: GangliaMetric -> Put
putMetaData m@GangliaMetric{..} = do
    putHeader 128 m -- 128 = metadata_msg
    putType type'
    putString name
    putString units
    putEnum slope
    putUInt tmax
    putUInt dmax
    putGroup group

-- | Encode a GangliaMetric's value into a Binary.Put monad
putValue :: GangliaMetric -> Put
putValue m@GangliaMetric{..} = do
    putHeader 133 m -- 133 = string_msg
    putString "%s"
    putString value

--
-- Private
--

-- TODO: enforce max buffer size length checks.
-- Magic number is per libgmond.c
bufferSize :: Integer
bufferSize = 1500

-- | Encode a metric into the Ganglia format
encode :: Metric -> BL.ByteString
encode (Metric t g b v) = BL.concat $ map put [putMetaData, putValue]
  where
    slope' = case t of
        Counter -> Positive
        _       -> Both
    metric = defaultMetric { name  = b, group = g, value = v, slope = slope' }
    put f  = runPut $ f metric

-- | Common headers for the metadata and value
putHeader :: Int32 -> GangliaMetric -> Put
putHeader code GangliaMetric{..} = do
    putInt code
    putString host
    putString name
    putString spoof

-- | Encode either a end of message delimiter or
-- an extra group field (Ganglia 3.1 only)
putGroup :: BS.ByteString -> Put
putGroup group | BS.null group = putInt 0
               | otherwise     = do
                     putInt 1
                     putString "GROUP"
                     putString group

putInt :: Int32 -> Put
putInt = putWord32be . fromIntegral

putUInt :: Word32 -> Put
putUInt = putWord32be

putEnum :: Enum a => a -> Put
putEnum = putInt . fromIntegral . fromEnum

putString :: BS.ByteString -> Put
putString bstr = do
    putInt $ fromIntegral len
    putByteString bstr
    case fromIntegral len .&. 3 of
        0 -> return ()
        m -> putByteString $ B.replicate (4 - m) 0
  where
    len = BS.length bstr

putType :: GangliaType -> Put
putType = putString . BS.pack . map toLower . show
