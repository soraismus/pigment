\section{Nu}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}

> module Features.Nu where

%endif

> import -> CanTraverse where
>   traverse f (Nu t) = (|Nu (traverse f t)|)
>   traverse f (CoIt d sty g s) = (|CoIt (f d) (f sty) (f g) (f s)|)

> import -> CanHalfZip where
>   halfZip (Nu t0) (Nu t1)  = (| Nu (halfZip t0 t1) |)
>   halfZip (CoIt d0 sty0 g0 s0) (CoIt d1 sty1 g1 s1) =
>     Just (CoIt (d0,d1) (sty0,sty1) (g0,g1) (s0,s1))

> import -> CanReactive where
>   reactify (Nu (Just l :?=: _))  = reactify l
>   reactify (Nu (Nothing :?=: Id t))  = reactKword KwNu >> reactify t
>   reactify (CoIt d sty f s) = do
>       reactKword KwCoIt
>       reactify sty
>       reactify f
>       reactify s

> import -> ElimTyRules where
>   elimTy chev (_ :<: t@(Nu (_ :?=: Id d))) Out = return (Out, descOp @@ [d , C t])

> import -> ElimComputation where
>   COIT d sty f s $$ Out = mapOp @@ [d, sty, NU Nothing d,
>     L $ "s" :. [.s. COIT (d -$ []) (sty -$ []) (f -$ []) (NV s)],
>     f $$ A s]

> import -> Coerce where
>   -- coerce :: (Can (VAL,VAL)) -> VAL -> VAL -> Either NEU VAL
>   coerce (Nu (Just (l0,l1) :?=: Id (d0,d1))) q (CON x) =
>     let typ = ARR desc (ARR SET SET)
>         vap = L $ "d" :. [.d. L $ "l" :. [.l. N $
>                 descOp :@ [NV d,NU (Just $ NV l) (NV d)] ] ]
>     in Right . CON $
>       coe @@ [ descOp @@ [ d0 , NU (Just l0) d0 ]
>              , descOp @@ [ d1 , NU (Just l1) d1 ]
>              , CON $ pval refl $$ A typ $$ A vap $$ Out
>                                $$ A d0 $$ A d1 $$ A (CON $ q $$ Snd)
>                                $$ A l0 $$ A l1 $$ A (CON $ q $$ Fst)
>              , x ]
>   coerce (Nu (Nothing :?=: Id (d0,d1))) q (CON x) =
>     let typ = ARR desc SET
>         vap = L $ "d" :. [.d. N $
>                 descOp :@ [NV d,NU Nothing (NV d)] ]
>     in Right . CON $
>       coe @@ [ descOp @@ [ d0 , NU Nothing d0 ]
>              , descOp @@ [ d1 , NU Nothing d1 ]
>              , CON $ pval refl $$ A typ $$ A vap $$ Out
>                                $$ A d0 $$ A d1 $$ A (CON q)
>              , x ]



> import -> KeywordConstructors where
>   KwNu    :: Keyword
>   KwCoIt  :: Keyword

> import -> KeywordTable where
>   key KwNu        = "Nu"
>   key KwCoIt      = "CoIt"

> import -> DInTmParsersSpecial where
>   (AndSize, (|(DNU Nothing) (%keyword KwNu%) (sizedDInTm ArgSize)|)) :
>   (AndSize, (|(DCOIT DU) (%keyword KwCoIt%)
>       (sizedDInTm ArgSize) (sizedDInTm ArgSize) (sizedDInTm ArgSize)|)) :




> import -> MakeElabRules where
>     makeElab' loc (NU l d :>: DVOID) =
>         makeElab' loc (NU l d :>: DCON (DPAIR DZE DVOID))
>     makeElab' loc (NU l d :>: DPAIR s t) =
>         makeElab' loc (NU l d :>: DCON (DPAIR (DSU DZE) (DPAIR s (DPAIR t DVOID))))
>     makeElab' loc (SET :>: DNU Nothing d) = do
>         lt :=>: lv <- eFaker
>         dt :=>: dv <- subElab loc (desc :>: d)
>         return $ NU (Just (N lt)) dt :=>: NU (Just lv) dv
>     makeElab' loc (NU l d :>: DCOIT DU sty f s) = do
>       d' :=>: _ <- eQuote d
>       makeElab' loc (NU l d :>: DCOIT (DTIN d') sty f s)



To avoid an infinite loop when distilling, we have to be a little cleverer
and call canTy directly rather than letting distill do it for us.

> import -> DistillRules where
>     distill _ (NU _ _ :>: CON (PAIR ZE VOID)) =
>         return (DVOID :=>: CON (PAIR ZE VOID))
>     distill es (C ty@(Nu _) :>: C c@(Con (PAIR (SU ZE) (PAIR _ (PAIR _ VOID))))) = do
>         Con (DPAIR _ (DPAIR s (DPAIR t _)) :=>: v) <- canTy (distill es) (ty :>: c)
>         return (DPAIR s t :=>: CON v)


If a label is not in scope, we remove it, so the definition appears at the
appropriate place when the proof state is printed.

>     distill es (SET :>: tm@(C (Nu ltm@(Just _ :?=: _)))) = do
>       cc <- canTy (distill es) (Set :>: Nu ltm)
>       return ((DC $ fmap termOf cc) :=>: evTm tm)
