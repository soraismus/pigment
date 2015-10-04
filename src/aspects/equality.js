import { Expression, Type } from './tm';


// Propositional Equality type
export class Equality extends Expression {
  static arity = [0];
  static renderName = "equality";

  constructor(ty): void {
    super([ty], Type.singleton);
  }

  map(): Equality {
    throw new Error('unimplemented - Equality.map');
  }

  evaluate(): EvaluationResult<Expression> {
    throw new Error('unimplemented - Equality.evaluate');
  }
}


// TODO come up with appropriate name for this
export class Refl extends Expression {
  static arity = [0, 0];
  static renderName = "refl";


  constructor(l: Expression, r: Expression): void {
    super([l, r], tyXXX);
  }

  map(): Equality {
    throw new Error('unimplemented - Refl.map');
  }

  evaluate(): EvaluationResult<Expression> {
    throw new Error('unimplemented - Refl.evaluate');
  }
}