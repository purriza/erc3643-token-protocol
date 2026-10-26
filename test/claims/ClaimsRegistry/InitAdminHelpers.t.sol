// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ClaimsRegistry} from "../../../src/claims/ClaimsRegistry.sol";
import {TrustedIssuersRegistry} from "../../../src/claims/TrustedIssuersRegistry.sol";
import {TopicCatalog} from "../../../src/claims/TopicCatalog.sol";
import {IClaimsRegistry} from "../../../src/interfaces/IClaimsRegistry.sol";

contract ClaimsRegistryInitAdminHelpersTest is Test {
    address internal admin = makeAddr("admin");
    address internal complianceAdmin = makeAddr("complianceAdmin");
    address internal other = makeAddr("other");

    ClaimsRegistry internal claimsRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    TopicCatalog internal topicCatalog;

    function setUp() public {
        TrustedIssuersRegistry issuersImpl = new TrustedIssuersRegistry();
        ERC1967Proxy issuersProxy = new ERC1967Proxy(
            address(issuersImpl), abi.encodeCall(TrustedIssuersRegistry.initialize, (admin, complianceAdmin))
        );
        trustedIssuersRegistry = TrustedIssuersRegistry(address(issuersProxy));

        TopicCatalog catalogImpl = new TopicCatalog();
        ERC1967Proxy catalogProxy =
            new ERC1967Proxy(address(catalogImpl), abi.encodeCall(TopicCatalog.initialize, (admin)));
        topicCatalog = TopicCatalog(address(catalogProxy));

        ClaimsRegistry impl = new ClaimsRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(
                ClaimsRegistry.initialize, (admin, complianceAdmin, address(trustedIssuersRegistry), address(topicCatalog))
            )
        );
        claimsRegistry = ClaimsRegistry(address(proxy));
    }

    function test_Initialize_RevertsWhenAdminIsZeroAddress() public {
        ClaimsRegistry impl = new ClaimsRegistry();
        vm.expectRevert(IClaimsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(
                ClaimsRegistry.initialize, (address(0), complianceAdmin, address(trustedIssuersRegistry), address(topicCatalog))
            )
        );
    }

    function test_Initialize_RevertsWhenComplianceAdminIsZeroAddress() public {
        ClaimsRegistry impl = new ClaimsRegistry();
        vm.expectRevert(IClaimsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(
                ClaimsRegistry.initialize, (admin, address(0), address(trustedIssuersRegistry), address(topicCatalog))
            )
        );
    }

    function test_Initialize_RevertsWhenTrustedIssuersRegistryIsZeroAddress() public {
        ClaimsRegistry impl = new ClaimsRegistry();
        vm.expectRevert(IClaimsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(ClaimsRegistry.initialize, (admin, complianceAdmin, address(0), address(topicCatalog)))
        );
    }

    function test_Initialize_RevertsWhenTopicCatalogIsZeroAddress() public {
        ClaimsRegistry impl = new ClaimsRegistry();
        vm.expectRevert(IClaimsRegistry.ZeroAddress.selector);
        new ERC1967Proxy(
            address(impl),
            abi.encodeCall(
                ClaimsRegistry.initialize, (admin, complianceAdmin, address(trustedIssuersRegistry), address(0))
            )
        );
    }

    function test_Upgrade_RevertsWhenCallerIsNotUpgrader() public {
        ClaimsRegistry newImplementation = new ClaimsRegistry();
        vm.prank(other);
        vm.expectRevert();
        claimsRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_Upgrade_SucceedsWhenCallerHasUpgraderRole() public {
        ClaimsRegistry newImplementation = new ClaimsRegistry();
        vm.prank(admin);
        claimsRegistry.upgradeToAndCall(address(newImplementation), bytes(""));
    }
}
