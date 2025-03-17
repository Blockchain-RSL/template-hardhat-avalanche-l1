// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./RestrictionsLayer1.sol";

contract CustomStablecoin is ERC20, Pausable {

    address private _restrictionsSmartContract;

    /**
     * @dev Modifier to restrict access to only admins.
     */
    modifier onlyRegistrar() virtual {
        if(
            !RestrictionsLayer1(_restrictionsSmartContract).hasRole(
                RestrictionsLayer1(_restrictionsSmartContract).ADMIN(),
                msg.sender
            )
        ) {
            revert InvalidRegistrar("Caller is not a admin", msg.sender);
        }
          
        _;
    }

    event ForceTransfer(address indexed from, address indexed to, uint256 amount);

    error AccountNotWhitelisted(string message, address account);
    error InvalidRegistrar(string message, address caller);

    constructor(string memory name_, string memory symbol_, address restrictionsSmartContract_) ERC20(name_, symbol_) {
        _restrictionsSmartContract = restrictionsSmartContract_;
    }

    function balanceOf(address account_) public view override returns (uint256) {
        if(!_isWhitelisted(msg.sender)) {
            revert AccountNotWhitelisted("Caller is not whitelisted", msg.sender);
        }

        return super.balanceOf(account_);
    }

    function totalSupply() public view override returns (uint256) {
        if(!_isWhitelisted(msg.sender)) {
            revert AccountNotWhitelisted("Caller is not whitelisted", msg.sender);
        }

        return super.totalSupply();
    }

    function setRestrictionsSmartContract(address restrictionsSmartContract_) external onlyRegistrar {
        _restrictionsSmartContract = restrictionsSmartContract_;
    }

    function transfer(address to_, uint256 amount_) public override whenNotPaused returns (bool) {
        if(!_isWhitelisted(msg.sender)) {
            revert AccountNotWhitelisted("Caller is not whitelisted", msg.sender);
        }
        if(!_isWhitelisted(to_)) {
            revert AccountNotWhitelisted("Recipient is not whitelisted", to_);
        }

        return super.transfer(to_, amount_);
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override whenNotPaused returns (bool) {
        if(!_isWhitelisted(from_)) {
            revert AccountNotWhitelisted("Sender is not whitelisted", from_);
        }
         if(!_isWhitelisted(to_)) {
            revert AccountNotWhitelisted("Recipient is not whitelisted", to_);
        }

        return super.transferFrom(from_, to_, amount_);
    }

    function mint(address account_, uint256 amount_) external onlyRegistrar {
        if(!_isWhitelisted(account_)) {
            revert AccountNotWhitelisted("Recipient is not whitelisted", account_);
        }
        _mint(account_, amount_);
    }

    function burn(address account_, uint256 amount_) external onlyRegistrar {
        _burn(account_, amount_);
    }

    function forceTransfer(address from_, address to_, uint256 amount_) external onlyRegistrar {
        if(!_isWhitelisted(from_)) {
            revert AccountNotWhitelisted("Sender is not whitelisted", from_);
        }
         if(!_isWhitelisted(to_)) {
            revert AccountNotWhitelisted("Recipient is not whitelisted", to_);
        }

        _transfer(from_, to_, amount_);

        emit ForceTransfer(from_, to_, amount_);
    }

    function pause() external onlyRegistrar {
        _pause();
    }

    function unpause() external onlyRegistrar {
        _unpause();
    }

    function _isWhitelisted(address account_) internal view returns (bool) {
        return RestrictionsLayer1(_restrictionsSmartContract).isWhitelisted(account_);
    }
}