# BSC OKC MinerReward ProcessLpReward() exploit

### Quick Nav
[Contracts](https://github.com/lcfr-eth/defihacks/master/analysis/BSC-OKC-ProcessLpReward.md#Contracts)

### Contracts
[OKC token](https://bscscan.com/address/0xabba891c633fb27f8aa656ea6244dedb15153fe0#code)    
[OKC MinerPool](https://bscscan.com/address/0x36016C4F0E0177861E6377f73C380c70138E13EE#code)  
[BSC-USDT:OKC PancakePool](https://bscscan.com/address/0x9cc7283d8f8b92654e6097aca2acb9655fd5ed96#code)

### OKC Token Analysis
```
constructor() ERC20("OKC", "OKC") {
        require(USDT < address(this),"token0 must be usdt");
        
        // Creates a new PancakeSwap pair using PancakeRouter
        uniswapRouter = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapFactory(IUniswapV2Router02(uniswapRouter).factory()).createPair(address(this), USDT);

        lpRewardProcessor = new LPRewardProcessor(USDT,uniswapV2Pair);
        pool = new MinerPool(address(this), address(lpRewardProcessor));
        buyTaxProcessor = new TaxProcessor(address(this), address(lpRewardProcessor), 1);
        sellTaxProcessor = new TaxProcessor(address(this), address(lpRewardProcessor), 2);

        uint256 _decimal = 10 ** uint256(decimals());

        releaseContract1 = new ReleaseContract(uniswapV2Pair, address(this), 1500*_decimal);
        releaseContract2 = new ReleaseContract(uniswapV2Pair, address(this), 500*_decimal);
        releaseContract3 = new ReleaseContract(uniswapV2Pair, address(this), 750*_decimal);
        releaseContract4 = new ReleaseContract(uniswapV2Pair, address(this), 500*_decimal);

        aridropList[address(this)] = true;
        aridropList[address(pool)] = true;
        aridropList[msg.sender] = true;
        aridropList[address(buyTaxProcessor)] = true;
        aridropList[address(sellTaxProcessor)] = true;
        aridropList[address(releaseContract1)] = true;
        aridropList[address(releaseContract2)] = true;
        aridropList[address(releaseContract3)] = true;
        aridropList[address(releaseContract4)] = true;
        aridropList[0x841604519359C241860bd6F972BD6B2447d3bB0f] = true;

        // Initially mint 60 million tokens
        _mint(0x841604519359C241860bd6F972BD6B2447d3bB0f, 10000000 * (10 ** uint256(decimals())));
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
