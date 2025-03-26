// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CustomERC20 is ERC20 {
    uint256 private constant _initialSupply = 100e12; // 100 trillion tokens

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    constructor() ERC20("CustomERC20", "CE20") {
        _mint(msg.sender, _initialSupply);
    }
}
