// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {OrderBook} from "../src/OrderBook.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockWBTC} from "./mocks/MockWBTC.sol";
import {MockWETH} from "./mocks/MockWETH.sol";
import {MockWSOL} from "./mocks/MockWSOL.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestOrderBook is Test {
    OrderBook book;

    MockUSDC usdc;
    MockWBTC wbtc;
    MockWETH weth;
    MockWSOL wsol;

    address owner;
    address alice;
    address bob;
    address clara;
    address dan;

    uint256 mdd;

    function setUp() public {
        owner = makeAddr("protocol_owner");
        alice = makeAddr("will_sell_wbtc_order");
        bob = makeAddr("will_sell_weth_order");
        clara = makeAddr("will_sell_wsol_order");
        dan = makeAddr("will_buy_orders");

        usdc = new MockUSDC(6);
        wbtc = new MockWBTC(8);
        weth = new MockWETH(18);
        wsol = new MockWSOL(18);

        vm.prank(owner);
        book = new OrderBook(address(weth), address(wbtc), address(wsol), address(usdc), owner);

        usdc.mint(dan, 200_000);
        wbtc.mint(alice, 2);
        weth.mint(bob, 2);
        wsol.mint(clara, 2);

        mdd = book.MAX_DEADLINE_DURATION();
    }

    function test_init() public view {
        assert(usdc.balanceOf(dan) == 200_000e6);
        assert(wbtc.balanceOf(alice) == 2e8);
        assert(weth.balanceOf(bob) == 2e18);
        assert(wsol.balanceOf(clara) == 2e18);

        assert(mdd == 3 days);
    }

    function test_createSellOrder() public {
        // alice creates sell order for wbtc
        vm.startPrank(alice);
        wbtc.approve(address(book), 2e8);
        uint256 aliceId = book.createSellOrder(address(wbtc), 2e8, 180_000e6, 2 days);
        vm.stopPrank();

        assert(aliceId == 1);
        assert(wbtc.balanceOf(alice) == 0);
        assert(wbtc.balanceOf(address(book)) == 2e8);

        // bob creates sell order for weth
        vm.startPrank(bob);
        weth.approve(address(book), 2e18);
        uint256 bobId = book.createSellOrder(address(weth), 2e18, 5_000e6, 2 days);
        vm.stopPrank();

        assert(bobId == 2);
        assert(weth.balanceOf(bob) == 0);
        assert(weth.balanceOf(address(book)) == 2e18);

        // clara creates sell order for wsol
        vm.startPrank(clara);
        wsol.approve(address(book), 2e18);
        uint256 claraId = book.createSellOrder(address(wsol), 2e18, 300e6, 2 days);
        vm.stopPrank();

        assert(claraId == 3);
        assert(wsol.balanceOf(clara) == 0);
        assert(wsol.balanceOf(address(book)) == 2e18);
    }

    function test_amendSellOrder() public {
        // alice creates sell order for wbtc
        vm.startPrank(alice);
        wbtc.approve(address(book), 2e8);
        uint256 aliceId = book.createSellOrder(address(wbtc), 2e8, 180_000e6, 2 days);
        vm.stopPrank();

        // bob creates sell order for weth
        vm.startPrank(bob);
        weth.approve(address(book), 2e18);
        uint256 bobId = book.createSellOrder(address(weth), 2e18, 5_000e6, 2 days);
        vm.stopPrank();

        // clara creates sell order for wsol
        vm.startPrank(clara);
        wsol.approve(address(book), 2e18);
        uint256 claraId = book.createSellOrder(address(wsol), 2e18, 300e6, 2 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        // alice amends her wbtc sell order
        vm.prank(alice);
        book.amendSellOrder(aliceId, 1.75e8, 175_000e6, 0.5 days);
        string memory aliceOrderDetails = book.getOrderDetailsString(aliceId);
        console2.log(aliceOrderDetails);
        assert(wbtc.balanceOf(alice) == 0.25e8);
        assert(wbtc.balanceOf(address(book)) == 1.75e8);

        // bob amends his weth order
        vm.prank(bob);
        book.amendSellOrder(bobId, 1.75e18, 4_550e6, 0.5 days);
        string memory bobOrderDetails = book.getOrderDetailsString(bobId);
        console2.log(bobOrderDetails);
        assert(weth.balanceOf(bob) == 0.25e18);
        assert(weth.balanceOf(address(book)) == 1.75e18);

        // clara amends her wsol order
        vm.prank(clara);
        book.amendSellOrder(claraId, 1.75e18, 350e6, 0.5 days);
        string memory claraOrderDetails = book.getOrderDetailsString(claraId);
        console2.log(claraOrderDetails);
        assert(wsol.balanceOf(clara) == 0.25e18);
        assert(wsol.balanceOf(address(book)) == 1.75e18);
    }

    function test_cancelSellOrder() public {
        // alice creates sell order for wbtc
        vm.startPrank(alice);
        wbtc.approve(address(book), 2e8);
        uint256 aliceId = book.createSellOrder(address(wbtc), 2e8, 180_000e6, 2 days);
        vm.stopPrank();

        // bob creates sell order for weth
        vm.startPrank(bob);
        weth.approve(address(book), 2e18);
        uint256 bobId = book.createSellOrder(address(weth), 2e18, 5_000e6, 2 days);
        vm.stopPrank();

        // clara creates sell order for wsol
        vm.startPrank(clara);
        wsol.approve(address(book), 2e18);
        uint256 claraId = book.createSellOrder(address(wsol), 2e18, 300e6, 2 days);
        vm.stopPrank();

        // alice cancels wbtc sell order
        vm.prank(alice);
        book.cancelSellOrder(aliceId);

        // bob cancels weth order
        vm.prank(bob);
        book.cancelSellOrder(bobId);

        // clara cancels sell order
        vm.prank(clara);
        book.cancelSellOrder(claraId);
    }

    function test_buyOrder() public {
        // alice creates sell order for wbtc
        vm.startPrank(alice);
        wbtc.approve(address(book), 2e8);
        uint256 aliceId = book.createSellOrder(address(wbtc), 2e8, 180_000e6, 2 days);
        vm.stopPrank();

        assert(aliceId == 1);
        assert(wbtc.balanceOf(alice) == 0);
        assert(wbtc.balanceOf(address(book)) == 2e8);

        // bob creates sell order for weth
        vm.startPrank(bob);
        weth.approve(address(book), 2e18);
        uint256 bobId = book.createSellOrder(address(weth), 2e18, 5_000e6, 2 days);
        vm.stopPrank();

        assert(bobId == 2);
        assert(weth.balanceOf(bob) == 0);
        assert(weth.balanceOf(address(book)) == 2e18);

        // clara creates sell order for wsol
        vm.startPrank(clara);
        wsol.approve(address(book), 2e18);
        uint256 claraId = book.createSellOrder(address(wsol), 2e18, 300e6, 2 days);
        vm.stopPrank();

        vm.startPrank(dan);
        usdc.approve(address(book), 200_000e6);
        book.buyOrder(aliceId); // dan buys alice wbtc order
        book.buyOrder(bobId); // dan buys bob weth order
        book.buyOrder(claraId); // dan buys clara wsol order
        vm.stopPrank();

        assert(wbtc.balanceOf(dan) == 2e8);
        assert(weth.balanceOf(dan) == 2e18);
        assert(wsol.balanceOf(dan) == 2e18);

        assert(usdc.balanceOf(alice) == 174_600e6);
        assert(usdc.balanceOf(bob) == 4_850e6);
        assert(usdc.balanceOf(clara) == 291e6);

        assert(book.totalFees() == 5_559e6);

        vm.prank(owner);
        book.withdrawFees(owner);

        assert(usdc.balanceOf(owner) == 5_559e6);
    }

    //@audit-poc 
    function test_precision_loss_in_fee_calculation() external {
        //Arrange
        vm.startPrank(alice);
        wbtc.approve(address(book), 2e8);
        uint256 aliceId = book.createSellOrder(address(wbtc), 2e8, 0.000033e6, 2 days);
        vm.stopPrank();

        //Act
        uint256 orderInUSDC = book.getOrder(aliceId).priceInUSDC;
        uint256 protocolFee = (orderInUSDC * book.FEE()) / book.PRECISION();
        
        //Assert
        assertEq(protocolFee, 0);
    }

    //@audit-poc
    function test_seller_at_loss_than_buyer() external {
        vm.startPrank(alice);
        wbtc.approve(address(book), 2e8);
        uint256 aliceId = book.createSellOrder(address(wbtc), 2e8, 180_000e6, 2 days);

        uint256 orderInUSDC = book.getOrder(aliceId).priceInUSDC;
        uint256 protocolFee = (orderInUSDC * book.FEE()) / book.PRECISION();
        vm.stopPrank();
        assertEq(wbtc.balanceOf(alice), 0);

        vm.startPrank(dan);
        usdc.approve(address(book), 180_000e6);
        book.buyOrder(aliceId);
        vm.stopPrank();

        assertEq(wbtc.balanceOf(dan), 2e8);
        assert(usdc.balanceOf(alice) == 174_600e6);
        assert(usdc.balanceOf(address(book)) == protocolFee);
    }

    //@audit-poc
    function test_Allow_Random_Address_As_Token_Address() external {
        vm.prank(owner);
        vm.expectEmit();
        //using a random non-erc20 address - address(1)
        emit OrderBook.TokenAllowed(address(1), true);
        book.setAllowedSellToken(address(1), true);
    }

    //@audit-poc
    function test_Decimal_Precision_Bug() public {
        console2.log("=== DEMONSTRATING DECIMAL PRECISION ===");

        // Alice creates orders for 1 WBTC and 1 WETH, both priced at $50,000 USDC
        uint256 priceInUSDC = 50000e6; // $50,000 USDC

        // WBTC order: 1 WBTC = 100000000 (8 decimals)
        uint256 wbtcAmount = 1e8;
        vm.startPrank(alice);
        wbtc.approve(address(book), wbtcAmount);
        uint256 wbtcOrderId = book.createSellOrder(address(wbtc), wbtcAmount, priceInUSDC, 3600);
        vm.stopPrank();

        // WETH order: 1 WETH = 1000000000000000000 (18 decimals)
        uint256 wethAmount = 1e18;
        vm.startPrank(bob);
        weth.approve(address(book), wethAmount);
        uint256 wethOrderId = book.createSellOrder(address(weth), wethAmount, priceInUSDC, 3600);
        vm.stopPrank();

        // Get order details
        (,,, uint256 storedWbtcAmount, uint256 wbtcPrice,,) = book.orders(wbtcOrderId);
        (,,, uint256 storedWethAmount, uint256 wethPrice,,) = book.orders(wethOrderId);

        console2.log("WBTC Order - Amount:", storedWbtcAmount);
        console2.log("WBTC Order - Price:", wbtcPrice);
        console2.log("WETH Order - Amount:", storedWethAmount);
        console2.log("WETH Order - Price:", wethPrice);

        // Calculate price per token unit (this shows the bug)
        // Note: WETH calculation will result in 0 due to integer division
        uint256 wbtcPricePerUnit = wbtcPrice / storedWbtcAmount;
        uint256 wethPricePerUnit = wethPrice / storedWethAmount; // This will be 0!

        console2.log("WBTC Price per unit:", wbtcPricePerUnit);
        console2.log("WETH Price per unit:", wethPricePerUnit);

        // The bug: WETH price per unit becomes 0 due to integer division
        // while WBTC has a meaningful price per unit
        assertEq(wethPricePerUnit, 0);
        assertGt(wbtcPricePerUnit, 0);

        console2.log("WETH price per unit is 0, while WBTC has meaningful price!");
    }
    
    //@audit-poc
    function testEmergencyWithdraw() external {
        TestToken token = new TestToken();

        vm.prank(owner);
        book.setAllowedSellToken(address(token), true);

        vm.startPrank(alice);
        token.mint(alice, 2e18);
        token.approve(address(book), 2e18);
        book.createSellOrder(address(token), 2e18, 3000e6, 3600);
        vm.stopPrank();

        assertEq(token.balanceOf(address(book)), 2e18);

        vm.prank(owner);
        vm.expectEmit();
        emit OrderBook.EmergencyWithdrawal(address(token), 0, owner);
        book.emergencyWithdrawERC20(address(token), 0, owner);
    }

    //@audit-poc 
    function test_EmergencyWithdrawal_Of_NonCoreTokens() external {
        TestToken token = new TestToken();

        vm.prank(owner);
        book.setAllowedSellToken(address(token), true);

        vm.startPrank(alice);
        token.mint(alice, 2e18);
        token.approve(address(book), 2e18);
        book.createSellOrder(address(token), 2e18, 3000e6, 3600);
        vm.stopPrank();

        assertEq(token.balanceOf(address(book)), 2e18);

        vm.prank(owner);
        vm.expectEmit();
        emit OrderBook.EmergencyWithdrawal(address(token), 2e18, owner);
        book.emergencyWithdrawERC20(address(token), 2e18, owner);

        assertEq(token.balanceOf(address(book)), 0);
        assertEq(token.balanceOf(owner), 2e18);
    }

}

contract TestToken is ERC20 {
    constructor() ERC20("Test", "TT"){
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
