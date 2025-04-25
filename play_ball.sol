// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface MyHashBall {
    function deal_play_ball_external(bytes32 _hashball, uint72 _mutiple, address _owner, uint256 _epoch, uint256 index_ball) external;
}

interface MyCommittee {
    function get_current_epoch_starttime() external view returns(uint256, uint256);
}

interface MyEvent {
    function emit_buyballnormal(uint256 _index, address _addr, uint256 _epoch, uint72 _mutiple, bytes32 _hashball, uint32[6] memory nums, uint256 _time) external;
    function emit_buyball(uint256 _index, address _addr, uint256 _epoch, uint72 _mutiple, bytes32 _hashball, uint256 _time) external;
    function emit_buyballdealer(uint256[2] calldata _index_epoch, address[2] calldata _addr, uint72 _mutiple, bytes32 _hashball, uint256[2] calldata _dealerearn_time) external;
    function emit_buyballdealernormal(uint256[2] calldata _index_epoch, address[2] calldata _addr, uint72 _mutiple, bytes32 _hashball, uint32[6] calldata nums, uint256[2] calldata _dealerearn_time) external;
    function emit_buyballorganization(uint256 _index, address _addr, address _organization, uint256 _epoch, uint72 _mutiple, bytes32 _hashball, uint256 _time) external;
    function emit_communityearn(address _community, address _from, uint256 _amount, uint256 _time) external;
}
interface MyCommunity {
    function get_my_community(address _address) external view returns(address, string memory, bool);
}

interface MyDrawWinner {
    function add_ball_committee_money(uint256 _ball_money, uint256 _committee_value) external;
}

contract PlayBall {

    MyHashBall public myHashBall;
    MyCommittee public mycommittee;
    MyEvent public myevent;
    MyCommunity public mycommunity;
    MyDrawWinner public mydrawwinner;

    mapping(address => bool) private is_dealer;
    mapping(address =>mapping(uint256 => uint32[6])) private myball_normal;
    address private owner;   
    address private hashball_contract_address; 
    address private developer;
    address private airdrop;
    address private stake_pool;
    address private grant_address;
    address private committee_contract_address; 
    bool private initialized;
    uint256 private index_ball;

    uint256 constant public Dealer_Price = 1 * (10 ** 18);//price
    uint256 constant public BASE_BET = 1 * (10 ** 17);//price
    uint256 constant public MAX_MULTIPLE = 10;
    uint256 constant public BET_DIFF = 60*60*46;

    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }

    function initialize(address _owner, address _airdrop, address _grant_address) public{
        require(!initialized, "already initialized");
        initialized = true;
        owner = _owner;
        airdrop = _airdrop;
        grant_address = _grant_address;
    }

    function set_hashball(address _myhashball) public onlyOwner{
        myHashBall = MyHashBall(_myhashball);
        hashball_contract_address = _myhashball;
    }
    function set_mycommittee(address _mycommittee) public onlyOwner{
        mycommittee = MyCommittee(_mycommittee);
        committee_contract_address = _mycommittee;
    }
    function set_myevent(address _myevent) public onlyOwner{
        myevent = MyEvent(_myevent);
    }
    function set_mycommunity(address _mycommunity) public onlyOwner{
        mycommunity = MyCommunity(_mycommunity);
    }
    function set_mydrawwinner(address _mydrawwinner) public onlyOwner{
        mydrawwinner = MyDrawWinner(_mydrawwinner);
    }
    function set_stake_pool(address _stake_pool) public onlyOwner{
        stake_pool = _stake_pool;
    }
    function set_developer(address _developer) public onlyOwner{
        developer = _developer;
    }
    receive() external payable {}
    fallback() external payable {}

    function become_dealer() public payable{
        require(!is_dealer[msg.sender], 'already dealer');
        require(msg.value >= Dealer_Price, "not enough pay");
        (bool success, ) = (developer).call{value: Dealer_Price}("");
        if(!success){
            revert('call failed');
        }
        is_dealer[msg.sender] = true;
    }

    function play_ball(bytes32 _hashball, uint72 _mutiple) public payable returns(uint256){
        require(_mutiple >0 && _mutiple <= MAX_MULTIPLE, 'mutiple not allowed');       
        require(msg.value >= BASE_BET * _mutiple, "not enough pay");
        (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
        require(epoch > 0, 'not start');
        require(starttime > 0, 'epoch not start');
        require(block.timestamp < BET_DIFF + starttime, 'time exceed');
        uint256 total_money = msg.value;
        distribute_money(total_money, msg.sender, 1);
        (bool success, ) = (hashball_contract_address).call{value: total_money * 80 / 100}("");
        if(!success){
            revert('call failed');
        }
        index_ball = index_ball + 1;
        myHashBall.deal_play_ball_external(_hashball, _mutiple, msg.sender, epoch, index_ball);
        myevent.emit_buyball(index_ball, msg.sender, epoch, _mutiple, _hashball, block.timestamp);
        return index_ball;
    }

    function distribute_money(uint256 _total_money, address _owner, uint8 _type) private {
        (bool success_developer, ) = (developer).call{value: (_total_money * 5)/100}("");
        if(!success_developer){
            revert('call failed');
        }
        (bool success_airdrop, ) = (airdrop).call{value: (_total_money * 5)/100}("");
            if(!success_airdrop){
                revert('call failed');
        }
        (bool success_stake, ) = (stake_pool).call{value: (_total_money * 5)/100}("");
            if(!success_stake){
                revert('call failed');
        }
        if(_type == 1 || _type == 4){
            
            (address mycommunity_address, , ) = mycommunity.get_my_community(_owner);
            if(mycommunity_address != address(0)){
                (bool success_mycommunity_address, ) = (mycommunity_address).call{value: (_total_money * 3)/100}("");
                (bool success_committee_contract_address, ) = (committee_contract_address).call{value: (_total_money * 2)/100}("");
                if(!success_committee_contract_address || !success_mycommunity_address){
                    revert('call failed');
                }
                mydrawwinner.add_ball_committee_money(_total_money*80/100, _total_money*2/100);
                myevent.emit_communityearn(mycommunity_address, _owner, (_total_money * 3)/100, block.timestamp);
            }else{
                //if no community
                (bool success_grant, ) = (grant_address).call{value: (_total_money * 3)/100}("");
                (bool success_committee_contract_address, ) = (committee_contract_address).call{value: (_total_money * 2)/100}("");
                if(!success_committee_contract_address || !success_grant){
                    revert('call failed');
                }
                mydrawwinner.add_ball_committee_money(_total_money*80/100, _total_money*2/100);          
            }

        }else{
            (bool success_grant, ) = (grant_address).call{value: (_total_money * 3)/100}("");
            (bool success_committee_contract_address, ) = (committee_contract_address).call{value: (_total_money * 2)/100}("");
            if(!success_committee_contract_address || !success_grant){
                revert('call failed');
            }
            mydrawwinner.add_ball_committee_money(_total_money*80/100, _total_money*2/100);            
        }

    }

    function play_ball_normal(uint32[6] calldata nums, uint72 _mutiple) public payable returns(uint256){
        require(_mutiple >0 && _mutiple <= MAX_MULTIPLE, 'mutiple not allowed');       
        require(msg.value >= BASE_BET * _mutiple, "not enough pay");
        (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
        require(epoch > 0, 'not start');
        require(starttime > 0, 'epoch not start');
        require(block.timestamp < BET_DIFF + starttime, 'time exceed');

        uint256 total_money = msg.value;
        distribute_money(total_money, msg.sender, 4);
        (bool success, ) = (hashball_contract_address).call{value: total_money * 80 / 100}("");
        if(!success){
            revert('call failed');
        }
        uint256 salt = 0;
        // bytes32 _hashball = keccak256(abi.encodePacked(nums, salt, msg.sender));
        bytes32 _hashball = keccak256(abi.encodePacked(nums, salt));
        index_ball = index_ball + 1;
        myHashBall.deal_play_ball_external(_hashball, _mutiple, msg.sender, epoch, index_ball);
        myball_normal[msg.sender][index_ball] = nums;
        // emit buyballnormal(_index,  msg.sender, epoch, _mutiple, _hashball, nums, block.timestamp); 
        myevent.emit_buyballnormal(index_ball,  msg.sender, epoch, _mutiple, _hashball, nums, block.timestamp);
        return index_ball;
    }

    function play_ball_dealer(bytes32 _hashball, uint72 _mutiple, address dealer) public payable returns(uint256){
        (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
        require(epoch > 0, 'not start');
        require(starttime > 0, 'epoch not start');
        require(block.timestamp < BET_DIFF + starttime, 'time exceed');

        require(_mutiple >0 && _mutiple <= MAX_MULTIPLE, 'mutiple not allowed'); 
        require(is_dealer[dealer], 'not dealer');      
        require(msg.value >= BASE_BET * _mutiple, "not enough pay");
        uint256 total_money = msg.value;
        uint256 left_money = (total_money * 90)/100;
        uint256 dealer_money = (total_money * 10)/100;

        distribute_money(left_money, msg.sender, 2);
        (bool success_dealer, ) = (dealer).call{value: dealer_money}("");
        if(!success_dealer){
            revert('call failed');
        }
        (bool success_hashball, ) = (hashball_contract_address).call{value: left_money*80/100}("");
        if(!success_hashball){
            revert('call failed');
        }
        index_ball = index_ball + 1;
        myHashBall.deal_play_ball_external(_hashball, _mutiple, msg.sender, epoch, index_ball);
        myevent.emit_buyballdealer([index_ball, epoch], [msg.sender, dealer], _mutiple, _hashball, [dealer_money, block.timestamp]);
        
        return index_ball;
    }

    function play_ball_dealer_normal(uint32[6] calldata nums, uint72 _mutiple, address dealer) public payable returns(uint256){
        require(_mutiple >0 && _mutiple <= MAX_MULTIPLE, 'mutiple not allowed');       
        require(msg.value >= BASE_BET * _mutiple, "not enough pay");
        (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
        require(epoch > 0, 'not start');
        require(starttime > 0, 'epoch not start');
        require(block.timestamp < BET_DIFF + starttime, 'time exceed');
        require(is_dealer[dealer], 'not dealer');  

        // uint256 total_money = msg.value;
        // uint256 left_money = (total_money * 90)/100;
        // uint256 dealer_money = (total_money * 10)/100;

        distribute_money((msg.value* 90)/100, msg.sender, 2);
        (bool success_dealer, ) = (dealer).call{value: ((msg.value* 10)/100)}("");
        if(!success_dealer){
            revert('call failed');
        }
        (bool success_hashball, ) = (hashball_contract_address).call{value: ((msg.value* 90)/100)*80/100}("");
        if(!success_hashball){
            revert('call failed');
        }

        uint256 salt = 0;
        // bytes32 _hashball = keccak256(abi.encodePacked(nums, salt, msg.sender));
        bytes32 _hashball = keccak256(abi.encodePacked(nums, salt));
        index_ball = index_ball + 1;
        myHashBall.deal_play_ball_external(_hashball, _mutiple, msg.sender, epoch, index_ball);
        myball_normal[msg.sender][index_ball] = nums;
        
        myevent.emit_buyballdealernormal([index_ball, epoch], [msg.sender, dealer], _mutiple, _hashball, nums, [(msg.value* 10)/100, block.timestamp]);
        return index_ball;
    }

    // function play_ball_organization(uint32[6][] calldata nums, uint256[] calldata salts, address[] calldata addrs) public payable returns(uint256[] memory){
    //     (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
    //     require(epoch > 0, 'not start');
    //     require(starttime > 0, 'epoch not start');
    //     require(block.timestamp < BET_DIFF + starttime, 'time exceed');

    //     require(nums.length >= 50 && addrs.length >=50 && salts.length >=50, 'length is too small');// at least 50 for organization
    //     require((nums.length == addrs.length) && (addrs.length == salts.length) , 'nums, addrs and salts should same length'); 
    //     uint256 should_pay = (BASE_BET * nums.length * 90 /100);//orgainization buy is 10% off
    //     require(msg.value >= should_pay, "not enough pay");
    //     uint256 total_money = msg.value;
    //     distribute_money(total_money, msg.sender, 3);
    //     (bool success_hashball, ) = (hashball_contract_address).call{value: total_money * 80 / 100}("");
    //     if(!success_hashball){
    //         revert('call failed');
    //     }
 
    //     uint256[] memory indexs = new uint256[](nums.length);
    //     bytes32 _hashball;
    //     for(uint256 i = 0; i < nums.length; i++) {
    //         // _hashball = keccak256(abi.encodePacked(nums[i], salts[i], addrs[i]));
    //         _hashball = keccak256(abi.encodePacked(nums[i], salts[i]));
    //         index_ball = index_ball + 1;
    //         myHashBall.deal_play_ball_external(_hashball, 1, addrs[i], epoch, index_ball);
    //         indexs[i] = index_ball;
    //         myevent.emit_buyballorganization(indexs[i], addrs[i], msg.sender, epoch, 1, _hashball, block.timestamp);
    //     }

    //     return (indexs);
    // }
    function play_ball_organization(bytes32[] calldata _hashballs, address[] calldata addrs) public payable {
        (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
        require(epoch > 0, 'not start');
        require(starttime > 0, 'epoch not start');
        require(block.timestamp < BET_DIFF + starttime, 'time exceed');

        require(_hashballs.length >= 20 && addrs.length >=20, 'length is too small');// at least 20 for organization
        require(_hashballs.length == addrs.length, 'nums and addrs should same length'); 
        uint256 should_pay = (BASE_BET * _hashballs.length * 90 /100);//orgainization buy is 10% off
        require(msg.value >= should_pay, "not enough pay");
        uint256 total_money = msg.value;
        distribute_money(total_money, msg.sender, 3);
        (bool success_hashball, ) = (hashball_contract_address).call{value: total_money * 80 / 100}("");
        if(!success_hashball){
            revert('call failed');
        }
 
        for(uint256 i = 0; i < _hashballs.length; i++) {
            index_ball = index_ball + 1;
            bytes32 _hashball = _hashballs[i];
            myHashBall.deal_play_ball_external(_hashball, 1, addrs[i], epoch, index_ball);
            myevent.emit_buyballorganization(index_ball, addrs[i], msg.sender, epoch, 1, _hashball, block.timestamp);
        }

       
    }

    function get_ball_num(address _addr, uint256 _index) external view returns(uint32[6] memory){
        return myball_normal[_addr][_index];
    }
    function get_indexball() external view returns(uint256){
        return index_ball;
    }
    function check_dealer(address _addr) external view returns(bool){
        return is_dealer[_addr];
    } 

}
