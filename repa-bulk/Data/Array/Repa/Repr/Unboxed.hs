
module Data.Array.Repa.Repr.Unboxed
        ( U, U.Unbox
        , Array (..)
        , fromListU
        , fromVectorU
        , toVectorU)
where
import Data.Array.Repa.Bulk.Base
import Data.Array.Repa.Bulk.Target
import Data.Array.Repa.Repr.Delayed
import Data.Array.Repa.Shape
import qualified Data.Vector.Unboxed            as U
import qualified Data.Vector.Unboxed.Mutable    as UM
import Control.Monad


---------------------------------------------------------------------------------------------------
-- | Unboxed arrays are represented as unboxed vectors.
--
--   The implementation uses @Data.Vector.Unboxed@ which is based on type
--   families and picks an efficient, specialised representation for every
--   element type. In particular, unboxed vectors of pairs are represented
--   as pairs of unboxed vectors.
--   This is the most efficient representation for numerical data.
--
data U

instance (U.Unbox a, Shape sh) => Bulk U sh a where
 data Array U sh a
        = UArray 
        { uarrayShape     :: !sh
        , uarrayVector    :: !(U.Vector a) }

 index  (UArray sh vec) ix
        | not $ inShapeRange zeroDim sh ix
        = error "repa-bulk.index[U] out of range"

        | otherwise
        = vec U.! (toIndex sh ix)

 extent arr
        = uarrayShape arr
 {-# INLINE extent #-}


deriving instance (Show sh, Show e, U.Unbox e)
        => Show (Array U sh e)

deriving instance (Read sh, Read e, U.Unbox e)
        => Read (Array U sh e)


-- Target -----------------------------------------------------------------------------------------
instance U.Unbox e => Target U e where
 data Buffer U e 
  = UBuffer (UM.IOVector e)

 unsafeNewBuffer len
  = liftM UBuffer (UM.unsafeNew len)
 {-# INLINE unsafeNewBuffer #-}

 unsafeWriteBuffer (UBuffer mvec) ix
  = UM.unsafeWrite mvec ix
 {-# INLINE unsafeWriteBuffer #-}

 unsafeSliceBuffer start len (UBuffer mvec)
  = do  let mvec'  = UM.unsafeSlice start len mvec
        return  $  UBuffer mvec'
 {-# INLINE unsafeSliceBuffer #-}

 unsafeFreezeBuffer sh (UBuffer mvec)     
  = do  vec     <- U.unsafeFreeze mvec
        return  $  UArray sh vec
 {-# INLINE unsafeFreezeBuffer #-}

 touchBuffer _ 
  = return ()
 {-# INLINE touchBuffer #-}


-- Conversions ------------------------------------------------------------------------------------
-- | O(n). Convert a list to an unboxed vector array.
-- 
--   * This is an alias for `fromList` with a more specific type.
--
fromListU
        :: (Shape sh, U.Unbox a)
        => sh -> [a] -> Maybe (Array U sh a)
fromListU = fromList
{-# INLINE [1] fromListU #-}


-- | O(1). Wrap an unboxed vector as an array.
fromVectorU
        :: (Shape sh, U.Unbox e)
        => sh -> U.Vector e -> Array U sh e
fromVectorU sh vec
        = UArray sh vec
{-# INLINE [1] fromVectorU #-}


-- | O(1). Unpack an unboxed vector from an array.
toVectorU
        :: U.Unbox e
        => Array U sh e -> U.Vector e
toVectorU (UArray _ vec)
        = vec
{-# INLINE [1] toVectorU #-}


