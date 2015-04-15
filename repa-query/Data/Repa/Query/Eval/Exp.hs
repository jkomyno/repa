

module Data.Repa.Query.Eval.Exp
        ( Env (..)
        , ExpEnv
        , ValEnv
        , evalExp)
where
import Data.Repa.Query.Exp
import Control.Monad
import Prelude hiding (lookup)


class Env env v where
 data Bind  env  
 data Bound env
 lookup         :: env v -> Bound env -> Maybe v
 insert         :: env v -> Bind  env -> v -> env v


-- | An expression closed by the given environment type.
type ExpEnv a env
        = Exp a (Bind env) (Bound env)


-- | A value closed by the given environment type.
type ValEnv a env
        = Val a (Bind env) (Bound env)



-- | Evaluate an expression in some environment.
evalExp :: Env env (ValEnv a env)
        => env     (ValEnv a env)
        -> ExpEnv a env
        -> Maybe   (ValEnv a env)

evalExp env xx
 = case xx of
        XVal _ val      
         -> Just val

        XVar _ bound
         -> case lookup env bound of 
                Nothing         -> Nothing
                Just val        -> Just val

        XApp _ (XVal _ (VLam _ bV xBody)) (XVal _ val)
         ->     evalExp (insert env bV val) xBody

        XApp a xFun@(XVal _ VLam{}) xArg
         -> do  xArg'    <- evalExp env xArg
                let aArg =  annotOfExp xArg
                evalExp env (XApp a xFun (XVal aArg xArg'))

        XApp a xFun xArg
         -> do  xFun'    <- evalExp env xFun
                let aFun =  annotOfExp xFun
                evalExp env (XApp a (XVal aFun xFun') xArg)

        XOp a sop xsArgs
         -> do  vsArgs   <- sequence $ map (evalExp env) xsArgs
                lsArgs   <- sequence $ map (liftM snd . takeVLit) vsArgs
                lResult  <- evalScalarOp sop lsArgs
                return $ VLit a lResult


-- | Evaluate a primitive scalar operator applied to its arguments.
evalScalarOp 
        :: ScalarOp 
        -> [Lit] 
        -> Maybe Lit

evalScalarOp sop args
 = case (sop, args) of

        -- Integer
        (SopNeg, [LInt i])              -> Just $ LInt  (negate i)

        (SopAdd, [LInt i1, LInt i2])    -> Just $ LInt  (i1 +     i2)
        (SopSub, [LInt i1, LInt i2])    -> Just $ LInt  (i1 -     i2)
        (SopMul, [LInt i1, LInt i2])    -> Just $ LInt  (i1 *     i2)
        (SopDiv, [LInt i1, LInt i2])    -> Just $ LInt  (i1 `div` i2)

        (SopEq,  [LInt i1, LInt i2])    -> Just $ LBool (i1 == i2)
        (SopNeq, [LInt i1, LInt i2])    -> Just $ LBool (i1 /= i2)
        (SopGt,  [LInt i1, LInt i2])    -> Just $ LBool (i1 >  i2)
        (SopGe,  [LInt i1, LInt i2])    -> Just $ LBool (i1 >= i2)
        (SopLt,  [LInt i1, LInt i2])    -> Just $ LBool (i1 <  i2)
        (SopLe,  [LInt i1, LInt i2])    -> Just $ LBool (i1 <= i2)

        _                               -> Nothing

