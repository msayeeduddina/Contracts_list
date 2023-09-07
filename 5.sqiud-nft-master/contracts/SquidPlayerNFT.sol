// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract SquidPlayerNFT is
    Initializable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    bytes32 public constant SE_BOOST_ROLE = keccak256("SE_BOOST_ROLE");
    bytes32 public constant TOKEN_FREEZER = keccak256("TOKEN_FREEZER");
    bytes32 public constant COLLECTIBLES_CHANGER = keccak256("COLLECTIBLES_CHANGER");

    string private _internalBaseURI;
    uint private _lastTokenId;
    uint128[5] private _rarityLimitsSE; //SE limit to each rarity

    struct Token {
        uint8 rarity; //Token rarity (Star)
        uint32 createTimestamp;
        uint32 busyTo; //Timestamp to which the token is busy
        uint32 contractEndTimestamp; //Timestamp to which the token has game contract
        uint128 squidEnergy; // in 1e18 340282366920938463463e18 max
        bool stakeFreeze; //Freeze token when staking
    }

    struct TokensViewFront {
        uint tokenId;
        uint8 rarity;
        address tokenOwner;
        uint128 squidEnergy;
        uint128 maxSquidEnergy;
        uint32 contractEndTimestamp;
        uint32 contractV2EndTimestamp;
        uint32 busyTo; //Timestamp until which the player is busy
        uint32 createTimestamp;
        bool stakeFreeze;
        string uri;
        bool contractBought;
    }

    mapping(uint => Token) private _tokens; // TokenId => Token

    //for decrease SE when token lock
    uint128 public seDivide; //base 10000
    uint public gracePeriod; //45d = 3 888 000; Period in seconds when SE didnt decrease after game
    bool public enableSeDivide; //enabled decrease SE

    uint public mintLockDuration; // lock time after mint in seconds
    uint public mintLockStartTime; // timestamp after which mint lock time enabled

    mapping(uint => bool) public contractBought; // Buying player contract tokenId => true/false

    mapping(uint => uint32) public contractV2EndTimestamp; //TokenId => contractV2EndTimestamp

    event Initialize(string baseURI);
    event TokenMint(address indexed to, uint indexed tokenId, uint8 rarity, uint128 squidEnergy);
    event TokensLock(uint[] _tokenId, uint32 busyTo, uint128[] decreaseSE);
    event SEIncrease(uint[] _tokenId, uint128[] addition);
    event NewContract(uint[] _tokenId, uint32[] contractEndTimestamp);
    event ChangeSEDivideState(bool state, uint seDivide, uint gracePeriod);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(string memory baseURI, uint128 _seDivide, uint _gracePeriod, bool _enableSeDivide) public initializer {
        __ERC721_init("Biswap Squid Players", "BSP"); //("Biswap Squid Players", "BSP"); //BSP - Biswap Squid Players
        __ERC721Enumerable_init();
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _rarityLimitsSE[0] = 600 ether;
        _rarityLimitsSE[1] = 1400 ether;
        _rarityLimitsSE[2] = 2000 ether;
        _rarityLimitsSE[3] = 2700 ether;
        _rarityLimitsSE[4] = 4000 ether;

        _internalBaseURI = baseURI;
        seDivide = _seDivide;
        gracePeriod = _gracePeriod;
        enableSeDivide = _enableSeDivide;
        emit Initialize(baseURI);
    }

    //External functions --------------------------------------------------------------------------------------------

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _internalBaseURI = newBaseUri;
    }

    function setRarityLimitsTable(uint128[5] calldata newRarityLimits) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rarityLimitsSE = newRarityLimits;
    }

    function setSeDivide(
        bool _enableSeDivide,
        uint128 _seDivide,
        uint _gracePeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        //MSG-01
        require(seDivide <= 10000, "Wrong seDivide parameter. Must be less or equal than 10000");
        enableSeDivide = _enableSeDivide;
        seDivide = _seDivide;
        gracePeriod = _gracePeriod;

        emit ChangeSEDivideState(_enableSeDivide, _seDivide, _gracePeriod);
    }

    function setMintLockTime(uint _mintLockTimeDuration, uint _mintLockStartTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintLockDuration = _mintLockTimeDuration;
        mintLockStartTime = _mintLockStartTime;
    }

    function tokenFreeze(uint _tokenId) external onlyRole(TOKEN_FREEZER) {
        require(!_tokens[_tokenId].stakeFreeze, "ERC721: Token already frozen");
        // Clear all approvals when freeze token
        _approve(address(0), _tokenId);

        _tokens[_tokenId].stakeFreeze = true;
    }

    function tokenUnfreeze(uint _tokenId) external onlyRole(TOKEN_FREEZER) {
        require(_tokens[_tokenId].stakeFreeze, "ERC721: Token already unfrozen");
        _tokens[_tokenId].stakeFreeze = false;
    }

    function getSEAmountFromTokensId(uint[] calldata _tokenId) external view returns(uint totalSeAmount, uint[] memory tokenSeAmount){
        totalSeAmount = 0;
        tokenSeAmount = new uint[](_tokenId.length);
        for(uint i = 0; i < _tokenId.length; i++){
            require(_exists(_tokenId[i]), "ERC721: token does not exist");
            tokenSeAmount[i] = _tokens[_tokenId[i]].squidEnergy;
            totalSeAmount += _tokens[_tokenId[i]].squidEnergy;
        }
    }

    function burnForCollectibles(address user, uint[] calldata tokenId)
        external
        onlyRole(COLLECTIBLES_CHANGER)
        returns (uint burnedSEAmount)
    {
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            require(ownerOf(tokenId[i]) == user, "Not token owner");
            Token memory curToken = _tokens[tokenId[i]];
            burnedSEAmount += curToken.squidEnergy;
            _burn(tokenId[i]);
        }
        return burnedSEAmount;
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function mint(
        address to,
        uint128 squidEnergy,
        uint32 contractEndTimestamp,
        uint8 rarity
    ) public onlyRole(TOKEN_MINTER_ROLE) nonReentrant {
        require(to != address(0), "Address can not be zero");
        require(rarity < _rarityLimitsSE.length, "Wrong rarity");
        require(squidEnergy <= _rarityLimitsSE[rarity], "Squid energy over rarity limit");
        _lastTokenId += 1;
        uint tokenId = _lastTokenId;
        _tokens[tokenId].rarity = rarity;
        _tokens[tokenId].squidEnergy = squidEnergy;
        _tokens[tokenId].createTimestamp = uint32(block.timestamp);
        _tokens[tokenId].contractEndTimestamp = contractEndTimestamp;
        _safeMint(to, tokenId);
    }

    function burn(uint _tokenId) public {
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Not token owner");
        _burn(_tokenId);
    }

    function getToken(uint _tokenId) public view returns (TokensViewFront memory) {
        require(_exists(_tokenId), "ERC721: token does not exist");
        Token memory token = _tokens[_tokenId];
        TokensViewFront memory tokenReturn;
        tokenReturn.tokenId = _tokenId;
        tokenReturn.rarity = token.rarity;
        tokenReturn.tokenOwner = ownerOf(_tokenId);
        tokenReturn.squidEnergy = token.squidEnergy;
        tokenReturn.maxSquidEnergy = _rarityLimitsSE[token.rarity];
        tokenReturn.contractEndTimestamp = token.contractEndTimestamp;
        tokenReturn.contractV2EndTimestamp = contractV2EndTimestamp[_tokenId];
        tokenReturn.busyTo = token.busyTo;
        tokenReturn.stakeFreeze = token.stakeFreeze;
        tokenReturn.createTimestamp = token.createTimestamp;
        tokenReturn.uri = tokenURI(_tokenId);
        tokenReturn.contractBought = contractBought[_tokenId];
        return (tokenReturn);
    }

    //returns locked SE amount
    function lockTokens(
        uint[] calldata tokenId,
        uint32 busyTo,
        bool willDecrease, //will decrease SE or not
        address user,
        uint contractVersion
    ) public onlyRole(GAME_ROLE) returns (uint128) {
        uint128 seAmount;
        uint128[] memory SEAfterDec = new uint128[](tokenId.length);
        for (uint i = 0; i < tokenId.length; i++) {
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            uint128 curSEAmount;
            (curSEAmount, SEAfterDec[i]) = _lockToken(tokenId[i], busyTo, willDecrease, contractVersion);
            seAmount += curSEAmount;
        }
        emit TokensLock(tokenId, busyTo, SEAfterDec);
        return seAmount;
    }

    function setPlayerContract(uint[] calldata tokenId, uint32 contractDuration, address user, uint contractVersion) public onlyRole(GAME_ROLE) {
        uint32[] memory contractEndTimestamp = new uint32[](tokenId.length);
        for (uint i = 0; i < tokenId.length; i++) {
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            if(contractVersion == 1){
                contractEndTimestamp[i] = _setPlayerContract(tokenId[i], contractDuration);
            } else if(contractVersion == 2){
                contractEndTimestamp[i] = _setPlayerContractV2(tokenId[i], contractDuration);
            } else {
                revert("Wrong contract version");
            }
        }
        emit NewContract(tokenId, contractEndTimestamp);
    }

    function squidEnergyDecrease(uint[] calldata tokenId, uint128[] calldata deduction, address user) public onlyRole(SE_BOOST_ROLE) {
        require(tokenId.length == deduction.length, "Wrong calldata array size");
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            require(!_tokens[tokenId[i]].stakeFreeze, "ERC721: Token frozen");
            require(_tokens[tokenId[i]].squidEnergy >= deduction[i], "Wrong deduction value");
            _tokens[tokenId[i]].squidEnergy -= deduction[i];
        }
    }

    function squidEnergyIncrease(uint[] calldata tokenId, uint128[] calldata addition, address user) public onlyRole(SE_BOOST_ROLE) {
        require(tokenId.length == addition.length, "Wrong calldata array size");
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            require(!_tokens[tokenId[i]].stakeFreeze, "ERC721: Token frozen");
            Token storage curToken = _tokens[tokenId[i]];
            require((curToken.squidEnergy + addition[i]) <= _rarityLimitsSE[curToken.rarity], "Wrong addition value");
            curToken.squidEnergy += addition[i];
        }
        emit SEIncrease(tokenId, addition);
    }

    function arrayUserPlayers(address _user) public view returns (TokensViewFront[] memory) {
        if (balanceOf(_user) == 0) return new TokensViewFront[](0);
        return arrayUserPlayers(_user, 0, balanceOf(_user) - 1);
    }

    function arrayUserPlayers(
        address _user,
        uint _from,
        uint _to
    ) public view returns (TokensViewFront[] memory) {
        //SPN-01
        require(_to < balanceOf(_user), "Wrong max array value");
        require((_to - _from) <= balanceOf(_user), "Wrong array range");
        TokensViewFront[] memory tokens = new TokensViewFront[](_to - _from + 1);
        uint index = 0;
        for (uint i = _from; i <= _to; i++) {
            uint id = tokenOfOwnerByIndex(_user, i);
            tokens[index] = getToken(id);
            index++;
        }
        return (tokens);
    }

    function arrayUserPlayersWithValidContracts(address _user) public view returns (TokensViewFront[] memory) {
        if (balanceOf(_user) == 0) return new TokensViewFront[](0);
        return arrayUserPlayersWithValidContracts(_user, 0, balanceOf(_user) - 1);
    }

    function arrayUserPlayersWithValidContracts(
        address _user,
        uint _from,
        uint _to
    ) public view returns (TokensViewFront[] memory) {
        //SPN-01
        require(_to < balanceOf(_user), "Wrong max array value");
        require((_to - _from) <= balanceOf(_user), "Wrong array range");
        uint[] memory index = new uint[](_to - _from + 1);
        uint count = 0;
        for (uint i = _from; i <= _to; i++) {
            uint id = tokenOfOwnerByIndex(_user, i);
            if (getToken(id).contractEndTimestamp > block.timestamp) {
                index[count] = id;
                count++;
            }
        }
        TokensViewFront[] memory tokensView = new TokensViewFront[](count);
        for (uint i = 0; i < count; i++) {
            tokensView[i] = getToken(index[i]);
        }
        return (tokensView);
    }

    function availableSEAmount(address _user) public view returns (uint128 amount) {
        for (uint i = 0; i < balanceOf(_user); i++) {
            Token memory curToken = _tokens[tokenOfOwnerByIndex(_user, i)];
            if (
                curToken.contractEndTimestamp > block.timestamp &&
                curToken.busyTo < block.timestamp &&
                !curToken.stakeFreeze
            ) {
                amount += curToken.squidEnergy;
            }
        }
        return amount;
    }

    function availableSEAmountV2(address _user) public view returns (uint128 amount) {
        for (uint i = 0; i < balanceOf(_user); i++) {
            uint tokenId = tokenOfOwnerByIndex(_user, i);
            Token memory curToken = _tokens[tokenId];
            if (
                contractV2EndTimestamp[tokenId] > block.timestamp &&
                curToken.busyTo < block.timestamp &&
                !curToken.stakeFreeze
            ) {
                amount += curToken.squidEnergy;
            }
        }
        return amount;
    }

    function totalSEAmount(address _user) public view returns (uint128 amount) {
        for (uint i = 0; i < balanceOf(_user); i++) {
            Token memory curToken = _tokens[tokenOfOwnerByIndex(_user, i)];
            amount += curToken.squidEnergy;
        }
        return amount;
    }

    function approve(address to, uint tokenId) public override {
        require(!_tokens[tokenId].stakeFreeze, "ERC721: Token frozen");
        super.approve(to, tokenId);
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }

    function _burn(uint tokenId) internal override {
        super._burn(tokenId);
        delete _tokens[tokenId];
    }

    function _safeMint(address to, uint tokenId) internal override {
        super._safeMint(to, tokenId);
        emit TokenMint(to, tokenId, _tokens[tokenId].rarity, _tokens[tokenId].squidEnergy);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable) {
        if(_tokens[tokenId].createTimestamp > mintLockStartTime && from != address(0) && to != address(0))
            require((block.timestamp - _tokens[tokenId].createTimestamp) >= mintLockDuration, "mint lock time not ended");

        require(!_tokens[tokenId].stakeFreeze, "ERC721: Token frozen");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _lockToken(uint _tokenId, uint32 _busyTo, bool willDecrease, uint contractVersion) private returns (uint128 SEAmount, uint128 currentSE) {
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(_busyTo > block.timestamp, "Busy to block must be greater than current block timestamp");
        Token storage _token = _tokens[_tokenId];
        require(!_token.stakeFreeze, "Token frozen");
        require(_token.busyTo < block.timestamp, "Token already busy");
        if(contractVersion == 1){
            require(_token.contractEndTimestamp > block.timestamp, "Token hasnt valid contract");
        } else if(contractVersion == 2){
            require(contractV2EndTimestamp[_tokenId] > block.timestamp, "Token hasnt valid contract");
        } else {
            revert("Wrong contract version");
        }
        _token.busyTo = _busyTo;
        bool gracePeriodHasPassed = (block.timestamp - _token.createTimestamp) >= gracePeriod;
        uint128 _seDivide = enableSeDivide && gracePeriodHasPassed && willDecrease ? seDivide : 0;
        uint128 decreaseSE;
        SEAmount = _token.squidEnergy;
        decreaseSE = (SEAmount * _seDivide) / 10000;
        _token.squidEnergy -= decreaseSE;
        return (SEAmount, _token.squidEnergy);
    }

    function _setPlayerContract(uint _tokenId, uint32 _contractDuration) private returns(uint32 _contractEndTimestamp){
        Token storage _token = _tokens[_tokenId];
        require(!_token.stakeFreeze, "Token frozen");
        require(!contractBought[_tokenId], "Contract already bought");
        contractBought[_tokenId] = true;
        if(_token.contractEndTimestamp <= block.timestamp){
            _contractEndTimestamp = uint32(block.timestamp) + _contractDuration;
            _token.contractEndTimestamp = _contractEndTimestamp;
        } else {
            _contractEndTimestamp = _token.contractEndTimestamp + _contractDuration;
            _token.contractEndTimestamp = _contractEndTimestamp;
        }
    }

    function _setPlayerContractV2(uint _tokenId, uint32 _contractDuration) private returns(uint32 _contractEndTimestamp){
        require(!_tokens[_tokenId].stakeFreeze, "Token frozen");
        require(_tokens[_tokenId].contractEndTimestamp < block.timestamp, "Contract V1 not finished");
        require(contractV2EndTimestamp[_tokenId] <= uint32(block.timestamp), "Previous contract does not finished");
        _contractEndTimestamp = uint32(block.timestamp) + _contractDuration;
        contractV2EndTimestamp[_tokenId] = _contractEndTimestamp;
    }
}
