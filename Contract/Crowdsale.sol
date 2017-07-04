pragma solidity ^0.4.11;


import "./Pause.sol";
import "./Puller.sol";
import "./Token.sol";

contract Crowdsale is Pause, Puller {
    
    using SafeMath for uint;

  	struct Backer {
		uint weiReceived; // Amount of Ether given
		uint coinSent;
	}
    
	//CONSTANTS
	// Minimum number of TRIBE to sell
	uint public constant MIN_CAP = 7500000000000; // 7,500,000 TRIBE
	// Maximum number of TRIBE to sell
	uint public constant MAX_CAP = 150000000000000; // 150,000,000 TRIBE
	// Minimum amount to invest
	uint public constant MIN_INVEST_ETHER = 100 finney;
	// Crowdsale period
	uint private constant CROWDSALE_PERIOD = 30 minutes;
	// Number of TRIBE per Ether
	uint public constant COIN_PER_ETHER = 3000000000; // 3,000 TRIBE


	//VARIABLES
	// TRIBE contract reference
	Token public coin;
    // Multisig contract that will receive the Ether
	address public multisigEther;
	// Number of Ether received
	uint public etherReceived;
	// Number of TRIBE sent to Ether contributors
	uint public coinSentToEther;
	// Crowdsale start time
	uint public startTime;
	// Crowdsale end time
	uint public endTime;
 	// Is crowdsale still on going
	bool public crowdsaleClosed;

	// Backers Ether indexed by their Ethereum address
	mapping(address => Backer) public backers;


	//MODIFIERS
	modifier minCapNotReached() {
		if ((now < endTime) || coinSentToEther >= MIN_CAP ) throw;
		_;
	}

	modifier respectTimeFrame() {
		if ((now < startTime) || (now > endTime )) throw;
		_;
	}

	//EVENTS
	event LogReceivedETH(address addr, uint value);
	event LogCoinsEmited(address indexed from, uint amount);

	//Crowdsale Constructor
	function Crowdsale(address _TRIBEAddress, address _to) {
		coin = Token(_TRIBEAddress);
		multisigEther = _to;
	}

	
	// Default function to receive ether
	function() stopInEmergency respectTimeFrame payable {
		receiveETH(msg.sender);
	}

	 
	// To call to start the crowdsale
	function start() onlyOwner {
		if (startTime != 0) throw; // Crowdsale was already started

		startTime = now ;            
		endTime =  now + CROWDSALE_PERIOD;    
	}

	// Main function on ETH receive
	function receiveETH(address beneficiary) internal {
		if (msg.value < MIN_INVEST_ETHER) throw; // Do not accept investment if the amount is lower than the minimum allowed investment
		
		uint coinToSend = bonus(msg.value.mul(COIN_PER_ETHER).div(1 ether)); // Calculate the amount of tokens to send
		if (coinToSend.add(coinSentToEther) > MAX_CAP) throw;	

		Backer backer = backers[beneficiary];
		coin.transfer(beneficiary, coinToSend); // Transfer TRIBE

		backer.coinSent = backer.coinSent.add(coinToSend);
		backer.weiReceived = backer.weiReceived.add(msg.value); // Update the total wei collected during the crowdfunding for this backer    

		etherReceived = etherReceived.add(msg.value); // Update the total wei collected during the crowdfunding
		coinSentToEther = coinSentToEther.add(coinToSend);

		// Send events
		LogCoinsEmited(msg.sender ,coinToSend);
		LogReceivedETH(beneficiary, etherReceived); 
	}
	

	// Bonus function for the first week
	function bonus(uint amount) internal constant returns (uint) {
		if (now < startTime.add(7 days)) return amount.add(amount.div(5));   // bonus 20%
		return amount;
	}

	// Finalize function
	function finalize() onlyOwner public {

        // Check if the crowdsale has ended or if the old tokens have been sold
		if (now < endTime) {
			if (coinSentToEther == MAX_CAP) {
			} else {
				throw;
			}
		}

		if (coinSentToEther < MIN_CAP && now < endTime + 15 days) throw; // If MIN_CAP is not reached donors have 15days to get refund before we can finalise

		if (!multisigEther.send(this.balance)) throw; // Move the remaining Ether to the multisig address
		
		uint remains = coin.balanceOf(this);
		if (remains > 0) { // Burn the rest of TRIBE
			if (!coin.burn(remains)) throw;
		}
		crowdsaleClosed = true;
	}

	// Function to drain ETH from the contract in case something goes wrong.
	function drain() onlyOwner {
		if (!owner.send(this.balance)) throw;
	}

	// Change multisig wallet in case its needed
	function setMultisig(address addr) onlyOwner public {
		if (addr == address(0)) throw;
		multisigEther = addr;
	}

	// Manually back TRIBE owner address.
	function backTRIBEOwner() onlyOwner public {
		coin.transferOwnership(owner);
	}

	// Transfer remains to owner in case if impossible to do min invest
	function getRemainCoins() onlyOwner public {
		var remains = MAX_CAP - coinSentToEther;
		uint minCoinsToSell = bonus(MIN_INVEST_ETHER.mul(COIN_PER_ETHER) / (1 ether));

		if(remains > minCoinsToSell) throw;

		Backer backer = backers[owner];
		coin.transfer(owner, remains); // Transfer TRIBE right now 

		backer.coinSent = backer.coinSent.add(remains);

		coinSentToEther = coinSentToEther.add(remains);

		// Send events
		LogCoinsEmited(this ,remains);
		LogReceivedETH(owner, etherReceived);
	}


	/* 
  	 * When MIN_CAP is not reach:
  	 * 1) backer call the "approve" function of the TRIBE token contract with the amount of all TRIBE they got in order to be refund
  	 * 2) backer call the "refund" function of the Crowdsale contract with the same amount of TRIBE
   	 * 3) backer call the "withdrawPayments" function of the Crowdsale contract to get a refund in ETH
   	 */
	function refund(uint _value) minCapNotReached public {
		
		if (_value != backers[msg.sender].coinSent) throw; // compare value from backer balance

		coin.transferFrom(msg.sender, address(this), _value); // get the token back to the crowdsale contract

		if (!coin.burn(_value)) throw ; // token sent for refund are burnt

		uint ETHToSend = backers[msg.sender].weiReceived;
		backers[msg.sender].weiReceived=0;

		if (ETHToSend > 0) {
			asyncSend(msg.sender, ETHToSend); // pull payment to get refund in ETH
		}
	}

}
