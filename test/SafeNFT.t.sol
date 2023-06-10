// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SafeNFT.sol";
import "safe-contracts/Safe.sol";
import "safe-contracts/proxies/SafeProxy.sol";

contract SafeNFTTest is Test {
    address public safeImplementation;
    Safe public avatar;
    SafeNFT public safeNFT;

    address account1 = address(0xF1);
    address account2 = address(0xF2);

    function setUp() public {
        safeImplementation = address(new Safe());
        avatar = Safe(payable(address(new SafeProxy(safeImplementation))));

        address[] memory owners = new address[](2);
        owners[0] = account1;
        owners[1] = account2;

        avatar.setup(
            owners,
            1, //threshold
            address(0), //to
            "", //data
            address(0),//fallback handler
            address(0),//paymentToken
            0,//payment
            payable(address(0))//paymentReceiver
        );

        safeNFT = new SafeNFT("name", "symbol");

        // Add safeNFT as a module
        execCall(
            account1,
            address(avatar),
            abi.encodeWithSelector(IAvatar.enableModule.selector, address(safeNFT))
        );
    }

    function testMint() public {
        // Mint NFT
        // safeNFT.mint(account1);
        execCall(
            account1,
            address(safeNFT),
            abi.encodeWithSelector(SafeNFT.mint.selector, account1)
        );

        assertEq(account1, safeNFT.ownerOf(1));
        assertEq(safeNFT.balanceOf(account1), 1);

        address[] memory owners = avatar.getOwners();
        assertEq(owners.length, 1);
        assertEq(owners[0], safeNFT.PLACEHOLDER_OWNER());
        (address[] memory modules, address next) = avatar.getModulesPaginated(address(0x1), 20);
        assertEq(modules.length, 1);
        assertEq(modules[0], address(safeNFT));
    }

    function testBurn() public {
        // Mint NFT
        // safeNFT.mint(account1);
        execCall(
            account1,
            address(safeNFT),
            abi.encodeWithSelector(SafeNFT.mint.selector, account1)
        );

        address[] memory owners = new address[](2);
        owners[0] = account1;
        owners[1] = account2;

        // Burn NFT
        // safeNFT.burn(1);
        vm.prank(account1);
        safeNFT.burn(1, owners, 1);

        address[] memory avatarOwners = avatar.getOwners();
        assertEq(avatarOwners.length, 2);
        assertEq(avatarOwners[1], account1);
        assertEq(avatarOwners[0], account2);
        assertEq(safeNFT.balanceOf(account1), 0);
        // TODO check mappings cleaned up
        (address[] memory modules, address next) = avatar.getModulesPaginated(address(0x1), 20);
        assertEq(modules.length, 0);
    }

    function execCall(address signer, address to, bytes memory data) public {
        vm.prank(signer);
        avatar.execTransaction(
            to,
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            getSig(signer)
        );
    }

    function getSig(address signer) public returns(bytes memory) {
        return abi.encodePacked(
            uint256(uint160(signer)),
            uint256(0),
            uint8(1)
        );
    }

    function testMintModuleNotAdded() public {
        // 
    }
}
