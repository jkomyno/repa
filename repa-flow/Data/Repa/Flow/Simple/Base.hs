
module Data.Repa.Flow.Simple.Base
        ( Source, Sink
        , finalize_i
        , finalize_o
        , wrapI_i
        , wrapI_o)
where
import Data.Repa.Flow.States
import qualified Data.Repa.Flow.Generic as G

-- | Source consisting of a single stream.
type Source m e = G.Sources () m e

-- | Sink consisting of a single stream.
type Sink   m e = G.Sinks   () m e


-- Finalizers -----------------------------------------------------------------
-- | Attach a finalizer to a source.
--
--   The finalizer will be called the first time a consumer of that stream
--   tries to pull an element when no more are available.
--
--   The provided finalizer will be run after any finalizers already
--   attached to the source.
--
finalize_i
        :: States () m
        => m ()
        -> Source m a -> m (Source m a)

finalize_i f s0 = G.finalize_i (\_ -> f) s0
{-# INLINE [2] finalize_i #-}


-- | Attach a finalizer to a sink.
--
--   The finalizer will be called the first time the stream is ejected.
--
--   The provided finalizer will be run after any finalizers already
--   attached to the sink.
--
finalize_o
        :: States () m
        => m ()
        -> Sink m a -> m (Sink m a)

finalize_o f s0 = G.finalize_o (\_ -> f) s0
{-# INLINE [2] finalize_o #-}


-- Wrapping -------------------------------------------------------------------
wrapI_i  :: G.Sources Int m e -> Maybe (Source m e)
wrapI_i (G.Sources n pullX)
 | n /= 1       = Nothing
 | otherwise    
 = let  pullX' _ eat eject 
         = pullX (G.IIx 0 1) eat eject 
   in   Just $ G.Sources () pullX'
{-# INLINE wrapI_i #-}


wrapI_o  :: G.Sinks Int m e -> Maybe (Sink m e)
wrapI_o (G.Sinks n eatX ejectX)
 | n /= 1       = Nothing
 | otherwise    
 = let  eatX' _ x       = eatX   (G.IIx 0 1) x
        ejectX' _       = ejectX (G.IIx 0 1)
   in   Just $ G.Sinks () eatX' ejectX'
{-# INLINE wrapI_o #-}
