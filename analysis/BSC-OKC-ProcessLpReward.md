## BSC OKC MinerReward ProcessLpReward() exploit

## Contracts
OKC token: 0xABba891c633Fb27f8aa656EA6244dEDb15153fE0  
BSC-USD -> OKC PANCAKEPOOL/LP: 0x9cc7283d8f8b92654e6097aca2acb9655fd5ed96  
OKC MinerPool: 0x36016C4F0E0177861E6377f73C380c70138E13EE  

## OKC Token Analysis
```constructor() ERC20("OKC", "OKC") {
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

    function withdrawTo(address destination, uint256 amount) external onlyAdmin {
        uint256 rewardAmount = amount * rewardRate / 1000;

        if(rewardAmount > token.balanceOf(address(this))){
            return;
        }
        require(token.transfer(destination, rewardAmount), "Transfer failed");
    }

    function setToken(address _token) external onlyAdmin{
        token = IERC20(_token);
    }

    function setRate(uint256 _rate) external  onlyAdmin{
        rewardRate = _rate;
    }

    function addAdmin(address account) public onlyAdmin{
        admins[account] = true;
    }

    function removeAdmin(address account) public onlyAdmin{
        admins[account] = false;
    }
}
```

Taking a closer look at this function: 

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

The goal is to become an LP for OKC and reap the rewards. 
