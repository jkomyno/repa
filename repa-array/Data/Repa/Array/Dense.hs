{-# LANGUAGE UndecidableInstances #-}
module Data.Repa.Array.Dense
        ( E      (..)
        , Name   (..)
        , Array  (..)
        , Buffer (..)

        -- * Common layouts)
        , vector
        , matrix
        , cube)
where
import Data.Repa.Array.Index
import Data.Repa.Array.RowWise
import Data.Repa.Array.Internals.Bulk
import Data.Repa.Array.Internals.Target
import Data.Repa.Fusion.Unpack
import Prelude                                  as P


-- | The Dense layout maps a higher-ranked index space to some underlying
--   linear index space.
--
--   For example, we can create a dense 2D row-wise array where the elements are
--   stored in a flat unboxed vector:
--
-- @
-- > let Just arr  = fromList (matrix U 10 10) [1000..1099 :: Float]
-- > :type arr
--   arr :: Array (E U (RW DIM2) Float
--
-- > arr ! (Z :. 5 :. 4)
-- > 1054.0 
-- @
--
data E r l 
        = Dense r l

deriving instance (Eq   r, Eq   l) => Eq   (E r l)
deriving instance (Show r, Show l) => Show (E r l)


-------------------------------------------------------------------------------
-- The elements of Flat arrays are stored in row-wise order.
instance (Index r ~ Int, Layout r, Layout l)
      =>  Layout (E r l) where

        data Name  (E r l)              = E (Name r) (Name l)
        type Index (E r l)              = Index     l

        create     (E nR nL) ix        
         = Dense (create nR (size ix)) (create nL ix)

        extent     (Dense _ l)          = extent    l
        toIndex    (Dense _ l) ix       = toIndex   l ix
        fromIndex  (Dense _ l) n        = fromIndex l n
        {-# INLINE create    #-}
        {-# INLINE extent    #-}
        {-# INLINE toIndex   #-}
        {-# INLINE fromIndex #-}


-------------------------------------------------------------------------------
-- The elements of Flat arrays are stored in some 
-- underlying linear representation.
instance (Index r ~ Int, Layout l, Bulk r a)
      =>  Bulk (E r l) a where
        
        data Array (E r l) a            = Array l (Array r a)
        layout (Array l inner)          = Dense (layout inner) l
        index  (Array l inner) ix       = index inner (toIndex l ix)
        {-# INLINE layout #-}
        {-# INLINE index  #-}


-- When constructing flat arrays we use the same buffer
-- type as the underlying linear representation.
instance (Index r ~ Int, Layout l, Target r a)
      =>  Target (E r l) a where

        data Buffer (E r l) a
                = EBuffer l (Buffer r a)

        unsafeNewBuffer   (Dense r l)   
         = do   buf     <- unsafeNewBuffer r
                return  $ EBuffer l buf

        unsafeWriteBuffer  (EBuffer _ buf) ix x     
                = unsafeWriteBuffer buf ix x

        unsafeGrowBuffer   (EBuffer l buf) ix       
         = do   buf'    <- unsafeGrowBuffer  buf ix
                return  $ EBuffer l buf'

        unsafeSliceBuffer  _st _sz _buf
                = error "repa-array: dense sliceBuffer, can't window inner"

        unsafeFreezeBuffer (EBuffer l buf)
         = do   inner   <- unsafeFreezeBuffer buf
                return  $ Array l inner

        touchBuffer (EBuffer _ buf)  = touchBuffer buf
        {-# INLINE unsafeNewBuffer    #-}
        {-# INLINE unsafeWriteBuffer  #-}
        {-# INLINE unsafeGrowBuffer   #-}
        {-# INLINE unsafeSliceBuffer  #-}
        {-# INLINE unsafeFreezeBuffer #-}
        {-# INLINE touchBuffer        #-}


instance Unpack (Buffer r a) tBuf
      => Unpack (Buffer (E r l) a) (l, tBuf) where

 unpack (EBuffer l buf)             = (l, unpack buf)
 repack (EBuffer _ buf) (l, ubuf)   = EBuffer l (repack buf ubuf)
 {-# INLINE unpack #-}
 {-# INLINE repack #-}


-------------------------------------------------------------------------------
-- | Yield a layout for a dense vector of the given length.
--
--   The first argument is the name of the underlying linear layout
--   which stores the elements.
vector  :: (Layout l, Index l ~ Int)
        => Name l -> Int -> E l DIM1
vector n len            
        = create (E n (RC RZ)) (Z :. len)


-- | Yield a layout for a matrix with the given number of
--   rows and columns.
matrix  :: (Layout l, Index l ~ Int)
        => Name l -> Int -> Int -> E l DIM2
matrix n rows cols
        = create (E n (RC (RC RZ))) (Z :. rows :. cols)


-- | Yield a layout for a cube with the given number of
--   planes, rows, and columns.
cube    :: (Layout l, Index l ~ Int)
        => Name l -> Int -> Int -> Int -> E l DIM3
cube n planes rows cols
        = create (E n (RC (RC (RC RZ)))) (Z :. planes :. rows :. cols)
