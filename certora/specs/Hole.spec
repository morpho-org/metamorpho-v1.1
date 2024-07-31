// SPDX-License-Identifier: GPL-2.0-or-later

using Util as Util;

rule holeIncreases(method f, env e, calldataarg args) {
    uint256 holeBefore = hole();

    f(e, args);

    uint256 holeAfter = hole();

    assert holeBefore <= holeAfter;
}
