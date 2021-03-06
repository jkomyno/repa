
module Data.Array.Repa.Vector.Compute.Load
        ( Load      (..)
        , LoadRange (..))
where
import Data.Array.Repa.Vector.Compute.Target
import Data.Array.Repa.Vector.Shape
import Data.Array.Repa.Vector.Base
import Data.Array.Repa.Vector.Operators.Bulk    ()


-- Load -----------------------------------------------------------------------
-- | Compute all elements defined by an array and write them to a manifest
--   target representation.
--
--   In general this class only has instances for source array representations
--   that support random access indexing (ie `Bulk` representations)
--  
class Shape sh => Load r1 sh e where

 -- | Fill an entire array sequentially.
 loadS          :: Target r2 e => Array r1 sh e -> MVec r2 e -> IO ()

 -- | Fill an entire array in parallel.
 loadP          :: Target r2 e => Array r1 sh e -> MVec r2 e -> IO ()


-- FillRange ------------------------------------------------------------------
-- | Compute a range of elements defined by an array and write them to a fillable
--   representation.
--
--   In general this class only has instances for source array representations
--   that support random access indexing (ie `Bulk` representations)
--
class Shape sh => LoadRange r1 sh e where

 -- | Fill a range of an array sequentially.
 loadRangeS     :: Target r2 e => Array r1 sh e -> MVec r2 e -> sh -> sh -> IO ()

 -- | Fill a range of an array in parallel.
 loadRangeP     :: Target r2 e => Array r1 sh e -> MVec r2 e -> sh -> sh -> IO ()


                        
