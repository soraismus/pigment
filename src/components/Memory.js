// @flow
import React, { Component } from 'react';

import { row, column } from '../styles/flex';

import type { Element } from 'react';

import type Firmament from '../models/Firmament';


function PointerView({ name, pointer, selected, callback }) {
  const myStyle = Object.assign(
    {},
    pointer === selected ? style.selected : style.standard,
    style.li
  );
  return (
    <li
      style={myStyle}
      onClick={() => callback(pointer)}
    >
      {name.toString()}
    </li>
  );
}


export default class Memory extends Component {
  constructor(props: { global: Firmament }) {
    super(props);
    this.state = {
      selected: null,
    };
  }

  handleClick(pointer: Symbol) {
    const selected = this.state.selected === pointer
      ? null
      : pointer;
    this.setState({ selected });
  }

  render(): Element {
    const { global } = this.props;
    const { selected } = this.state;

    const rows = global.memory.map(({ tag, data, locations }, key) => {
      const locs = locations.map((pointer, name) => (
        <PointerView
          {...{ name, pointer, selected }}
          callback={pointer => this.handleClick(pointer)}
        />
      ))
        .toArray();

      return (
        <tr style={key === selected ? style.selected : style.standard}>
          <td style={style.td}>{tag.name}</td>
          <td style={style.td}>{data && JSON.stringify(data.toJS())}</td>
          <td style={style.td}>
            <ul style={style.locations}>{locs}</ul>
          </td>
        </tr>
      );
    })
      .toArray();

    return (
      <div style={column}>
        <h2>Memory</h2>
        <table style={style.table}>
          <thead>
            <tr>
              <th style={style.th}>Type</th>
              <th style={style.th}>Data</th>
              <th style={style.th}>Locations</th>
            </tr>
          </thead>
          <tbody>
            {rows}
          </tbody>
        </table>
      </div>
    );
  }
}


const style = {
  selected: {
    borderLeft: '5px solid red',
  },
  standard: {
    marginLeft: 5,
  },
  table: {
    borderCollapse: 'collapse',
    border: '1px solid #eee',
    borderBottom: '2px solid #00cccc',
    fontFamily: 'Arial',
  },
  th: {
    background: '#00cccc',
    color: '#fff',
    textTransform: 'uppercase',
    border: '1px solid #eee',
    padding: '12px 35px',
    borderCollapse: 'collapse',
  },
  td: {
    color: '#999',
    border: '1px solid #eee',
    padding: '12px 35px',
    borderCollapse: 'collapse',
  },
  locations: {
    listStyleType: 'none',
  },
  li: {
    padding: 5,
  },
};