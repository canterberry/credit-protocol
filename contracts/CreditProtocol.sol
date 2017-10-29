pragma solidity 0.4.15;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "tce-contracts/contracts/CPToken.sol";
import "./BasicUCAC.sol";

contract CreditProtocol is Ownable {
    using SafeMath for uint256;

    struct Ucac {
        address ucacContractAddr;
        uint256 totalStakedTokens;
        uint256 txLevel;
        uint256 lastTxTimestamp;
        bytes32 denomination;
    }

    CPToken public token;
    uint256 public txPerGigaTokenPerHour; // gigatoken = 10 ^ 9 nominal tokens
    uint256 public tokensToOwnUcac;

    mapping (bytes32 => Ucac) public ucacs; // ucacId -> Ucac struct

    // ucacId -> token owner address -> amount of tokens
    mapping (bytes32 => mapping (address => uint256)) public stakedTokensMap;

    // id -> id -> # of transactions in all UCACs
    // lesser id is must always be the first argument
    mapping(address => mapping(address => uint256)) public nonces;
    // ucac -> id -> balance
    mapping(bytes32 => mapping(address => int256)) public balances;

    // the standard prefix appended to 32-byte-long messages when signed by an
    // Ethereum client
    bytes prefix = "\x19Ethereum Signed Message:\n32";

    event IssueCredit(bytes32 indexed ucac, address indexed creditor, address indexed debtor, uint256 amount);
    event UcacCreation(bytes32 indexed ucac, address indexed contractAddr, bytes32 denomination);

    function CreditProtocol(address _tokenContract, uint256 _txPerGigaTokenPerHour, uint256 _tokensToOwnUcac) {
        token = CPToken(_tokenContract);
        txPerGigaTokenPerHour = _txPerGigaTokenPerHour;
        tokensToOwnUcac = _tokensToOwnUcac;
    }

    function getNonce(address p1, address p2) public constant returns (uint256) {
        return p1 < p2 ? nonces[p1][p2] : nonces[p2][p1];
    }

    function issueCredit( bytes32 ucac, address creditor, address debtor, uint256 amount
                        , bytes32 sig1r, bytes32 sig1s, uint8 sig1v
                        , bytes32 sig2r, bytes32 sig2s, uint8 sig2v
                        ) public {
        require(creditor != debtor);

        bytes32 hash = keccak256(prefix, keccak256(ucac, creditor, debtor, amount, getNonce(creditor, debtor)));

        // verifying signatures
        require(ecrecover(hash, sig1v, sig1r, sig1s) == creditor);
        require(ecrecover(hash, sig2v, sig2r, sig2s) == debtor);

        // checking for overflow
        require(balances[ucac][creditor] < balances[ucac][creditor] + int256(amount));
        // checking for underflow
        require(balances[ucac][debtor] > balances[ucac][debtor] - int256(amount));
        // executeUcacTx will throw if a transaction limit has been reached or the ucac is uninitialized
        executeUcacTx(ucac);
        // check that UCAC contract approves the transaction
        require(BasicUCAC(getUcacAddr(ucac)).allowTransaction(creditor, debtor, amount));

        balances[ucac][creditor] = balances[ucac][creditor] + int256(amount);
        balances[ucac][debtor] = balances[ucac][debtor] - int256(amount);
        IssueCredit(ucac, creditor, debtor, amount);
        incrementNonce(creditor, debtor);
    }

    function incrementNonce(address p1, address p2) private {
        if (p1 < p2) {
            nonces[p1][p2] = nonces[p1][p2] + 1;
        } else {
            nonces[p2][p1] = nonces[p2][p1] + 1;
        }
    }

    // Staking

    function getUcacAddr(bytes32 _ucacId) public constant returns (address) {
        return ucacs[_ucacId].ucacContractAddr;
    }

    function setTxPerGigaTokenPerHour(uint256 _txPerGigaTokenPerHour) public onlyOwner {
        txPerGigaTokenPerHour = _txPerGigaTokenPerHour;
    }

    function setTokensToOwnUcac(uint256 _tokensToOwnUcac) public onlyOwner {
        tokensToOwnUcac = _tokensToOwnUcac;
    }

    function currentTxLevel(bytes32 _ucacId) public constant returns (uint256) {
        uint256 totalStaked = ucacs[_ucacId].totalStakedTokens;
        uint256 currentDecay = totalStaked / 3600 * (now - ucacs[_ucacId].lastTxTimestamp);
        uint256 adjustedTxLevel = ucacs[_ucacId].txLevel < currentDecay ? 0 : ucacs[_ucacId].txLevel - currentDecay;
        return adjustedTxLevel;
    }

    function executeUcacTx(bytes32 _ucacId) public {
        uint256 txLevelBeforeCurrentTx = currentTxLevel(_ucacId);
        uint256 txLevelAfterCurrentTx = txLevelBeforeCurrentTx + 10 ** 27 / txPerGigaTokenPerHour;
        require(ucacs[_ucacId].totalStakedTokens >= txLevelAfterCurrentTx);
        ucacs[_ucacId].lastTxTimestamp = now;
        ucacs[_ucacId].txLevel = txLevelAfterCurrentTx;
    }

    /**
       @dev msg.sender must have approved Stake contract to transfer **exactly** `_tokensToStake` tokens.
            This design decision is a security precaution since this is a public function and it is desirable
            to have the token owner to control exactly how many tokens can be transferred to `Stake.sol`,
            regardless of who calls the function.
     **/
    function createAndStakeUcac( address _ucacContractAddr, bytes32 _ucacId
                               , bytes32 _denomination, uint256 _tokensToStake) public {
        // check that _ucacContractAddr points to something meaningful
        require(_ucacContractAddr != address(0));
        // check that _ucacId does not point to an extant UCAC
        require(ucacs[_ucacId].totalStakedTokens == 0 && ucacs[_ucacId].ucacContractAddr == address(0));
        // checking that initial token staking amount is enough to own a UCAC
        require(_tokensToStake >= tokensToOwnUcac);
        stakeTokensInternal(_ucacId, msg.sender, _tokensToStake);
        ucacs[_ucacId].ucacContractAddr = _ucacContractAddr;
        ucacs[_ucacId].denomination = _denomination;
        UcacCreation(_ucacId, _ucacContractAddr, _denomination);
    }

    /* Token staking functionality */

    /**
       @dev msg.sender must have approved Stake contract to transfer **exactly** `_numTokens` tokens
     **/
    function stakeTokens(bytes32 _ucacId, address _stakeholder, uint256 _numTokens) public {
        // check that _ucacId points to an extant UCAC
        require(ucacs[_ucacId].ucacContractAddr != address(0));
        stakeTokensInternal(_ucacId, _stakeholder, _numTokens);
    }

    /**
       @notice Checks if this address is already in this name.
       @param _ucacId Id of the ucac tokens are staked to
       @param _numTokens Number of tokens the user wants to unstake
     **/
    function unstakeTokens(bytes32 _ucacId, uint256 _numTokens) public {
        // SafeMath will throw if _numTokens is greater than a sender's stakedTokens amount
        uint256 updatedStakedTokens = stakedTokensMap[_ucacId][msg.sender].sub(_numTokens);
        stakedTokensMap[_ucacId][msg.sender] = updatedStakedTokens;
        uint256 updatedNumTokens = ucacs[_ucacId].totalStakedTokens.sub(_numTokens);
        ucacs[_ucacId].totalStakedTokens = updatedNumTokens;
        token.transfer(msg.sender, _numTokens);
    }

    // Private Functions

    function stakeTokensInternal(bytes32 _ucacId, address _stakeholder, uint256 _numTokens) private {
        require(token.allowance(_stakeholder, this) == _numTokens);
        token.transferFrom(_stakeholder, this, _numTokens);
        uint256 updatedStakedTokens = stakedTokensMap[_ucacId][_stakeholder].add(_numTokens);
        stakedTokensMap[_ucacId][_stakeholder] = updatedStakedTokens;
        uint256 updatedNumTokens =  ucacs[_ucacId].totalStakedTokens.add(_numTokens);
        ucacs[_ucacId].totalStakedTokens = updatedNumTokens;
    }

}
