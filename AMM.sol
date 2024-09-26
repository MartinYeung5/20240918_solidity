// Task3-實現一個AMM流動性池
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleSwap is ERC20 {
    // 設置2個代幣的合約
    IERC20 public token0;
    IERC20 public token1;

    // 設置代幣數量
    uint public reserve0;
    uint public reserve1;
    
    // Event
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1);
    event Swap(
        address indexed sender,
        uint amountIn,
        address tokenIn,
        uint amountOut,
        address tokenOut
        );

    // 初始化代幣地址
    constructor(IERC20 _token0, IERC20 _token1) ERC20("AMM", "AMM") {
        token0 = _token0;
        token1 = _token1;
    }

    // 取兩個數的最小值
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // 計算平方根
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // 增加流動性，轉進代幣，鑄造LP
    // @param amount0Desired 
    // @param amount1Desired 
    function addLiquidity(uint amount0Desired, uint amount1Desired) public returns(uint liquidity){
        // 將增加的流動性轉入Swap合約，需事先給Swap合約授權
        token0.transferFrom(msg.sender, address(this), amount0Desired);
        token1.transferFrom(msg.sender, address(this), amount1Desired);
        // 計算增加的流動性
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            // 第一次增加流動性，鑄造 L = sqrt(x * y) 單位的LP（流動性提供者）代幣
            liquidity = sqrt(amount0Desired * amount1Desired);
        } else {
            // 按增加代幣的數量比例鑄造LP，取兩個代幣更小的那個比例
            liquidity = min(amount0Desired * _totalSupply / reserve0, amount1Desired * _totalSupply /reserve1);
        }

        // 檢查鑄造的LP數量
        require(liquidity > 0, 'INSUFFICIENT_LIQUIDITY_MINTED');

        // 更新
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        // 給流動性提供者鑄造LP代幣，代表他們提供的流動性
        _mint(msg.sender, liquidity);
        
        emit Mint(msg.sender, amount0Desired, amount1Desired);
    }

    // 移除流動性，銷毀LP，轉出代幣
    // @param liquidity 
    function removeLiquidity(uint liquidity) external returns (uint amount0, uint amount1) {
        // 獲取余額
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));
        // 按LP的比例計算要轉出的代幣數量
        uint _totalSupply = totalSupply();
        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;
        // 檢查代幣數量
        require(amount0 > 0 && amount1 > 0, 'INSUFFICIENT_LIQUIDITY_BURNED');
        // 銷毀LP
        _burn(msg.sender, liquidity);
        // 轉出代幣
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
        // 更新
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Burn(msg.sender, amount0, amount1);
    }

    // 給定一個資產的數量和代幣對的儲備，計算交換另一個代幣的數量
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        amountOut = amountIn * reserveOut / (reserveIn + amountIn);
    }

    // swap代幣
    // @param amountIn 
    // @param tokenIn 
    // @param amountOutMin 
    function swap(uint amountIn, IERC20 tokenIn, uint amountOutMin) external returns (uint amountOut, IERC20 tokenOut){
        require(amountIn > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(tokenIn == token0 || tokenIn == token1, 'INVALID_TOKEN');
        
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        if(tokenIn == token0){
            // token0交換token1
            tokenOut = token1;
            // 計算能交換出的token1數量
            amountOut = getAmountOut(amountIn, balance0, balance1);
            require(amountOut > amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
            // 進行交換
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut);
        }else{
            // token1交換token0
            tokenOut = token0;
            // 計算能交換出的token0數量
            amountOut = getAmountOut(amountIn, balance1, balance0);
            require(amountOut > amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
            // 進行交換
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut);
        }

        // 更新
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Swap(msg.sender, amountIn, address(tokenIn), amountOut, address(tokenOut));
    }
}