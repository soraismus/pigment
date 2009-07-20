\documentclass[a4paper]{report}
\usepackage{stmaryrd,wasysym,url,upgreek,palatino,alltt}

%include lhs2TeX.fmt
%include lhs2TeX.sty
%include polycode.fmt

%include stuff.fmt

\begin{document}

\title{An Epigram Implementation}
\author{Conor McBride, James Chapman, Peter Morris}
\maketitle

\chapter{Perversity}

%include BwdFwd.lhs
%include Parsley.lhs

\chapter{Core}

%include Root.lhs
%include Tm.lhs

\chapter{Feature by Feature}

%include Features.lhs

\chapter{Concrete Syntax}

%include Lexer.lhs
%include Layout.lhs
%include TmParse.lhs


\end{document}