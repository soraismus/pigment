//
// TODO:
// * user-defined types
// * source positions? how does this relate to names?
import { Set } from 'immutable';

import { Abt, mkTm } from './abt';
import { lookup } from './context';
import type { Context } from './context';
import { mkStuck, mkSuccess } from './evaluation';
import type { EvaluationResult } from './evaluation';


export class Expression extends Abt {
  static renderName: string;

  type: Expression;

  // bleh. making an exception here since Lam.evaluate uses an extra parameter.
  // TODO figure out a better way.
  //
  // $flow-exception
  evaluate: ((ctx: Context) => EvaluationResult<Expression>) &
            ((ctx: Context, x: Expression) => EvaluationResult<Expression>);

  constructor(children: Array<Abt>,
              binders: Array<Array<?string>>,
              type: Expression): void {

    // fill in freevars and children with meaningless values, since we're
    // required to call super before touching this.
    super(Set(), []);

    var abt: Abt = mkTm(children, binders);

    this.freevars = abt.freevars;
    this.children = abt.children;
    this.type = type;
  }
}


export class Type extends Expression {
  // $flowstatic
  static arity = [];
  // $flowstatic
  static renderName = "type";
  // $flowstatic
  static singleton = new Type();

  constructor(): void {
    // We make an exception here and allow the type to be null, so we don't end
    // up with Type referring to itself, because that makes testing harder
    // (involving JSON serialization).
    //
    // $flow-type-in-type
    super([], [], null);
    // circular json PITA
    // this.type = this;
  }

  evaluate(): EvaluationResult<Expression> {
    return mkSuccess(this);
  }
}
Type.arity = [];


export class Hole extends Expression {
  // $flowstatic
  static arity = [];
  // $flowstatic
  static renderName = "hole";
  name: ?string;

  constructor(name: ?string, type: Expression): void {
    super([], [], type);
    this.name = name;
  }

  evaluate(): EvaluationResult<Expression> {
    return mkStuck(this);
  }
}
