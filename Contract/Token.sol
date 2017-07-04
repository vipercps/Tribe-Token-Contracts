pragma solidity ^0.4.11;

import "./StandardToken.sol";
import "./Own.sol";

contract Token is StandardToken, Own {
  string public constant name = "TRIBE";
  string public constant symbol = "TRIBE";
  uint public constant decimals = 6;

  // Token constructor
  function Token() {
      totalSupply = 200000000000000;
      balances[msg.sender] = totalSupply; // send all created tokens to the owner/creator
  }

  // Burn function to burn a set amount of tokens
  function burn(uint _value) onlyOwner returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    totalSupply = totalSupply.sub(_value);
    Transfer(msg.sender, 0x0, _value);
    return true;
  }

}
