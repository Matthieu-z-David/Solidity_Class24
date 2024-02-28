// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
 

contract CoinFlip is Initializable, OwnableUpgradeable, UUPSUpgradeable, VRFConsumerBase {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        setVRFCoordinator(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625); // Set the VRFCoordinator address
        setLinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789); // Set the Link token address
        keyHash = keccak256("CoinFlipKeyHash"); // Generate a unique key hash for the contract
        fee = 0.1 * 10 ** 18; // Set the fee to 0.1 LINK
    }

    function _authorizeUpgrade(address newImplementation)
        internal onlyOwner override
    {}

    event FlipResult(uint256 userAddress, bool result);

    function flipCoin(bool playerGuess) external payable {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");

        bytes32 requestId = requestRandomness(keyHash, fee);

        while (randomResult == uint256(-1)) {
            pause();
            (_ , _, randomResult, ) = checkUpkeep("CheckAndUpdateFlip");
            if (randomResult != uint256(-1)) {
                unpause();
            }
        }

        require(randomResult < 1 || randomResult > 0, "Error generating random number.");

        emit FlipResult(msg.sender, randomResult == 1 == playerGuess);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness % 2; // Simplified coin flip logic
    }

    function fundContractWithLink() external payable {
        LINK.transferFrom(msg.sender, address(this), msg.value);
    }

    function CheckAndUpdateFlip() external view override returns (bool){
        (,,randomResult,_) = getRandomness();
        if(randomResult != uint256(-1)){
            return true;
        }
        return false;
    }

    function getChainlinkToken() external view override returns (ILinkToken){
        return ILinkToken(LINK);
    }
} 

// Our contract passess various LLM, which globally validates it
// Neverthless it fails to compile due to last function which is essential 
// Idea of getChainlinkToken function is to return the address of the LINK token contract that the user interact with to pay for 
// VRF requests, as we implement the direct funding method