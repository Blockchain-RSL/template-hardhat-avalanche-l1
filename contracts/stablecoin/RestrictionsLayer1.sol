// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Restrictions
 * @dev This contract defines access control and whitelisting functionality.
 *
 * The contract manages a whitelist of addresses that can be used to control access to specific functionalities.
 * It uses the OpenZeppelin AccessControl and Pausable libraries for access control and pausing functionality.
 */
contract RestrictionsLayer1 is AccessControl, Pausable {
    mapping(address => bool) private whitelist;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant ADMIN_ADMIN = keccak256("ADMIN_ADMIN");

    /**
     * @dev Modifier to restrict access to only admins.
     */
    modifier onlyRegistrar() {
        require(hasRole(ADMIN, msg.sender), "caller is not a admin");
        _;
    }
    // Events

    /**
     * @dev Emitted when new tokens are minted.
     */

    event WhitelistChanged(address[] _address, string change);
    /**
     * @dev Constructor to initialize the contract.
     * It sets up the roles for admins and admin administrators.
     */
    constructor() {
        _setRoleAdmin(ADMIN, ADMIN_ADMIN);

        whitelist[msg.sender] = true;

        _setupRole(ADMIN_ADMIN, msg.sender);
        _setupRole(ADMIN, msg.sender);
    }

    /**
     * @dev Add a new admin with the necessary roles.
     * @param admin_ The address of the new admin.
     */
    function addRegistrar(address admin_) external onlyRegistrar {
        require(whitelist[admin_], "account is not whitelisted");
        _grantRegistrarRoles(admin_);
    }

    /**
     * @dev Remove a admin role of an account.
     * @param account_ The account to remove the admin role.
     */
    function removeRegistrar(address account_) external onlyRegistrar {
        require(
            hasRole(ADMIN, account_),
            "cannot remove role, account is not a admin"
        );
        _revokeRole(ADMIN, account_);
    }

    /**
     * @dev Add multiple addresses to the whitelist.
     * @param addAddresses_ An array of addresses to add to the whitelist.
     */
    function addWhitelistAddress(
        address[] calldata addAddresses_
    ) external onlyRegistrar {
        for (uint i = 0; i < addAddresses_.length; ++i) {
            if (!whitelist[addAddresses_[i]]) {
                whitelist[addAddresses_[i]] = true;
            }
        }
        emit WhitelistChanged(addAddresses_, "Added");
    }

    /**
     * @dev Check if an address is whitelisted.
     * @param _address The address to check.
     * @return True if the address is whitelisted, false otherwise.
     */
    function isWhitelisted(address _address) external view returns (bool) {
        return whitelist[_address];
    }

    function checkWhitelistStatus(
        address[] calldata addresses
    ) external view returns (bool, address[] memory) {
        address[] memory nonWhitelisted = new address[](addresses.length);
        uint256 count = 0;

        for (uint256 i = 0; i < addresses.length; ++i) {
            if (!whitelist[addresses[i]]) {
                nonWhitelisted[count] = addresses[i];
                count++;
            }
        }
        if (count == 0) {
            return (true, new address[](0));
        } else {
            address[] memory result = new address[](count);
            for (uint256 i = 0; i < count; ++i) {
                result[i] = nonWhitelisted[i];
            }
            return (false, result);
        }
    }

    /**
     * @dev Remove multiple addresses from the whitelist.
     * @param removeAddresses_ An array of addresses to remove from the whitelist.
     */
    function removeWhitelistAddress(
        address[] calldata removeAddresses_
    ) external onlyRegistrar {
        for (uint i = 0; i < removeAddresses_.length; ++i) {
            require(
                !hasRole(ADMIN, removeAddresses_[i]),
                "account is assigned to a role"
            );
            if (whitelist[removeAddresses_[i]]) {
                delete whitelist[removeAddresses_[i]];
            }
        }
        emit WhitelistChanged(removeAddresses_, "Removed");
    }

    /**
     * @dev Pause all contract functionality. Can only be called by a admin.
     */
    function pauseAll() public onlyRegistrar {
        _pause();
    }

    /**
     * @dev Unpause all contract functionality. Can only be called by a admin.
     */
    function unpauseAll() public onlyRegistrar {
        _unpause();
    }

    /**
     * @dev Internal function to grant admin roles to an account.
     * @param account_ The address to grant admin roles to.
     */
    function _grantRegistrarRoles(address account_) internal {
        _grantRole(ADMIN, account_);
        _grantRole(ADMIN_ADMIN, account_);
    }
}
