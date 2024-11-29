// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// OpenZeppelin ERC20 ve Ownable sözleşmelerini içeri aktar
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ERC20 token kontratını tanımla
contract MccbToken is ERC20, Ownable {
    // Token adı ve sembolünü belirle
    constructor(uint256 initialSupply) ERC20("MccbToken", "MCCB") {
        // Başlangıç arzını sahibine mint et
        _mint(msg.sender, initialSupply);
    }

    // Mint fonksiyonu: Yeni token üretme
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount); // Belirtilen adrese yeni token ekler
    }

    // Burn fonksiyonu: Token yakma (görünürlük açısından public yapmadık çünkü kullanıcılar yalnızca kendi token'larını yakabilir)
    function burn(uint256 amount) public {
        _burn(msg.sender, amount); // Gönderen kişinin balance'ından yakma işlemi yapar
    }
}
