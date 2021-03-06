{-# LANGUAGE GeneralizedNewtypeDeriving, TypeFamilies, FlexibleInstances #-}

module Analyses.BigStep.ConcreteT where

import Data.PartialOrder
import Data.Lattice
import StateSpace.Semantics
import Analyses.BigStep.AnalysisT
import Control.Monad
import Control.Monad.Identity
import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Trans
import Fixpoints.Y
import Monads
import StateSpace
import Util.ExtTB
import Util.MFunctor
import qualified Data.Map as Map

newtype ConcreteT var val m a = ConcreteT
  { unConcreteT :: AnalysisT Integer Integer ExtTB var val (DiscreteT m) a }
  deriving
  ( Monad
  , MonadPlus
  , MonadState s
  , MonadReader r
  , MonadEnvReader (Env var Integer)
  , MonadStoreState (Store ExtTB Integer val)
  , MonadTimeState Integer
  , MMorph ExtTB
  )

mkConcreteT :: 
  (Monad m)
  => (Env var Integer
      -> Store ExtTB Integer val 
      -> Integer 
      -> m (ExtTB (a, Store ExtTB Integer val, Integer))
     )
  -> ConcreteT var val m a
mkConcreteT f = 
  ConcreteT $
  mkAnalysisT $ \ env store time ->
  mkDiscreteT $
  f env store time

runConcreteT :: 
  (Monad m) 
  => ConcreteT var val m a
  -> Env var Integer 
  -> Store ExtTB Integer val 
  -> Integer 
  -> m (ExtTB (a, Store ExtTB Integer val, Integer))
runConcreteT aM env store time =
  runDiscreteT 
  $ (\x -> runAnalysisT x env store time)
  $ unConcreteT aM

instance MonadTrans (ConcreteT var val) where
  lift = ConcreteT . lift . lift

instance MFunctor (ConcreteT var val) where
  mFmap f aMT = mkConcreteT $ \ env store time ->
    f $ runConcreteT aMT env store time

instance (Ord var, Ord val) => BigStep (ConcreteT var val) where
  newtype InBS (ConcreteT var val) a = ConcreteInBS 
    { unConcreteInBS :: (a, Env var Integer, Store ExtTB Integer val, Integer) }
  newtype OutBS (ConcreteT var val) a = ConcreteOutBS
    { unConcreteOutBS :: ExtTB (a, Store ExtTB Integer val, Integer) }
  askInBS e = do
    env <- askEnv
    store <- getStore
    time <- getTime
    return $ ConcreteInBS (e, env, store, time)
  runBS run (ConcreteInBS (e, env, store, time)) = 
    liftM ConcreteOutBS $ runConcreteT (run e) env store time

instance Inject (InBS (ConcreteT var val)) where
  inject a = ConcreteInBS (a, Map.empty, Map.empty, 0)
