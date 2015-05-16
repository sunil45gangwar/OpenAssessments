"use strict";

import Dispatcher     from "../dispatcher";
import Constants      from "../constants";
import StoreCommon    from "./store_common";
import assign         from "object-assign";
import _              from "lodash";

var _accounts = [];
var _users = [];

function loadAccounts(data){
  //console.log(data);
  _accounts = JSON.parse(data);
  // translates the data into a format material ui can understand;
 
}



function loadUsers(data){
  var userList = JSON.parse(data);
  // translates the data into a format material ui can understand;
  _users = [];
  for(var i=0; i< userList.length; i++){
    var s = "" + i;
    _users[i] = {
      payload: s, 
      text: userList[i].name, 
      data: userList[i].email, 
      role: userList[i].role,
      userID: userList[i].id,
      accountID: userList[i].account_id
    };
  }
}

// Extend User Store with EventEmitter to add eventing capabilities
var AccountsStore = assign({}, StoreCommon, {

  // Return the accounts
  current(){
    return _accounts;
  },

  // Return current users
  currentUsers(){
    return _users;
  },
  
  accountById(id){
    var account =  _.find(_accounts, function(account){
      return account.id == id;
    });
    //debugger;
  return account;
  }

});
 
// Register callback with Dispatcher
Dispatcher.register(function(payload) {
  var action = payload.action;
  
  switch(action){

    case Constants.ACCOUNTS_LOADED:
      loadAccounts(payload.data.text);

      break;
    case Constants.USERS_LOADED:
      loadUsers(payload.data.text);

      break;
    case Constants.USERS_UPDATED:
      // UPDATE THE USERS LIST AND SUCH
      console.log(payload.data.text);
      break;

    default:
      return true;
  }

  // If action was responded to, emit change event
  AccountsStore.emitChange();
  
  return true;

});

export default AccountsStore;

