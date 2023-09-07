// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract SquidBusNFT is
    Initializable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER");
    bytes32 public constant COLLECTIBLES_CHANGER = keccak256("COLLECTIBLES_CHANGER");

    uint public minBusBalance; // min bus balance by user on start
    uint public maxBusBalance; // max bus balance after bus addition period
    uint public busAdditionPeriod; // bus addition period in seconds (add 1 bus available to mint after each period)

    string private internalBaseURI;
    uint private lastTokenId;
    uint8 private maxBusLevel; // maximum bus capacity

    struct Token {
        uint8 level; //how many players can fit on the bus
        uint32 createTimestamp;
    }

    mapping(uint => Token) private tokens; // TokenId => Token
    mapping(address => uint) public firstBusTimestamp; //timestamp when user mint first bus

    event Initialize(string baseURI);
    event TokenMint(address indexed to, uint indexed tokenId, uint8 level);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(
        string memory baseURI,
        uint8 _maxBusLevel,
        uint _minBusBalance,
        uint _maxBusBalance,
        uint _busAdditionPeriod
    ) public initializer {
        __ERC721_init("Biswap Squid Buses", "BSB");  //("Biswap Squid Buses", "BSB");//BSB - Biswap Squid Buses
        __ERC721Enumerable_init();
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        internalBaseURI = baseURI;
        maxBusLevel = _maxBusLevel; // 5
        minBusBalance = _minBusBalance; // 2
        maxBusBalance = _maxBusBalance; // 5
        busAdditionPeriod = _busAdditionPeriod; // 604800 for 7 days

        emit Initialize(baseURI);
    }

    //External functions --------------------------------------------------------------------------------------------

    function setBusParameters(
        uint8 _maxBusLevel,
        uint _minBusBalance,
        uint _maxBusBalance,
        uint _busAdditionPeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_maxBusLevel > 0, "maxBusLevel must be > 0");
        require(_maxBusBalance > _minBusBalance, "maxBusBalance must be > minBusBalance");
        require(_busAdditionPeriod > 0, "busAdditionPeriod must be > 0");
        maxBusLevel = _maxBusLevel;
        minBusBalance = _minBusBalance;
        maxBusBalance = _maxBusBalance;
        busAdditionPeriod = _busAdditionPeriod;
    }

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        internalBaseURI = newBaseUri;
    }

    function burnForCollectibles(address user, uint[] calldata tokenId)
        external
        onlyRole(COLLECTIBLES_CHANGER)
        returns (uint burnedBusCapacity)
    {
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            require(ownerOf(tokenId[i]) == user, "Not token owner");
            burnedBusCapacity += tokens[tokenId[i]].level;
            _burn(tokenId[i]);
        }
        return burnedBusCapacity;
    }

    //Public functions --------------------------------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function mint(address _to, uint8 _busLevel) public onlyRole(TOKEN_MINTER_ROLE) nonReentrant {
        require(_to != address(0), "Address can not be zero");
        require(_busLevel <= maxBusLevel, "Volume out of range");
        if (firstBusTimestamp[_to] == 0) {
            firstBusTimestamp[_to] = block.timestamp;
        }
        lastTokenId += 1;
        uint tokenId = lastTokenId;
        tokens[tokenId].level = _busLevel;
        tokens[tokenId].createTimestamp = uint32(block.timestamp);
        _safeMint(_to, tokenId);
    }

    function burn(uint _tokenId) public {
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Not token owner");
        _burn(_tokenId);
    }

    function getToken(uint _tokenId)
        public
        view
        returns (
            uint tokenId,
            address tokenOwner,
            uint8 level,
            uint32 createTimestamp,
            string memory uri
        )
    {
        require(_exists(_tokenId), "ERC721: token does not exist");
        Token memory _token = tokens[_tokenId];
        tokenId = _tokenId;
        tokenOwner = ownerOf(_tokenId);
        level = _token.level;
        createTimestamp = _token.createTimestamp;
        uri = tokenURI(_tokenId);
    }

    function allowedBusBalance(address _user) public view returns (uint) {
        if (firstBusTimestamp[_user] == 0) return minBusBalance;

        uint passedTime = (block.timestamp - firstBusTimestamp[_user]);
        uint additionalQuantity = passedTime / busAdditionPeriod;
        return (
            (minBusBalance + additionalQuantity) > maxBusBalance ? maxBusBalance : (minBusBalance + additionalQuantity)
        );
    }

    function secToNextBus(address _user) public view returns(uint) {
        if (firstBusTimestamp[_user] == 0 || allowedBusBalance(_user) >= maxBusBalance) return 0;
        uint passedTime = (block.timestamp - firstBusTimestamp[_user]);
        uint timeLeft = (passedTime / busAdditionPeriod + 1) * busAdditionPeriod + firstBusTimestamp[_user];

        return timeLeft;
    }

    function allowedUserToMintBus(address _user) public view returns(bool) {
        if(balanceOf(_user) < allowedBusBalance(_user)) return true;

        return false;
    }

    function allowedUserToPlayGame(address _user) public view returns(bool) {
        if(balanceOf(_user) <= allowedBusBalance(_user)) return true;

        return false;
    }

    function seatsInBuses(address _user) public view returns(uint) {
        if(allowedUserToPlayGame(_user)){
            uint countBuses = balanceOf(_user);
            uint seats;
            for(uint i = 0; i < countBuses; i++){
                seats += tokens[tokenOfOwnerByIndex(_user, i)].level;
            }
            return(seats);
        } else {
            return 0;
        }
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return internalBaseURI;
    }

    function _burn(uint _tokenId) internal override {
        super._burn(_tokenId);
        delete tokens[_tokenId];
    }

    function _safeMint(address _to, uint _tokenId) internal override {
        super._safeMint(_to, _tokenId);
        emit TokenMint(_to, _tokenId, tokens[_tokenId].level);
    }

    //Private functions --------------------------------------------------------------------------------------------
}
