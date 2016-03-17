// @flow
import { Record as ImmRecord, List } from 'immutable';
import React, { Component, PropTypes } from 'react';

import Firmament, { UpLevel } from './Firmament';
import {
  INTRODUCTION,
  ELIMINATION,
  REMOVE_FIELD,
  NEW_FIELD,
} from '../messages';
import { handler as removeField } from '../actions/remove_field';
import { handler as newField } from '../actions/new_field';
import NewField from '../components/NewField';
import Rows from '../components/Rows';

import type { Element } from 'react';

import type { Path } from './Firmament';
import type {
  FillHoleSignal,
  ImplementationUpdatedSignal,
  ReferenceUpdatedSignal,
  NewFieldSignal,
  RemoveFieldSignal,
} from '../messages';


const RECORD = Symbol('RECORD');
const RECORD_TY = Symbol('RECORD_TY');
const PROJECTION = Symbol('PROJECTION');


const fieldHandlers = {
  NEW_FIELD: newField,
  REMOVE_FIELD: removeField,
  FILL_HOLE: fillHole,
};

const RecordData = ImmRecord({
  fields: List(),
});

const RecordTyData = ImmRecord({
  fields: List(),
});

function fillHole(
  global: Firmament,
  signal: FillHoleSignal
): Firmament {

  const { referer, holeName, fill } = signal;

  const loc: Location = global.getLocation(referer);

  // $FlowIgnore: this is inherited from Record
  const loc_: Location = loc.setIn(['locations', holeName], fill);

  return global.set(referer, loc_);
}

function recordTyUpdate(
  global: Firmament,
  signal: ImplementationUpdatedSignal
): Firmament {
  const action = signal.signal.action;

  if (action === NEW_FIELD || action === REMOVE_FIELD) {
    // * why is this supposedly an object type?
    // * i think flow isn't able to refine this beyond AnySignal to
    //   (NewFieldSignal | RemoveFieldSignal)
    // $FlowIgnore
    const subSignal: NewFieldSignal | RemoveFieldSignal = signal.signal;
    const target: Symbol = signal.target;
    const { name, path: { root, steps } } = subSignal;

    const signal_ = {
      // Flow apparently isn't sophisticated enough to understand this could be
      // of either type.
      // $FlowIgnore: I think this is fine...
      action,
      name,
      path: {
        root,
        steps: steps.concat(UpLevel),
      },
    };

    return action === NEW_FIELD
      ? newField(global, signal_)
      // $FlowIgnore
      : removeField(global, signal_);
  }

  return global;
}

function recordUpdate(
  global: Firmament,
  signal: ReferenceUpdatedSignal
): Firmament {

  const action = signal.signal.action;
  const original = global.getLocation(signal.original);

  if ((action === NEW_FIELD || action === REMOVE_FIELD) && original.tag === RecordTy) {
    // $FlowIgnore see note in recordTyUpdate
    const subSignal : NewFieldSignal | RemoveFieldSignal = signal.signal;
    const { referer, original } = signal;
    const { name, path: { root, steps } } = subSignal;

    // XXX need to treat differently depending on what kind of reference this is
    const signal_ = {
      // Flow apparently isn't sophisticated enough to understand this could be
      // of either type.
      // $FlowIgnore: I think this is fine...
      action,
      name,
      path: {
        root: referer, // XXX
        steps: [],
      },
    };

    return action === NEW_FIELD ?
      newField(global, signal_) :
      removeField(global, signal_);
  }

  return global;
}

const ProjectionData = ImmRecord({
  // TODO also point to record location

  // This is tricky -- we need to be able to fill in tag, but it must be
  // limited to the tags this record supports. Need some protocol for queries.
  tag: null,
  record: null,
});

const projectionHandlers = {
  // TODO - this thing where you specify either a record or the tag, and it
  // infers info about the other

  STEP(global: Firmament, { path }: { path: Path }): Firmament {
    const loc = global.getPath(path);
    const { tag, record } = loc.data;

    // TODO - returning a location here... what should we return?
    return record.concat(tag);
  },
};


type ProjectionViewProps = {
  path: Path;
};


export class ProjectionView extends Component<{}, ProjectionViewProps, {}> {

  static contextTypes = {
    global: PropTypes.instanceOf(Firmament).isRequired,
  };

  render(): Element {
    const { global } = this.context;
    const { path } = this.props;
    const loc = global.getPath(path);
    const { tag } = loc;

    return (
      <div>
        <RecordView path={path.concat('record')} />.{tag}
      </div>
    );
  }
}


// TODO remove duplication in Module.js
const contextTypes = {
  signal: PropTypes.func.isRequired,
  global: PropTypes.instanceOf(Firmament).isRequired,
};


type RecordLikeProps = {
  path: Path;
};


export class RecordTyView extends Component<{}, RecordLikeProps, {}> {

  static contextTypes = contextTypes;

  render(): Element {
    const { global } = this.context;
    const { path } = this.props;
    const loc = global.getPath(path);

    return <Rows fields={loc.data.fields} locations={loc.locations} path={path} />;
  }
}


export class RecordView extends Component<{}, RecordLikeProps, {}> {

  static contextTypes = contextTypes;

  render(): Element {
    const { global, signal } = this.context;
    const { path } = this.props;
    const loc = global.getPath(path);

    return (
      <div>
        <Rows fields={loc.data.fields} locations={loc.locations} path={path} />
        <NewField signal={action => { signal(path, action); }} />
      </div>
    );
  }
}


export const Record = {
  name: 'Record',
  symbol: RECORD,
  type: INTRODUCTION,
  minLevel: 0,
  handlers: {
    ...fieldHandlers,
    // XXX this is exactly the same as the equivalent module op
    REFERENCE_UPDATED: recordUpdate,
  },
  render: RecordView,
  data: RecordData,
  getNamesInScope(loc: Location): Set<string> {
    // $FlowIgnore: immutable record problems :(
    return loc.locations.keySeq().toSet();
  },
};

export const RecordTy = {
  name: 'RecordTy',
  symbol: RECORD_TY,
  type: INTRODUCTION,
  minLevel: 1,
  handlers: {
    ...fieldHandlers,
    // XXX this is exactly the same as the equivalent module op
    IMPLEMENTATION_UPDATED: recordTyUpdate,
  },
  render: RecordTyView,
  data: RecordTyData,
  getNamesInScope(loc: Location): Set<string> {
    throw new Error("can't get names of RecordTy");
  },
};

export const Projection = {
  symbol: PROJECTION,
  type: ELIMINATION,
  handlers: projectionHandlers,
  render: ProjectionView,
};