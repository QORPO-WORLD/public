// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

abstract contract NFTContract {
    function _finalizeNewToken(uint256[] memory randoms) public virtual returns (uint256 newIndex);
}


contract VRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    address nftAddress = address(0);
    mapping(address => bool) internal authorizedUsers;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    bytes32 keyHash =
        0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;

    // Storing each word costs about 20,000 gas.
    uint32 callbackGasLimit = 350000;
    uint16 requestConfirmations = 3;
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 3;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(0x6A2AAd07396B36Fe02a22b33cf443582f682c82f) ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(0x6A2AAd07396B36Fe02a22b33cf443582f682c82f);
        s_subscriptionId = subscriptionId;
    }

    function requestRandomWords() external returns (uint256 requestId)
    {
        require(authorizedUsers[msg.sender], "You are not an authorized user !");
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function setNftAddress(address _addr) external {
        nftAddress = _addr;
    }

    function setAuthorizedUsers(address _user, bool _approve) onlyOwner external {
        if (_approve) {
            authorizedUsers[_user] = true;
        } else {
            delete authorizedUsers[_user];
        }
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);

        NFTContract nft_contract = NFTContract(nftAddress);
        nft_contract._finalizeNewToken(_randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}
