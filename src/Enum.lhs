\section{Enum}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE TypeOperators, GADTs, KindSignatures,
>     TypeSynonymInstances, FlexibleInstances, ScopedTypeVariables #-}

> module Enum where

%endif

\question{Do the Formation/Introduction/\ldots names make sense?}

Formation rule:

\begin{prooftree}
\AxiomC{}
\RightLabel{EnumU-formation}
\UnaryInfC{|Set :>: EnumU|}
\end{prooftree}

\begin{prooftree}
\AxiomC{|EnumU :>: e|}
\RightLabel{EnumT-formation}
\UnaryInfC{|Set :>: EnumT e|}
\end{prooftree}

Introduction rules:

\begin{prooftree}
\AxiomC{}
\RightLabel{NilE-intro-1}
\UnaryInfC{|EnumU :>: NilE|}
\end{prooftree}

\begin{prooftree}
\AxiomC{|UId :>: t|}
\AxiomC{|EnumU :>: e|}
\RightLabel{ConsE-Intro-1}
\BinaryInfC{|EnumU :>: ConsE t e|}
\end{prooftree}

\begin{prooftree}
\AxiomC{}
\RightLabel{Ze-intro-1}
\UnaryInfC{|EnumT (ConsE t e) :>: Ze|}
\end{prooftree}

\begin{prooftree}
\AxiomC{|EnumT e :>: n|}
\RightLabel{Su-intro-1}
\UnaryInfC{|EnumT (ConsE t e) :>: Su n|}
\end{prooftree}

Elimination rules:

\begin{prooftree}
\AxiomC{|EnumU :>: e|}
\AxiomC{|EnumT e -> Set :>: P|}
\RightLabel{branches-elim}
\BinaryInfC{|Set :>: branches(e,P)|}
\end{prooftree}

With the following computational behavior:

< branches NilE _ :-> Unit
< branches (ConsE t e') P :-> (p Ze , \x -> branches (e', P (Su x)))

\begin{prooftree}
\AxiomC{|EnumU :>: e|}
\noLine
\UnaryInfC{|EnumT e -> Set :>: P|}
\AxiomC{|branches(e,P) :>: b|}
\noLine
\UnaryInfC{|EnumT e :>: x|}
\RightLabel{switch-elim}
\BinaryInfC{|P x :>: switch(e,P,b,x)|}
\end{prooftree}

With the following computational behavior:

< switch (ConsE t e') P ps Ze :-> fst ps
< switch (ConsE t e') P ps (Su n) :-> switch(e', \x -> P (Su x), snd ps, n)

Equality rules:

< eqGreen(EnumU, NilE, EnumU, NilE) :-> Trivial
< eqGreen(EnumU, ConsE t1 e1, EnumU, ConsE t2 e2) :->
<     And (eqGreen(UId, t1, UId, t2))
<         (eqGreen(EnumU, e1, EnumU, e2))
< eqGreen(EnumT (ConsE _ e1), Ze, EnumT (ConsE _ e2), Ze) :-> Trivial
< eqGreen(EnumT (ConsE _ e1), Su n1, EnumT (ConsE _ e2), Su n2) :->
<     eqGreen(EnumT e1, n1, EnumT e2, n2)


> import -> CanConstructors where
>   EnumU  :: Can t
>   EnumT  :: t -> Can t
>   NilE   :: Can t
>   ConsE  :: t -> t -> Can t
>   Ze     :: Can t
>   Su     :: t -> Can t 

> import -> CanPats where
>   pattern ENUMU      = C EnumU 
>   pattern ENUMT e    = C (EnumT e) 
>   pattern NILE       = C NilE
>   pattern CONSE t e  = C (ConsE t e) 
>   pattern ZE         = C Ze
>   pattern SU n       = C (Su n)

> import -> SugarTactics where
>   enumUTac = can EnumU
>   enumTTac t = can $ EnumT t
>   nilETac = can NilE
>   consETac e t = can $ ConsE e t
>   zeTac = can Ze
>   suTac t = can $ Su t

> import -> CanCompile where
>   makeBody Ze = CTag 0
>   makeBody (Su x) = STag (makeBody x)

> import -> TraverseCan where
>   traverse f EnumU        = (|EnumU|)
>   traverse f (EnumT e)    = (|EnumT (f e)|)
>   traverse f NilE         = (|NilE|)
>   traverse f (ConsE t e)  = (|ConsE (f t) (f e)|)
>   traverse f Ze           = (|Ze|)
>   traverse f (Su n)       = (|Su (f n)|) 

> import -> HalfZipCan where
>   halfZip EnumU EnumU = Just EnumU
>   halfZip (EnumT t0) (EnumT t1) = Just (EnumT (t0,t1))
>   halfZip NilE NilE = Just NilE
>   halfZip (ConsE s0 t0) (ConsE s1 t1) = Just (ConsE (s0,s1) (t0,t1))
>   halfZip Ze Ze = Just Ze
>   halfZip (Su t0) (Su t1) = Just (Su (t0,t1))

> import -> CanPretty where
>   prettyCan EnumU      = text "Enum"
>   prettyCan (EnumT t)  = braces (prettyEnum t)
>   prettyCan Ze         = text "0"
>   prettyCan (Su t)     = prettyEnumIndex 1 t

> import -> Pretty where
>   prettyEnum :: Tm {d, p} String -> Doc
>   prettyEnum NILE                            = empty
>   prettyEnum (CONSE (TAG t) NILE)            = text t
>   prettyEnum (CONSE (TAG t) ts@(CONSE _ _))  = text t <+> comma <+> prettyEnum ts
>   prettyEnum (CONSE (TAG t) ts)              = text t <+> text "/" <+> pretty ts
>   prettyEnum t                               = text "/" <+> pretty t
>
>   prettyEnumIndex :: Int -> Tm {d, p} String -> Doc
>   prettyEnumIndex n ZE      = int n
>   prettyEnumIndex n (SU t)  = prettyEnumIndex (succ n) t
>   prettyEnumIndex n tm      = parens (int n <+> text "+" <+> pretty tm)

> import -> CanTyRules where
>   canTy _ (Set :>: EnumU)    = return EnumU
>   canTy chev (Set :>: EnumT e)  = do
>     eev@(e :=>: ev) <- chev (ENUMU :>: e)
>     return $ EnumT eev
>   canTy chev (EnumU :>: NilE)       = return NilE
>   canTy chev (EnumU :>: ConsE t e)  = do
>     ttv@(t :=>: tv) <- chev (UID :>: t)
>     eev@(e :=>: ev) <- chev (ENUMU :>: e)
>     return $ ConsE ttv eev
>   canTy _ (EnumT (CONSE t e) :>: Ze)    = return Ze 
>   canTy chev (EnumT (CONSE t e) :>: Su n)  = do
>     nnv@(n :=>: nv) <- chev (ENUMT e :>: n)
>     return $ Su nnv

> import -> OpCode where
>   branchesOp = Op 
>     { opName   = "Branches"
>     , opArity  = 2 
>     , opTy     = bOpTy
>     , opRun    = bOpRun
>     } where
>         bOpTy chev [e , p] = do
>                  (e :=>: ev) <- chev (ENUMU :>: e)
>                  (p :=>: pv) <- chev (ARR (ENUMT ev) SET :>: p)
>                  return ([ e :=>: ev
>                          , p :=>: pv]
>                          , SET)
>         bOpTy _ _ = throwError' "branches: invalid arguments"
>         bOpRun :: [VAL] -> Either NEU VAL
>         bOpRun [NILE , _] = Right UNIT
>         bOpRun [CONSE t e' , p] = Right $ branchesTerm $$ A t $$ A e' $$ A p
>         bOpRun [N e , _] = Left e 
>         branchesTerm = trustMe (typeBranches :>: tacBranches)
>         typeBranches = trustMe (SET :>: tacTypeBranches)
>         tacTypeBranches = piTac uidTac
>                                 (\t ->
>                                  piTac enumUTac
>                                        (\e ->
>                                         arrTac (arrTac (enumTTac (consETac (use t done)
>                                                                            (use e done)))
>                                                        setTac)
>                                                setTac))
>         tacBranches = lambda $ \t ->
>                       lambda $ \e' ->
>                       lambda $ \p ->
>                       timesTac (p @@@ [zeTac])
>                                (useOp branchesOp [ use e' done
>                                                  , lambda $ \x -> 
>                                                    p @@@ [suTac (use x done)]]
>                                 done)

>   switchOp = Op
>     { opName = "Switch"
>     , opArity = 4
>     , opTy = sOpTy
>     , opRun = sOpRun
>     } where
>         sOpTy chev [e , p , b, x] = do
>           (e :=>: ev) <- chev (ENUMU :>: e)
>           (p :=>: pv) <- chev (ARR (ENUMT ev) SET :>: p)
>           (b :=>: bv) <- chev (branchesOp @@ [ev , pv] :>: b)
>           (x :=>: xv) <- chev (ENUMT ev :>: x)
>           return $ ([ e :=>: ev
>                     , p :=>: pv
>                     , b :=>: bv
>                     , x :=>: xv ] 
>                    , pv $$ A xv)
>         sOpRun :: [VAL] -> Either NEU VAL
>         sOpRun [CONSE t e' , p , ps , ZE] = Right $ ps $$ Fst
>         sOpRun [CONSE t e' , p , ps , SU n] = Right $ switchTerm
>                                                       $$ A t $$ A e' $$ A p $$ A ps $$ A n
>         sOpRun [_ , _ , _ , N n] = Left n
>
>         switchTerm = trustMe (typeSwitch :>: tacSwitch) 
>         tacSwitch = lambda $ \t ->
>                     lambda $ \e' ->
>                     lambda $ \p ->
>                     lambda $ \ps ->
>                     lambda $ \n ->
>                     useOp switchOp [ use e' done
>                                    , lambda $ \x -> 
>                                      p @@@ [ suTac (use x done) ]
>                                    , use ps . apply Snd $ done
>                                    , use n done ]
>                     done
>         typeSwitch = trustMe (SET :>: tacTypeSwitch) 
>         tacTypeSwitch = piTac uidTac
>                               (\t ->
>                                piTac enumUTac
>                                      (\e -> 
>                                       piTac (arrTac (enumTTac (consETac (use t done) 
>                                                                         (use e done)))
>                                                     setTac)
>                                             (\p ->
>                                              arrTac (useOp branchesOp [ consETac (use t done) (use e done)
>                                                                       , use p done] done)
>                                                      (piTac (enumTTac (use e done))
>                                                                       (\x -> 
>                                                                        p @@@ [ suTac $ use x done ])))))


> import -> Operators where
>   branchesOp :
>   switchOp :

> import -> OpCompile where
>     ("Branches", _) -> Ignore
>     ("Switch", [e, p, b, x]) -> App (Var "__switch") [b, x]

