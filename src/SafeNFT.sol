// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/utils/ReentrancyGuard.sol";
import "./lib/IAvatar.sol";

// TODO consider checkiing a whitelist of SAFE implementation contracts to prevent malicious safes misrepresenting themselves

contract SafeNFT is ERC721, ReentrancyGuard {
    address public constant PLACEHOLDER_OWNER = address(0x2);

    mapping(uint256 => address) public tokenToAvatar;
    mapping(address => uint256) public avatarToSafe; 

    uint256 counter;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {

    }

    function _allowed(uint256 id) internal view {
        address from = _ownerOf[id];

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );
    }

    function mint(address receiver) external nonReentrant {
        uint256 tokenId = ++counter;
        tokenToAvatar[tokenId] = msg.sender;
        avatarToSafe[msg.sender] = tokenId;
        IAvatar avatar = IAvatar(msg.sender);
        
        // Cannot be already tokenised because the avatar itself needs to send the tx

        // Wipe all modules except this one
        (address[] memory modules, ) = avatar.getModulesPaginated(address(0x1), type(uint256).max);

        // remove back to start
        for(uint256 i = modules.length - 1; i >= 0; i++) {
            address module = modules[i];

            // Skip if this contract
            if(module == address(this)) {
                continue;
            }
            // Sentinel module is indexed -1 in the linked list
            address prevModule = i == 0 ? address(0x1) : modules[i-1];

            // avatar.disableModule(prevModule, module);
            bytes memory data = abi.encodeWithSelector(IAvatar.disableModule.selector, prevModule, module);
            avatar.execTransactionFromModule(msg.sender, 0, data, Enum.Operation.Call);
        }


        address[] memory owners = avatar.getOwners();

        // Remove owners except for the first
        for(uint256 i = 1; i < owners.length; i ++) {
            address owner = owners[i];
            address prevOwner = owners[i-1];

            // avatar.removeOwner(prevOwner, owner, 0);
            bytes memory data = abi.encodeWithSelector(IAvatar.removeOwner.selector, prevOwner, owner, 0);
            avatar.execTransactionFromModule(msg.sender, 0, data, Enum.Operation.Call);
        }

        {
            // replace first owner
            // avatar.swapOwner(address(0x1), owners[0], PLACEHOLDER_OWNER)
            bytes memory data = abi.encodeWithSelector(IAvatar.swapOwner.selector, address(0x1), owners[0], PLACEHOLDER_OWNER);
            avatar.execTransactionFromModule(msg.sender, 0, data, Enum.Operation.Call);
        }
    

        // Mint NFT
        _mint(receiver, tokenId);
    }

    function burn(uint256 id, address[] calldata owners, uint256 threshold) external nonReentrant {
        IAvatar avatar = IAvatar(tokenToAvatar[id]);
        _allowed((id));
        // Burn NFT
        _burn(id);
        // reset mapping
        tokenToAvatar[id] = address(0);

        // Set owners
        // replace first owner
        // avatar.swapOwner(address(0x1), PLACEHOLDER_OWNER, owners[0])
        {
            bytes memory data = abi.encodeWithSelector(IAvatar.swapOwner.selector, address(0x1), PLACEHOLDER_OWNER, owners[0]);
            avatar.execTransactionFromModule(address(avatar), 0, data, Enum.Operation.Call);
        }

        // Add remaining owners 
        for(uint256 i = 1; i < owners.length; i ++) {
            // avatar.addOwnerWithThreshold(owners[i], threshold);
            bytes memory data = abi.encodeWithSelector(IAvatar.addOwnerWithThreshold.selector, owners[i], threshold);
            avatar.execTransactionFromModule(address(avatar), 0, data, Enum.Operation.Call);
        }

        // Disable this module
        {
            // avatar.disableModule(address(0x1), address(this));
            bytes memory data = abi.encodeWithSelector(IAvatar.disableModule.selector, address(0x1), address(this));
            avatar.execTransactionFromModule(address(avatar), 0 , data, Enum.Operation.Call);
        }

    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        // TODO implement this
        return "";
    }
}