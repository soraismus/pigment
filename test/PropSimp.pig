make P := ? : Prop ;
make Q := ? : Prop ;
make R := ? : Prop ;
make A := ? : Set ;
make B := ? : Set ;

make easy : :- TT ;
simplify ;
root ;

make hard : :- FF ;
simplify ;
root ;

make useless : :- (TT => P) ;
simplify ;
root ;

make easyish : :- (FF => P) ;
simplify ;
root ; 

make andy : :- (TT && P && TT) && (TT && Q) ;
simplify ;
root ;

make ethel : :- (TT && P => Q && FF) ;
simplify ;
root ;

make oops : :- ((TT && P => Q && FF) => FF) ;
simplify ;
root ;

make f : :- ((TT => P) => TT) ;
simplify ;
root ;

make g : :- (TT => TT) ;
simplify ;
root ;

make h : :- (P => TT) ;
simplify ;
root ;

make k : :- (P => FF && P) ;
simplify ;
root ; 

make x : :- (((P && TT) && (TT && Q)) && R && P) ;
simplify ;
root ;

make y : :- ((x : Set)(y : Set) => TT) ;
simplify ; 
root ;

make z : :- ((x : Set) => TT && P && Q) ;
simplify ; 
root ;

make a : :- ((TT => FF) => P) ;
simplify ;
root ;

make b : :- (TT => TT && P) ;
simplify ;
root ;

make eek : :- ((P => FF) => FF) ;
simplify ;
root ;

make d : :- (P && Q => TT) ;
simplify ;
root ;

make e : :- (TT && P => Q && TT) ;
simplify ;
root ;

make f : :- (P => P) ;
simplify ;
root ;

make g : :- (P && Q => R && Q && P) ;
simplify ;
root ;

make h : :- ((P => Q) => P => Q) ;
simplify ;
root ;

make k : :- (P == Q => P == Q) ;
simplify ;
root ;

make l : :- (P => Q) ;
simplify ;
root ;

make m : :- ((: Set) Set == (: Set) Set) ;
simplify ; 
root ;

make p : :- (((: Set -> Prop) \ x -> P) == ((: Set -> Prop) \ x -> Q)) ;
simplify ;
root ;

make q : :- ((: Set) Set == (: Set) (Set -> Set)) ;
simplify ;
root ;

make r : :- (P == P) ;
simplify ;
root ;

make s : :- (A == A) ;
simplify ;
root ;

make t : :- (A == B) ;
simplify ;
root ;

make u : :- ((: Sig (A ; B)) ?x == (: Sig (A ; B)) ?y) ;
simplify ;
root ;

