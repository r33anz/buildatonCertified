// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Counter {
    uint256 public count;

    event CountIncreased(uint256 newCount, address sender);

    function increment() external {
        count += 1;
        emit CountIncreased(count, msg.sender);
    }

    function getCount() external view returns (uint256) {
        return count;
    }
}
