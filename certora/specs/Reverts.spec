// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function isAllocator(address) external returns(bool) envfree;
    function skimRecipient() external returns(address) envfree;
    function fee() external returns(uint96) envfree;
    function feeRecipient() external returns(address) envfree;
    function guardian() external returns(address) envfree;
    function pendingGuardian() external returns(address, uint64) envfree;
}

rule setCuratorRevertCondition(env e, address newCurator) {
    address owner = owner();
    address oldCurator = curator();

    setCurator@withrevert(e, newCurator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newCurator == oldCurator;
}

rule setIsAllocatorRevertCondition(env e, address newAllocator, bool newIsAllocator) {
    address owner = owner();
    bool wasAllocator = isAllocator(newAllocator);

    setIsAllocator@withrevert(e, newAllocator, newIsAllocator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newIsAllocator == wasAllocator;
}

rule setSkimRecipientRevertCondition(env e, address newSkimRecipient) {
    address owner = owner();
    address oldSkimRecipient = skimRecipient();

    setSkimRecipient@withrevert(e, newSkimRecipient);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newSkimRecipient == oldSkimRecipient;
}

rule setFeeRevertCondition(env e, uint256 newFee) {
    address owner = owner();
    uint96 oldFee = fee();
    address feeRecipient = feeRecipient();

    setFee@withrevert(e, newFee);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newFee == assert_uint256(oldFee) ||
        (newFee != 0 && feeRecipient == 0);
}

rule setFeeRecipientRevertCondition(env e, address newFeeRecipient) {
    address owner = owner();
    uint96 fee = fee();
    address oldFeeRecipient = feeRecipient();

    setFeeRecipient@withrevert(e, newFeeRecipient);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newFeeRecipient == oldFeeRecipient ||
        (fee != 0 && newFeeRecipient == 0);
}

rule submitGuardianRevertCondition(env e, address newGuardian) {
    address owner = owner();
    address oldGuardian = guardian();
    address pendingGuardian;
    pendingGuardian, _ = pendingGuardian();

    submitGuardian@withrevert(e, newGuardian);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newGuardian == oldGuardian ||
        pendingGuardian != 0;
}
