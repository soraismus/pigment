// @flow

import { Record } from 'immutable';

import { ELIM, Hole } from '../../theory/tm';
import { register } from '../../theory/registry';
import { bind } from '../../theory/evaluation';
import { mkRel } from '../../theory/ref';

import type { Tm } from '../../theory/tm';
import type { AbsRef, Ref } from '../../theory/ref';


const appShape = Record({
  func: null,
  arg: null,
  type: null,
}, 'app');

export default class App extends appShape {

  constructor(func: Tm, arg: Tm, type: Tm): void {
    const fType = func.type;

    if (fType instanceof Arr) {
      const type = fType.codomain;
      super({ func, arg, type });
    } else {
      throw new Error('runtime error in App constructor');
    }
  }

  step(root: AbsRef, ctx: Context): EvaluationResult {
    return bind(
      this.arg.step(root.extend(mkRel('arg')), ctx),
      arg => this.func.step(root.extend(mkRel('func')), ctx, arg)
    );
  }

  // hm... this hardly seems to make sense for app...
  subst(root: AbsRef, ref: Ref, value: Tm): Tm {
    throw new Error('unimplemented - App.subst');
  }

  static fillHole(type: Tm): App {
    // how to quantify this variable so it's the same in both places?
    // future plan: instantiate here with a quantifier, its context menu allows
    // you to instantiate it and remove the quantifier.
    const x = Type.singleton;

    return new App(
      new Hole('f', XXX /* this needs to be an arrow... */),
      new Hole('x', x),
      type
    );
  }

  static form = ELIM;
}

register('app', App);
