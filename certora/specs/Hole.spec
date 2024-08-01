// SPDX-License-Identifier: GPL-2.0-or-later

import "Range.spec";

rule holeIncreases(method f, env e, calldataarg args) {
    uint256 holeBefore = hole();

    f(e, args);

    uint256 holeAfter = hole();

    assert holeBefore <= holeAfter;
}

// rule totalAssetsIncreases(method f, env e, calldataarg args) {
//     uint256 totalAssetsBefore = totalAssets();

//     require f != withdraw;

//     f(e, args);

//     uint256 totalAssetsAfter = totalAssets();

//     assert totalAssetsBefore <= totalAssetsAfter;
// }
