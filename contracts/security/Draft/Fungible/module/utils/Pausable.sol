// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract Pausable {
    bool private _isPaused;

    event Paused();
    event Unpaused();

    // error paused
    error PausedError(string err);

    function pause() external {
        _isPaused = true;
        emit Paused();
    }

    function unpause() external {
        _isPaused = false;
        emit Unpaused();
    }

    modifier isPaused() {
        if (_isPaused) {
            revert PausedError("paused");
        }
        _;
    }
}
