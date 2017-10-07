pragma solidity ^0.4.15;

import "blockmason-solidity-libs/contracts/Parentable.sol";

contract FriendData is Parentable {

  /*  Friend  */
  struct Friend {
    bytes32 ucac;
    bool initialized;
    bytes32 f1Id;
    bytes32 f2Id;
    bool isPending;
    bool isMutual;
    bool f1Confirmed;
    bool f2Confirmed;
  }

  //below are mapped by UCAC Id
  mapping ( bytes32 => mapping ( bytes32 => bytes32[] )) public friendIdList;
  mapping ( bytes32 => mapping ( bytes32 => mapping ( bytes32 => Friend ))) public friendships;

  /*
     temporary variables to hold indices
   */
  bytes32 f;
  bytes32 s;
  /* Flux helpers */
  function friendIndices(bytes32 ucac, bytes32 p1, bytes32 p2) private constant returns (bytes32, bytes32) {
    if ( friendships[ucac][p1][p2].initialized )
      return (p1, p2);
    else
      return (p2, p1);
  }

  /* Friend Getters */
  function numFriends(bytes32 ucac, bytes32 fId) public constant returns (uint) {
    return friendIdList[ucac][fId].length;
  }
  function friendIdByIndex(bytes32 ucac, bytes32 fId, uint index) public constant returns (bytes32) {
    return friendIdList[ucac][fId][index];
  }

  function fInitialized(bytes32 ucac, bytes32 p1, bytes32 p2) public constant returns (bool) {
    (f, s) = friendIndices(ucac, p1, p2);
    return friendships[ucac][f][s].initialized;
  }
  function ff1Id(bytes32 ucac, bytes32 p1, bytes32 p2) public constant returns (bytes32) {
    (f, s) = friendIndices(ucac, p1, p2);
    return friendships[ucac][f][s].f1Id;
  }
  function ff2Id(bytes32 ucac, bytes32 p1, bytes32 p2) public constant returns (bytes32) {
    (f, s) = friendIndices(ucac, p1, p2);
    return friendships[ucac][f][s].f2Id;
  }
  function fIsPending(bytes32 ucac, bytes32 p1, bytes32 p2) public constant returns (bool) {
    (f, s) = friendIndices(ucac, p1, p2);
    return friendships[ucac][f][s].isPending;
  }
  function fIsMutual(bytes32 ucac, bytes32 p1, bytes32 p2) public constant returns (bool) {
    (f, s) = friendIndices(ucac, p1, p2);
    return friendships[ucac][f][s].isMutual;
  }
  function ff1Confirmed(bytes32 ucac, bytes32 p1, bytes32 p2) public constant returns (bool) {
    (f, s) = friendIndices(ucac, p1, p2);
    return friendships[ucac][f][s].f1Confirmed;
  }
  function ff2Confirmed(bytes32 ucac, bytes32 p1, bytes32 p2) public constant returns (bool) {
    (f, s) = friendIndices(ucac, p1, p2);
    return friendships[ucac][f][s].f2Confirmed;
  }

  /* Friend Setters */

  function pushFriendId(bytes32 ucac, bytes32 myId, bytes32 friendId) public onlyParent  {
    friendIdList[ucac][myId].push(friendId);
  }
  function setFriendIdByIndex(bytes32 ucac, bytes32 myId, uint idx, bytes32 newFriendId) public onlyParent {
    friendIdList[ucac][myId][idx] = newFriendId;
  }

  function fSetInitialized(bytes32 ucac, bytes32 p1, bytes32 p2, bool initialized) public onlyParent {
    (f, s) = friendIndices(ucac, p1, p2);
    friendships[ucac][f][s].initialized = initialized;
  }
  function fSetf1Id(bytes32 ucac, bytes32 p1, bytes32 p2, bytes32 id) public onlyParent {
    (f, s) = friendIndices(ucac, p1, p2);
    friendships[ucac][f][s].f1Id = id;
  }
  function fSetf2Id(bytes32 ucac, bytes32 p1, bytes32 p2, bytes32 id) public onlyParent {
    (f, s) = friendIndices(ucac, p1, p2);
    friendships[ucac][f][s].f2Id = id;
  }
  function fSetIsPending(bytes32 ucac, bytes32 p1, bytes32 p2, bool isPending) public onlyParent {
    (f, s) = friendIndices(ucac, p1, p2);
    friendships[ucac][f][s].isPending = isPending;
  }
  function fSetIsMutual(bytes32 ucac, bytes32 p1, bytes32 p2, bool isMutual) public onlyParent {
    (f, s) = friendIndices(ucac, p1, p2);
    friendships[ucac][f][s].isMutual = isMutual;
  }
  function fSetf1Confirmed(bytes32 ucac, bytes32 p1, bytes32 p2, bool f1Confirmed) public onlyParent {
    (f, s) = friendIndices(ucac, p1, p2);
    friendships[ucac][f][s].f1Confirmed = f1Confirmed;
  }
  function fSetf2Confirmed(bytes32 ucac, bytes32 p1, bytes32 p2, bool f2Confirmed) public onlyParent {
    (f, s) = friendIndices(ucac, p1, p2);
    friendships[ucac][f][s].f2Confirmed = f2Confirmed;
  }

  /* batch functions */

  function initFriendship(bytes32 _ucacId, bytes32 myId, bytes32 friendId) public onlyParent {
    (f, s) = friendIndices(_ucacId, myId, friendId);
    friendships[_ucacId][f][s].initialized = true;
    friendships[_ucacId][f][s].f1Id = myId;
    friendships[_ucacId][f][s].f2Id = friendId;
    friendships[_ucacId][f][s].isPending = true;
    friendships[_ucacId][f][s].f1Confirmed = true;

    fd.fSetInitialized(_ucacId, myId, friendId, true);
    fd.fSetf1Id(_ucacId, myId, friendId, myId);
    fd.fSetf2Id(_ucacId, myId, friendId, friendId);
    fd.fSetIsPending(_ucacId, myId, friendId, true);
    fd.fSetf1Confirmed(_ucacId, myId, friendId, true);

    friendIdList[ucac][myId].push(friendId);
    friendIdList[ucac][friendId].push(myId);
  }

}
