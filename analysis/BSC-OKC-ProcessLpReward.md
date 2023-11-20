# BSC OKC MinerReward ProcessLpReward() exploit

### Contracts
[OKC token](https://bscscan.com/address/0xabba891c633fb27f8aa656ea6244dedb15153fe0#code)    
[OKC MinerPool](https://bscscan.com/address/0x36016C4F0E0177861E6377f73C380c70138E13EE#code)  
[BSC-USDT:OKC PancakePool](https://bscscan.com/address/0x9cc7283d8f8b92654e6097aca2acb9655fd5ed96#code)

### OKC Token Analysis
```
constructor() ERC20("OKC", "OKC") {
        ...
        require(USDT < address(this),"token0 must be usdt");
        
        // Creates a new PancakeSwap pair using PancakeRouter
        uniswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapFactory(IUniswapV2Router02(uniswapRouter).factory()).createPair(address(this), USDT);

        lpRewardProcessor = new LPRewardProcessor(USDT,uniswapV2Pair);
        pool = new MinerPool(address(this), address(lpRewardProcessor));
        ...
    }
```

The MinerPool Contract

```
contract MinerPool {
    IERC20 public token;

    mapping(address => bool)public admins;

    uint256 public rewardRate = 10;

    ILPRewardProcessor public lpRewardProcessor;

    uint256 public lastProcessTimestamp;

    modifier onlyAdmin(){
        require(admins[msg.sender],"only admin!");
        _;
    }

    constructor(address _token,address _lpRewardProcessor) {
        token = IERC20(_token);
        lpRewardProcessor = ILPRewardProcessor(_lpRewardProcessor);
        admins[msg.sender] = true;
        admins[tx.origin] = true;
    }

    receive() external payable {
        processLPReward();
    }

    function processLPReward() public {
        if(lastProcessTimestamp + 24 hours > block.timestamp) return;

        uint256 lpHolderCount = lpRewardProcessor.getLength();
        address pair = lpRewardProcessor.getPair();
        uint256 pairTotalSupply = ISwapPair(pair).totalSupply();
        uint256 pairTokenBalance = IERC20(ISwapPair(pair).token1()).balanceOf(address(this));
        if(lpHolderCount == 0 ) return;
        if(token.balanceOf(address(this)) == 0) return;

        for(uint256 i=0; i<lpHolderCount; i++){
            address _addr = lpRewardProcessor.holders(i);
            uint256 _lpBal = IERC20(pair).balanceOf(_addr);

            uint256 amount = pairTokenBalance * _lpBal / pairTotalSupply;

            token.transfer(_addr, amount * 1 / 100);
        }

        lastProcessTimestamp = block.timestamp;
    }
}
```

Taking a closer look its possible to trigger the processLpReward() function by sending 1 WEI to the MinerPool contract.  

```
    receive() external payable {
        processLPReward();
    }

    function processLPReward() public {
        if(lastProcessTimestamp + 24 hours > block.timestamp) return;

        uint256 lpHolderCount = lpRewardProcessor.getLength();
        address pair = lpRewardProcessor.getPair();
        uint256 pairTotalSupply = ISwapPair(pair).totalSupply();
        uint256 pairTokenBalance = IERC20(ISwapPair(pair).token1()).balanceOf(address(this));
        if(lpHolderCount == 0 ) return;
        if(token.balanceOf(address(this)) == 0) return;

        for(uint256 i=0; i<lpHolderCount; i++){
            address _addr = lpRewardProcessor.holders(i);
            uint256 _lpBal = IERC20(pair).balanceOf(_addr);

            uint256 amount = pairTokenBalance * _lpBal / pairTotalSupply;

            token.transfer(_addr, amount * 1 / 100);
        }

        lastProcessTimestamp = block.timestamp;
    }
  ```

The goal is now clear: To become an LP for OKC and reap the LP rewards. 

### Attack  
First we need to build a large BSC-USDT position using multiple Flashloan providers.  

The attacker uses multiple [DODOEX flashSwap](https://github.com/DODOEX/docs/blob/2f687d341183cf71ff267dcc4fca5a7d194f5d8c/docs/flashSwap.md?plain=1#L17) implementations for the initial BSC-USDT by chaining the DPPFlashLoanCall callback in order to call additional ```DODOEX flashLoan``` contracts for additional BSC-USDT.  

The attacker chains six BSC-USDT flashloans.  

The first five flashloans come from DODOEX
```
0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d -> 88177739049580517061951 ($88k)
0xFeAFe253802b77456B4627F8c2306a9CeBb5d681 -> 2405831490077590788521  ($2.4k)
0x26d0c625e5F5D6de034495fbDe1F6e9377185618 -> 47814445198579753743246 ($47k)
0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476 -> 84620256046164784063945 ($84k)
0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A -> 30381721225514539668296 ($30k)
```
DODOEX Total: ~$251400+ 

The sixth and final flashloan is using PancakeSwap pancakeV3pool flash() for ```$2,500,000``` BSC-USD.  

Total BSC-USD position: 
2753426503009917185325959 (~$2,753,000)


