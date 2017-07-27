pragma solidity ^0.4.11;
/*
import "./AbstractFoundation.sol";
import "./AbstractFriend.sol";

contract Debt {

  AbstractFoundation af;
  AbstractFriend afs;
  AbstractFIDData afd;

  bytes32 adminFoundationId;

  modifier isIdOwner(address _caller, bytes32 _name) {
    if ( ! af.isUnified(_caller, _name) ) revert();
    _;
  }

  modifier isAdmin(address _caller) {
    if ( ! af.idEq(adminFoundationId, af.resolveToName(_caller))) revert();
    _;
  }

  modifier currencyValid(bytes32 _currencyCode) {
    if ( ! currencyCodes[_currencyCode] ) revert();
    _;
  }

  modifier areFriends(bytes32 _id1, bytes32 _id2) {
    if ( ! afs.areFriends(_id1, _id2) ) revert();
    _;
  }

  modifier debtIndices(bytes32 p1, bytes32 p2) {
    first = p1;
    second = p2;
    if ( debts[p1][p2].length == 0 ) {
      first = p2;
      second = p1;
    }
    _;
  }

  function FriendInDebt(bytes32 _adminId, address dataContract, address friendContract, address foundationContract) {
    afd = AbstractFIDData(dataContract);
    afs = AbstractFriend(friendContract);
    af  = AbstractFoundation(foundationContract);
    adminFoundationId = _adminId;
    initCurrencyCodes();
  }

  function initCurrencyCodes() private {
    currencyCodes[bytes32("USD")] = true;
    currencyCodes[bytes32("EUR")] = true;
  }

  function addCurrencyCode(bytes32 _currencyCode) isAdmin(msg.sender) {
    currencyCodes[_currencyCode] = true;
  }

  function isActiveCurrency(bytes32 _currencyCode) constant returns (bool) {
    return currencyCodes[_currencyCode];
  }

  uint[] pDebts; //"local"
  bytes32[] friends;
  bytes32[] idsNeededToConfirmD;
  bytes32[] currencyD;
  int[] amountsD;
  bytes32[] descsD;
  bytes32[] debtorsD;
  bytes32[] creditorsD;
  function pendingDebts(bytes32 _foundationId) constant returns (uint[] debtIds, bytes32[] confirmerIds, bytes32[] currency, int[] amounts, bytes32[] descs, bytes32[] debtors, bytes32[] creditors) {
    friends.length = 0;
    for ( uint m=0; m < afs.numFriends(_foundationId); m++ ) {
      bytes32 tmp = afs.friendIdByIndex(_foundationId, m);
      friends.push(tmp);
    }
    pDebts.length = 0;
    idsNeededToConfirmD.length = 0;
    currencyD.length = 0;
    amountsD.length = 0;
    descsD.length = 0;
    debtorsD.length = 0;
    creditorsD.length = 0;

    for ( uint i=0; i < friends.length; i++) {
      if ( debts[friends[i]][_foundationId].length > 0 ) {
        first  = friends[i];
        second = _foundationId;
      }
      else {
        first = _foundationId;
        second = friends[i];
      }
      for ( uint j=0; j < debts[first][second].length; j++ ) {
        Debt memory d = debts[first][second][j];
        if ( d.isPending ) {
          pDebts.push(d.id);
          currencyD.push(d.currencyCode);
          amountsD.push(d.amount);
          descsD.push(d.desc);
          debtorsD.push(d.debtorId);
          creditorsD.push(d.creditorId);
          if ( d.debtorConfirmed )
            idsNeededToConfirmD.push(d.creditorId);
          else
            idsNeededToConfirmD.push(d.debtorId);
        }
      }
    }
    return (pDebts, idsNeededToConfirmD, currencyD, amountsD, descsD, debtorsD, creditorsD);
  }

  mapping ( bytes32 => mapping (bytes32 => int )) currencyToIdToAmount;
  bytes32[] cdCurrencies;
  int[] amountsCD;
  //returns positive for debt owed, negative for owed from other party
  function confirmedDebtBalances(bytes32 _foundationId) constant returns (bytes32[] currency, int[] amounts, bytes32[] counterpartyIds) {
    friends.length = 0;
    for ( uint m=0; m < afs.numFriends(_foundationId); m++ ) {
      bytes32 tmp = afs.friendIdByIndex(_foundationId, m);
      friends.push(tmp);
    }
    currencyD.length = 0;
    amountsCD.length = 0;
    creditorsD.length = 0;
    for( uint i=0; i < friends.length; i++ ) {
      bytes32 cFriend = friends[i];
      cdCurrencies.length = 0;
      Debt[] memory d1 = debts[_foundationId][cFriend];
      Debt[] memory d2 = debts[cFriend][_foundationId];
      Debt[] memory ds;
      if ( d1.length == 0 )
        ds = d2;
      else
        ds = d1;
      for ( uint j=0; j < ds.length; j++ ) {
        if ( !ds[j].isPending && !ds[j].isRejected ) {
          if ( ! currencyMember(ds[j].currencyCode, cdCurrencies) )
            cdCurrencies.push(ds[j].currencyCode);
          if ( af.idEq(ds[j].debtorId, _foundationId) )
            currencyToIdToAmount[ds[j].currencyCode][cFriend] += ds[j].amount;
          else
            currencyToIdToAmount[ds[j].currencyCode][cFriend] -= ds[j].amount;
        }
      }
      for ( uint k=0; k < cdCurrencies.length; k++ ) {
        currencyD.push(cdCurrencies[k]);
        amountsCD.push(currencyToIdToAmount[cdCurrencies[k]][cFriend]);
        creditorsD.push(cFriend);
      }
    }
    return (currencyD, amountsCD, creditorsD);
  }

  function confirmedDebts(bytes32 p1, bytes32 p2) debtIndices(p1, p2) constant returns (bytes32[] currency, int[] amounts, bytes32[] descs, bytes32[] debtors, bytes32[] creditors) {
    currencyD.length = 0;
    amountsD.length = 0;
    descsD.length = 0;
    debtorsD.length = 0;
    creditorsD.length = 0;
    for ( uint i=0; i < debts[first][second].length; i++ ) {
      Debt memory d = debts[first][second][i];
      if ( ! d.isPending && ! d.isRejected ) {
        currencyD.push(d.currencyCode);
        amountsD.push(d.amount);
        descsD.push(d.desc);
        debtorsD.push(d.debtorId);
        creditorsD.push(d.creditorId);
      }
    }
    return (currencyD, amountsD, descsD, debtorsD, creditorsD);
  }

  function newDebt(bytes32 debtorId, bytes32 creditorId, bytes32 currencyCode, int amount, bytes32 _desc) currencyValid(currencyCode) areFriends(debtorId, creditorId) {
    if ( !af.isUnified(msg.sender, debtorId) && !af.isUnified(msg.sender, creditorId))
      revert();

    if ( amount == 0 ) return;

    bytes32 confirmerName = af.resolveToName(msg.sender);

    uint debtId = nextDebtId;
    nextDebtId++;
    Debt memory d;
    d.id = debtId;
    d.timestamp = now;
    d.currencyCode = currencyCode;
    d.isPending = true;
    d.desc = _desc;
    d.amount = amount;
    d.debtorId = debtorId;
    d.creditorId = creditorId;

    if ( af.idEq(confirmerName, debtorId) )
      d.debtorConfirmed = true;
    else
      d.creditorConfirmed = true;

    //if first debt array for me isn't initialized, use second
    if ( debts[debtorId][creditorId].length == 0 )
      debts[creditorId][debtorId].push(d);
    else
      debts[debtorId][creditorId].push(d);
  }

  function confirmDebt(bytes32 myId, bytes32 friendId, uint debtId) debtIndices(myId, friendId) isIdOwner(msg.sender, myId) {
    uint index;
    bool success;
    (index, success) = findPendingDebt(myId, friendId, debtId);
    if ( ! success ) return;
    Debt memory d = debts[first][second][index];
    if ( af.idEq(myId, d.debtorId) && !d.debtorConfirmed && d.creditorConfirmed )
      d.debtorConfirmed = true;
    if ( af.idEq(myId, d.creditorId) && !d.creditorConfirmed && d.debtorConfirmed )
      d.creditorConfirmed = true;
    d.isPending = false;
    debts[first][second][index] = d;
  }

  function rejectDebt(bytes32 myId, bytes32 friendId, uint debtId) debtIndices(myId, friendId) isIdOwner(msg.sender, myId) {
    uint index;
    bool success;
    (index, success) = findPendingDebt(myId, friendId, debtId);
    if ( ! success ) return;
    Debt memory d = debts[first][second][index];
    d.isPending = false;
    d.isRejected = true;
    d.debtorConfirmed = false;
    d.creditorConfirmed = false;
    debts[first][second][index] = d;
  }

  /***********  Helpers  ************/
/*
  function getMyFoundationId() constant returns (bytes32 foundationId) {
    return af.resolveToName(msg.sender);
  }

  function idMember(bytes32 s, bytes32[] l) constant returns(bool) {
    for ( uint i=0; i<l.length; i++ ) {
      if ( af.idEq(l[i], s)) return true;
    }
    return false;
  }

  function currencyMember(bytes32 s, bytes32[] l) constant returns(bool) {
    for ( uint i=0; i<l.length; i++ ) {
      if ( af.idEq(l[i], s)) return true;
    }
    return false;
  }

  //returns false for success if debt not found
  //only returns pending, non-rejected debts
  function findPendingDebt(bytes32 p1, bytes32 p2, uint debtId) debtIndices(p1, p2) private constant returns (uint index, bool success) {
    bytes32 f = p1;
    bytes32 s = p2;
    if ( debts[f][s].length == 0 ) {
      f = p2;
      s = p1;
    }
    for(uint i=0; i<debts[f][s].length; i++) {
      if( debts[f][s][i].id == debtId && debts[f][s][i].isPending
          && ! debts[f][s][i].isRejected )
        return (i, true);
    }
    return (i, false);
  }
}
*/