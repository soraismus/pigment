// @flow

import invariant from 'invariant';
import { Record } from 'immutable';

import { INTRO, Type } from '../../theory/tm';
import { register } from '../../theory/registry';

import type { Tm } from '../../theory/tm';


var labelShape = Record({
  name: null,
}, 'label');

export class Label extends labelShape {

  constructor(name: string): void {
    super({ name });
  }

  getType(): Tm {
    return Type.singleton;
  }

  evaluate(root: AbsRef, ctx: Context): EvaluationResult {
    return mkSuccess(this);
  }

  static typeClass = Type.singleton;

  static fillHole(type: Tm): Label {
    invariant(
      type === LabelTy
      'Type asked to fill a hole of type other than LabelTy'
    );

    return LabelTy.singleton;
  }

  static form = INTRO;
}

register('label', Label);
