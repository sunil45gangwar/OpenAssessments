"use strict";

import React                          from 'react';
import _                              from 'lodash';
import BaseComponent                  from '../base_component.jsx';
import Style                          from './css/style';
import Expandable                     from '../admin/expandable';

export default class Instructions extends BaseComponent{

  constructor(props, context) {
    super(props, context);

    //Rebindings
    this._bind();
  }//constructor

render() {
    console.log("rendering instructions", this.props.settings.assessmentKind);
    if(this.props.settings.assessmentKind == "summative"){
      return <p>summative</p>
    }
    else if(this.props.settings.assessmentKind == "formative"){
      return <p>formative</p>
    }
    else if (this.props.settings.assessmentKind == "swyk"){
        return <p>swyk</p>
    }
    else return <p>hi</p>
}

  }
