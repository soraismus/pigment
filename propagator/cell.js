// @flow
import type Scheduler from './scheduler';

export type ForwardChange<A> = {
  tag: 'FORWARD_CHANGE';

  // did we change anything / gain information over the old?
  gain: boolean;

  content: A;
};

export type Contradiction = {
  tag: 'CONTRADICTION';

  errorMessage: string;

  // TODO more information - the haskell version has this data constructor:
  // `Contradiction !(HashSet Name) String`
  // names: Immutable.Set<Name>;
};

export type Change<A> = ForwardChange<A> | Contradiction;
export type Merge<A> = (left: A, right: A) => Change<A>;

export type Protocol<A> = {
  merge: Merge<A>;
};

// A cell contains "information about a value" rather than a value per se.
//
// - https://github.com/ekmett/propagators/blob/master/src/Data/Propagator/Cell.hs
//
// The shared connection mechanism is called a "cell" and the machines they
// connect are called "propagators".
export default class Cell<A> {
  scheduler: Scheduler;
  protocol: Protocol<A>;
  name: string | null;
  content: A;
  id: number;

  constructor(
    scheduler: Scheduler,
    protocol: Protocol<A>,
    content: A,
    name?: string
  ) {
    this.scheduler = scheduler;
    this.protocol = protocol;
    this.content = content;
    this.name = name || null;
    this.id = scheduler.registerCell(this);
  }

  // Update the value of this cell, propagating any updates
  addContent(increment: A) {
    const answer = this.protocol.merge(this.content, increment);
    if (answer.tag === 'CONTRADICTION') {
      throw new Error(`Ack! Inconsistency!\n ${answer.errorMessage}`);
    } else if (answer.gain) {
      this.content = answer.content;
      this.scheduler.markDirty(this.id);
    }

    // else no change
  }
}