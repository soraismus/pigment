import expect from 'expect';
import { Map } from 'immutable';

import { Type, Hole } from '../src/theory/tm';
import { mkSuccess, mkStuck, evalLookup } from '../src/theory/evaluation';
import { Lam, Arr, App } from '../src/theory/lambda';
import { empty as emptyCtx } from '../src/theory/context';
import { mkVar } from '../src/theory/abt';

describe('eval', () => {
  it('evaluates type', () => {
    // start with an empty context;
    expect(Type.singleton.evaluate(emptyCtx))
      .toEqual(mkSuccess(Type.singleton));
  });

  it('gets stuck on holes', () => {
    const hole = new Hole('hole', Type.singleton);
    expect(hole.evaluate(emptyCtx))
      .toEqual(mkStuck(hole));

    // TODO would be awesome for this to be parametric
    const lamTy = new Arr(Type.singleton, Type.singleton);

    const returningHole = new App(
      new Lam(null, hole, lamTy),
      Type.singleton
    );
    expect(returningHole.evaluate(emptyCtx))
      .toEqual(mkStuck(hole));
  });

  it('evaluates variables', () => {
    const ctx = Map({'x': Type.singleton});
    const lookedUp = evalLookup(ctx, 'x');

    expect(lookedUp).toEqual(mkSuccess(Type.singleton));
  });

  describe('lam', () => {
    // TODO would be awesome for this to be parametric
    const ty = Type.singleton;
    const lamTy = new Arr(ty, ty);
    const ctx = Map({'x': ty});

    it('works with var', () => {
      const tm = new App(
        new Lam('x', mkVar('x'), lamTy),
        ty
      );

      expect(tm.evaluate(ctx))
        .toEqual(mkSuccess(ty))
    });

    it('works with wildcards', () => {
      const tm = new App(
        new Lam(null, ty, lamTy),
        ty
      );

      expect(tm.evaluate(ctx))
        .toEqual(mkSuccess(ty))
    });
  });
});
