pragma solidity ^0.4.20;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
 
  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }
 
  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }
 
  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract BaseContract{
    address public super_owner;
    string public default_gateway;
    uint256 public rate;
    
    uint16 public totalLinkContract;
    uint16 public totalMessage; 
    
    struct MessageContract{
        address addr;
        uint16 idSublink;
    }
    
    // list manage address
    address[] public mapMember;
    
    // list manage contract by each address
    mapping(address => mapping(uint16 => address)) public mapLinkContract;
    
    // array to load all contract link 
    mapping(uint16 => address) public mapContract; 
    
    // 
    mapping(address => MessageContract[]) public listMessageContract;
    
    event UpdateExchange(uint256 _rate);
    event UpdateGateway(string _gateway);
    
    constructor (string _defautGateway, uint256 _rate) public {
        super_owner = msg.sender;
        default_gateway = _defautGateway;
        rate = _rate;
    }
    
    function () public payable {
        
    }
    
    modifier onlyOwner {
        require(msg.sender == super_owner);
        _;
    }
    
    function saveContract(address _contractLink, address _ownerContractLink) external {
        totalLinkContract ++;
        mapContract[totalLinkContract] = _contractLink;
        mapLinkContract[_ownerContractLink][totalLinkContract] = _contractLink; 
    }
    
    function forwardLink(address _addrContract, address _addrRecive, uint16 _idSublink) external {
        MessageContract memory mess = MessageContract(_addrContract, _idSublink); 
        listMessageContract[_addrRecive].push(mess);
    }
    
    function updateExchange(uint256 _newRate) onlyOwner public {
        rate = _newRate;
        emit UpdateExchange(rate);
    }
    
    function updateGateway(string _new_gateway) onlyOwner public {
        default_gateway = _new_gateway; 
        emit UpdateGateway(default_gateway);
    }
    
}

contract LinkContract {
    /*
        parent = parent + 0.1% child
        max_click = 1ETH : 1000 click
        https://sharesystem.herokuapp.com/link?create=0xaoaoao&parent=0xaooaoao&contract=0xapapapapap&ref=https://www.youtube.com/watch?v=UCXao7aTDQM
    */
    using SafeMath for uint256;
    BaseContract base_contract;
    
    address public owner;
    address public super_owner;
    
    address public contract_base;
    uint256 public invest_eth;
    
    string public link;
    string public default_gateway;
    
    uint256 public process;
    uint256 public totalClicked;
    uint256 public maxClick;
    uint16 public totalLinkGenerared;
    bool public status;
    
    // struct link generated
    struct SubLink{
        int32 id;
        address addr_create;
        address addr_parent;
        address current_contract;
        string link;
    }
    
    // all member, just address
    address[] public members;
    SubLink[] public subLinks;
    
    // map number click of address 
    mapping (address => uint256) public mapClick;
    
    // map statistical click of address (th?ng kê)
    mapping (address => uint256) public mapStatisticalClick;
    
    // map link generated for each address
    mapping (uint16 => SubLink) public mapLinkGenerated;
    
    /* modifier */
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    
    modifier notOwner(){
        require(msg.sender != owner);
        _;
    }
    
    modifier onlySuperOwner(){
        require(msg.sender == super_owner);
        _;
    }
    
    /* feature */
    event ForwardTo(address addrRecive);
    
    // on up contract_link
    event UpContractLink();
    
    // payment 
    event Payment(address addr, uint256 value);
    
    // on generated link => UI create link full link with param
    event GenerateLinkContract(address _sender, address _parent, address _contract, string _link, string _gateway);

    // "0xbe7828be49a52c06f64d9cb033e0a9465a7dc9b6","https://www.youtube.com/watch?v=DUZCedq9a4Q"
    constructor (address _contract_base, string _link) public {
        contract_base = _contract_base;
        owner = msg.sender;
        link = _link;
        status = true;
        emit UpContractLink();
    }
    
    // send ETH and save address contract_link, just owner contract 
    function () public payable onlyOwner {
        // save contract to contract_base
        base_contract = BaseContract(contract_base);
        
        super_owner = base_contract.super_owner(); 
        default_gateway = base_contract.default_gateway();
        uint256 rate = base_contract.rate();
        base_contract.saveContract(address(this), msg.sender);
        
        invest_eth += msg.value;
        
        maxClick = (invest_eth/10**18)*90*rate/100; 
        // send fee
        uint256 fee = invest_eth*10/100;
        sendEther(fee);
        
    }
    
    function forwardLink(address _addrRecive, uint16 _linkId) notOwner public {
        base_contract = BaseContract(contract_base);
        base_contract.forwardLink(address(this), _addrRecive, _linkId); 
        emit ForwardTo(_addrRecive); 
    }
    
    function generateLink(address _parent, address _contract) notOwner public {
        
        require(status == true);
        
        SubLink memory gen_link = SubLink(
            totalLinkGenerared,
            msg.sender,
            _parent,
            _contract,
            link
        );
        
        mapLinkGenerated[totalLinkGenerared] = gen_link; 
        
        members.push(msg.sender);
        subLinks.push(gen_link);
        
        totalLinkGenerared ++;
        
        emit GenerateLinkContract(msg.sender, _parent, _contract, link, default_gateway);
    }
    
    /* handle logic*/
    
     // incre number click link of address & total_clicked
    function onNewClick(address _child, address _parent) public onlySuperOwner{
        
        require(status == true);
        
        mapClick[_child] = mapClick[_child] + 10;
        mapClick[_parent] = mapClick[_parent] + 1;
        
        mapStatisticalClick[_child] = mapClick[_child];
        mapStatisticalClick[_parent] = mapClick[_parent];

        totalClicked = totalClicked + 1;
        
        // if number click full, to caculate money
        if (checkFullClick()){
            payment();
            status = false;
        }
    }
    
    function sendEther(uint256 _numEther) internal {
        super_owner.transfer(_numEther);
    }
    
    function payment() public {
        /*caculate money for address[] members*/
        
        uint size = members.length;
        uint balance = this.balance;
        
        if (maxClick == 0){
            return; 
        }
        for (uint i = 0; i < size; i++){
            // each click ++ 10; 
            uint256 numberETH = (mapClick[members[i]]*balance).div(maxClick*10);
            members[i].transfer(numberETH);
            
            // reset map_click
            mapClick[members[i]] = 0;
            
            emit Payment(members[i], numberETH);
        }
        
    }
    
    function checkFullClick() internal returns(bool){
        // total click ++ 10 each click 
        if (totalClicked >= maxClick*10){
            return true;
        }else{
            return false;
        }
    }
    
}



