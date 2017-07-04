pragma solidity ^0.4.11;

import "./Own.sol";

contract Pause is Own {
  bool public stopped;

  modifier stopInEmergency {
    if (stopped) {
      throw;
    }
    _;
  }
  
  modifier onlyInEmergency {
    if (!stopped) {
      throw;
    }
    _;
  }

  // owner call to trigger a stop state
  function emergencyStop() external onlyOwner {
    stopped = true;
  }

  // owner call to restart from the stop state
  function release() external onlyOwner onlyInEmergency {
    stopped = false;
  }

}
