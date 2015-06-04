"use strict";

import React           from 'react';
import TestUtils       from 'react/lib/ReactTestUtils';
import EditUserForm    from './edit_user_form';
import SettingsActions from '../../actions/settings';
import StubContext     from '../../../specs_support/stub_context';

describe('edit_user_form', function() {

  helpStubAjax(SettingsActions);

  it("renders the form to edit the users", function() {
    var name = "Joseph";
    var email = "test@test.com";
    var id = 1;
    var Subject = StubContext(EditUserForm, { user: {name: name, id: id, email: email }, selectedIndex: 0 });
    var result = TestUtils.renderIntoDocument(<Subject />);
    expect(React.findDOMNode(result).textContent).toContain(name);
  });
  
});