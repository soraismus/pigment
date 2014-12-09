\section{Skeleton feature}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}

> module Features.Skeleton where

%endif


\subsection{Extending the concrete syntax}

> import -> KeywordTable where

> import -> ElimParsers where

> import -> DInTmParsersSpecial where

> import -> DInTmParsersMore where

> import -> ParserCode where

\subsection{Extending the elaborator and distiller}

> import -> MakeElabRules where

> import -> DistillRules where
