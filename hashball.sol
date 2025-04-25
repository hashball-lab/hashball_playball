// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface MyCommittee {
    function get_current_epoch_starttime() external view returns(uint256, uint256);
}

interface MyCompare {
    function check_ball(uint32[6] calldata nums, uint256 _epoch) external view returns(uint8, uint32[] memory, uint32);
}

interface MyDrawWinner {
    function add_claimed_money(uint256 _epoch, uint256 _claimed_money) external;
}

interface MyPlayBall {
    function get_ball_num(address _addr, uint256 _index) external view returns(uint32[6] memory);
}

interface MyEvent {
    function emit_updatebuyballreward(uint256 _index, uint8 _reward) external;
    function emit_updateballclaimstatus(uint256 _index, uint8 _status) external;
}

contract HashBall {

    struct Ball{
        bytes32 ballhash;
        uint256 epoch;
        address owner;
        uint72 multiple;
        uint8 reward;//0 init & no reward, 1-6 reward
        bool has_claimed;
        bool has_request_claim;
    }

    MyCommittee public mycommittee;
    MyCompare public mycompare;
    MyDrawWinner public mydrawwinner;
    MyPlayBall public myplayball;
    MyEvent public myevent;

    uint256 constant public BASE_BET = 1 * (10 ** 17);//price

    mapping (uint256 => Ball) private myball;//index_ball

    mapping (uint256 => uint256) private epoch_prize1_value;//epoch
    mapping (uint256 => uint256) private epoch_prize2_value;//epoch
    mapping (uint256 => uint256) private epoch_prize3_value;//epoch
    mapping (uint256 => uint256) private epoch_prize4_value;//epoch
    mapping (uint256 => uint256) private epoch_prize5_value;//epoch
    mapping (uint256 => uint256) private epoch_prize6_value;//epoch

    mapping (uint256 => uint256) private epoch_prize1_claimed_value;//epoch
    mapping (uint256 => uint256) private epoch_prize2_claimed_value;//epoch
    mapping (uint256 => uint256) private epoch_prize3_claimed_value;//epoch
    mapping (uint256 => uint256) private epoch_prize4_claimed_value;//epoch
    mapping (uint256 => uint256) private epoch_prize5_claimed_value;//epoch
    mapping (uint256 => uint256) private epoch_prize6_claimed_value;//epoch

    mapping (uint256 => uint256) private epoch_prize1_members;//epoch
    mapping (uint256 => uint256) private epoch_prize2_members;//epoch
    mapping (uint256 => uint256) private epoch_prize3_members;//epoch
    mapping (uint256 => uint256) private epoch_prize4_members;//epoch
    mapping (uint256 => uint256) private epoch_prize5_members;//epoch
    mapping (uint256 => uint256) private epoch_prize6_members;//epoch

    mapping (address => bool) private authorize_drawwinner;//authorize
    mapping (address => bool) private authorize_ball_play;//authorize
    mapping (address => bool) private authorize_pool;//authorize

    address private developer;
    address private airdrop;
    address private owner;   
    bool private initialized;


    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyDrawWinner(){
        require(authorize_drawwinner[msg.sender], "not authorize");
        _;
    }

    modifier onlyPlayBall(){
        require(authorize_ball_play[msg.sender], "not authorize");
        _;
    }

    modifier onlyPool(){
        require(authorize_pool[msg.sender], "not authorize");
        _;
    }

    function initialize(address _owner) public{
        require(!initialized, "already initialized");
        initialized = true;
        owner = _owner;
    }

    function set_contracts(address _mycommittee, address _mycompare, address _mydrawwinner, address _myplayball, address _myevent) public onlyOwner{
        mycommittee = MyCommittee(_mycommittee);
        mycompare = MyCompare(_mycompare);
        mydrawwinner = MyDrawWinner(_mydrawwinner);
        myplayball = MyPlayBall(_myplayball);
        myevent = MyEvent(_myevent);
    }

    function set_authorize_drawwinner(address _myaddress, bool _true_false) public onlyOwner{
        authorize_drawwinner[_myaddress] = _true_false;
    }

    function set_authorize_ball_play(address _myaddress, bool _true_false) public onlyOwner{
        authorize_ball_play[_myaddress] = _true_false;
    }

    function set_authorize_pool(address _myaddress, bool _true_false) public onlyOwner{
        authorize_pool[_myaddress] = _true_false;
    }

    function get_pool_money_back(address _addr, uint256 _amount) external onlyPool{
        (bool success, ) = (_addr).call{value: _amount}("");
        if(!success){
            revert('call failed');
        }
    }

    function form_epoch_prize_value(uint256 _epoch, uint256 _total_value) external onlyDrawWinner{
        epoch_prize1_value[_epoch] = _total_value/5;
        epoch_prize2_value[_epoch] = _total_value/10;
        epoch_prize3_value[_epoch] = _total_value/20;
        epoch_prize4_value[_epoch] = _total_value/5;
        epoch_prize5_value[_epoch] = _total_value/5;
        epoch_prize6_value[_epoch] = _total_value/5;
    }

    function deal_play_ball_external(bytes32 _hashball, uint72 _mutiple, address _owner, uint256 _epoch, uint256 index_ball) external onlyPlayBall{
        deal_play_ball_internal(_hashball, _mutiple, _owner, _epoch, index_ball);

    }

    function deal_play_ball_internal(bytes32 _hashball, uint72 _mutiple, address _owner, uint256 _epoch, uint256 index_ball) private{
        myball[index_ball].ballhash = _hashball;
        myball[index_ball].epoch = _epoch;
        myball[index_ball].owner = _owner;
        myball[index_ball].multiple = _mutiple;
        myball[index_ball].reward = 0;
        myball[index_ball].has_claimed = false;
        myball[index_ball].has_request_claim = false;
    }

    receive() external payable {}
    fallback() external payable {}

    function check_ball(uint32[6] memory nums, uint256 _salt, uint256 _index_ball, uint256 _epoch) public view returns(uint8, uint32[] memory, uint32){
        return check_ball_internal(nums, _salt, _index_ball, _epoch, msg.sender);
    }

    function check_ball_normal(uint256 _index_ball, uint256 _epoch) public view returns(uint8, uint32[] memory, uint32){
        uint32[6] memory nums = myplayball.get_ball_num(msg.sender, _index_ball);
        uint256 _salt = 0;
        return check_ball_internal(nums, _salt, _index_ball, _epoch, msg.sender);
    }

    function submit_claim_request(uint32[6] memory nums, uint256 _salt, uint256 _index_ball, uint256 _epoch) public{
        submit_claim_request_internal(nums, _salt, _index_ball, _epoch, msg.sender);
    }

    function submit_claim_request_normal(uint256 _index_ball, uint256 _epoch) public{
        uint32[6] memory nums = myplayball.get_ball_num(msg.sender, _index_ball);
        uint256 _salt = 0;
        submit_claim_request_internal(nums, _salt, _index_ball, _epoch, msg.sender);
    }

    function submit_claim_request_internal(uint32[6] memory nums, uint256 _salt, uint256 _index_ball, uint256 _epoch, address _addr) private{
        (uint256 epoch, ) = mycommittee.get_current_epoch_starttime();
        require(epoch == (_epoch + 1), 'time exceed');//should submit before the end of next epoch
        uint8 reward_num = 0;
        (reward_num, , ) = check_ball_internal(nums, _salt, _index_ball, _epoch, _addr);
        require(reward_num > 0 && reward_num < 4, 'No Reward Submit');
        require(!myball[_index_ball].has_request_claim, 'already submit');
        require(!myball[_index_ball].has_claimed, 'already claimed');
        myball[_index_ball].reward = reward_num;
        myball[_index_ball].has_request_claim = true;
        if(reward_num == 1){
            epoch_prize1_members[_epoch] += myball[_index_ball].multiple;
        }else if(reward_num == 2){
            epoch_prize2_members[_epoch] += myball[_index_ball].multiple;
        }else if(reward_num == 3){
            epoch_prize3_members[_epoch] += myball[_index_ball].multiple;
        }

        myevent.emit_updatebuyballreward(_index_ball, reward_num);
        myevent.emit_updateballclaimstatus(_index_ball, 1);

    }

    function claim_prize1_2_3(uint256 _index_ball, uint256 _epoch) public{
        // uint256 epoch = mycommittee.get_current_epoch();
        (uint256 epoch, ) = mycommittee.get_current_epoch_starttime();
        require(epoch == (_epoch + 2), 'time not allow');//should claim before the end of third epoch
        require(myball[_index_ball].has_request_claim, 'not submit');
        require(myball[_index_ball].reward > 0 && myball[_index_ball].reward < 4, 'wrong reward');
        require(!myball[_index_ball].has_claimed, 'already claimed');
        require(myball[_index_ball].owner == msg.sender, 'not owner');
        if(myball[_index_ball].reward == 1){
            if(epoch_prize1_members[_epoch] > 0){
                uint256 _value = (myball[_index_ball].multiple * epoch_prize1_value[_epoch])/epoch_prize1_members[_epoch];
                if(epoch_prize1_value[_epoch] >= (_value + epoch_prize1_claimed_value[_epoch])){
                    epoch_prize1_claimed_value[_epoch] += _value;
                    deal_reward_pool(_index_ball, _epoch, _value, msg.sender);
                }
            }
        }else if(myball[_index_ball].reward == 2){
            if(epoch_prize2_members[_epoch] > 0){
                uint256 _value = (myball[_index_ball].multiple * epoch_prize2_value[_epoch])/epoch_prize2_members[_epoch];
                if(epoch_prize2_value[_epoch] >= (_value + epoch_prize2_claimed_value[_epoch])){
                    epoch_prize2_claimed_value[_epoch] += _value;
                    deal_reward_pool(_index_ball, _epoch, _value, msg.sender);
                }
            }
        }else if(myball[_index_ball].reward == 3){
            if(epoch_prize3_members[_epoch] > 0){
                uint256 _value = (myball[_index_ball].multiple * epoch_prize3_value[_epoch])/epoch_prize3_members[_epoch];
                if(epoch_prize3_value[_epoch] >= (_value + epoch_prize3_claimed_value[_epoch])){
                    epoch_prize3_claimed_value[_epoch] += _value;
                    deal_reward_pool(_index_ball, _epoch, _value, msg.sender);
                }
            }
        }
        // emit updateballclaimstatus(_index_ball, 2);
        myevent.emit_updateballclaimstatus(_index_ball, 2);
    }

    function claim_prize4_5_6(uint32[6] memory nums, uint256 _salt, uint256 _index_ball, uint256 _epoch) public{
        claim_prize4_5_6_internal(nums, _salt, _index_ball, _epoch, msg.sender);
    }

    function claim_prize4_5_6_normal(uint256 _index_ball, uint256 _epoch) public{
        uint32[6] memory nums = myplayball.get_ball_num(msg.sender, _index_ball);
        uint256 _salt = 0;
        claim_prize4_5_6_internal(nums, _salt, _index_ball, _epoch, msg.sender);
    }

    function claim_prize4_5_6_internal(uint32[6] memory nums, uint256 _salt, uint256 _index_ball, uint256 _epoch, address _addr) private{
        // uint256 epoch = mycommittee.get_current_epoch();
        (uint256 epoch, ) = mycommittee.get_current_epoch_starttime();
        require((epoch <= (_epoch + 2)) && (epoch > _epoch), 'time not allow');
        uint8 reward_num = 0;
        (reward_num, , ) = check_ball_internal(nums, _salt, _index_ball, _epoch, _addr);
        require(reward_num > 3 && reward_num < 7, 'wrong prize');
        require(!myball[_index_ball].has_claimed, 'Already Claimed');
        
        if(reward_num == 4){
            if(epoch_prize4_value[_epoch] > (epoch_prize4_claimed_value[_epoch] + BASE_BET * 50 * myball[_index_ball].multiple)){
                // myball[_index_ball].has_claimed = true;
                myball[_index_ball].reward = 4;
                epoch_prize4_members[_epoch] += myball[_index_ball].multiple;
                epoch_prize4_claimed_value[_epoch] += BASE_BET * 50 * myball[_index_ball].multiple;
                // payable (_addr).transfer(BASE_BET * 50 * myball[_index_ball].multiple);
                deal_reward_pool(_index_ball, _epoch, BASE_BET * 50 * myball[_index_ball].multiple, _addr);
            }else{
                if(epoch == (_epoch + 2)){
                    if(epoch_prize1_members[_epoch] == 0){
                        if((epoch_prize4_value[_epoch] + epoch_prize1_value[_epoch]/5) > (epoch_prize4_claimed_value[_epoch] + BASE_BET * 50 * myball[_index_ball].multiple)){
                            // myball[_index_ball].has_claimed = true;
                            myball[_index_ball].reward = 4;
                            epoch_prize4_members[_epoch] += myball[_index_ball].multiple;
                            epoch_prize4_claimed_value[_epoch] += BASE_BET * 50 * myball[_index_ball].multiple;
                            // payable (_addr).transfer(BASE_BET * 50 * myball[_index_ball].multiple);
                            deal_reward_pool(_index_ball, _epoch, BASE_BET * 50 * myball[_index_ball].multiple, _addr);
                        }else{
                            revert('Prize4 Pool is Empty');
                        }
                    }else{
                        revert('Prize4 Pool is Empty');
                    }
                }else{
                    revert('Prize4 Pool is Empty');
                }
                
            }
        }else if(reward_num == 5){
            if(epoch_prize5_value[_epoch] > (epoch_prize5_claimed_value[_epoch] + ((BASE_BET * 35)/10) * myball[_index_ball].multiple)){
                // myball[_index_ball].has_claimed = true;
                myball[_index_ball].reward = 5;
                epoch_prize5_members[_epoch] += myball[_index_ball].multiple;
                epoch_prize5_claimed_value[_epoch] += ((BASE_BET * 35)/10) * myball[_index_ball].multiple;
                // payable (_addr).transfer(((BASE_BET * 35)/10) * myball[_index_ball].multiple);
                deal_reward_pool(_index_ball, _epoch, ((BASE_BET * 35)/10) * myball[_index_ball].multiple, _addr);
            }else{
                if(epoch == (_epoch + 2)){
                    if(epoch_prize1_members[_epoch] == 0){
                        if((epoch_prize5_value[_epoch] + epoch_prize1_value[_epoch]/5) > (epoch_prize5_claimed_value[_epoch] + ((BASE_BET * 35)/10) * myball[_index_ball].multiple)){
                            // myball[_index_ball].has_claimed = true;
                            myball[_index_ball].reward = 5;
                            epoch_prize5_members[_epoch] += myball[_index_ball].multiple;
                            epoch_prize5_claimed_value[_epoch] += ((BASE_BET * 35)/10) * myball[_index_ball].multiple;
                            // payable (_addr).transfer(((BASE_BET * 35)/10) * myball[_index_ball].multiple);
                            deal_reward_pool(_index_ball, _epoch, ((BASE_BET * 35)/10) * myball[_index_ball].multiple, _addr);
                        }else{
                            revert('Prize5 Pool is Empty');
                        }
                    }else{
                        revert('Prize5 Pool is Empty');
                    }
                }else{
                    revert('Prize5 Pool is Empty');
                }
            }

        }else if(reward_num == 6){
            if(epoch_prize6_value[_epoch] > (epoch_prize6_claimed_value[_epoch] + BASE_BET * 2 * myball[_index_ball].multiple)){
                // myball[_index_ball].has_claimed = true;
                myball[_index_ball].reward = 6;
                epoch_prize6_members[_epoch] += myball[_index_ball].multiple;
                epoch_prize6_claimed_value[_epoch] += BASE_BET * 2 * myball[_index_ball].multiple;
                // payable (_addr).transfer(BASE_BET * 2 * myball[_index_ball].multiple);
                deal_reward_pool(_index_ball, _epoch, BASE_BET * 2 * myball[_index_ball].multiple, _addr);
            }else{
                if(epoch == (_epoch + 2)){
                    if(epoch_prize1_members[_epoch] == 0){
                        if((epoch_prize6_value[_epoch] + epoch_prize1_value[_epoch]/5)> (epoch_prize6_claimed_value[_epoch] + BASE_BET * 2 * myball[_index_ball].multiple)){
                            // myball[_index_ball].has_claimed = true;
                            myball[_index_ball].reward = 6;
                            epoch_prize6_members[_epoch] += myball[_index_ball].multiple;
                            epoch_prize6_claimed_value[_epoch] += BASE_BET * 2 * myball[_index_ball].multiple;
                            // payable (_addr).transfer(BASE_BET * 2 * myball[_index_ball].multiple);
                            deal_reward_pool(_index_ball, _epoch, BASE_BET * 2 * myball[_index_ball].multiple, _addr);
                        }else{
                            revert('Prize6 Pool is Empty');
                        }
                    }else{
                        revert('Prize6 Pool is Empty');
                    }
                }else{
                    revert('Prize6 Pool is Empty');
                }
                
            }
        }
        // emit updatebuyballreward(_index_ball, reward_num);
        // emit updateballclaimstatus(_index_ball, 2);
        myevent.emit_updatebuyballreward(_index_ball, reward_num);
        myevent.emit_updateballclaimstatus(_index_ball, 2);
    }

    function save_prize_status(uint32[6] memory nums, uint256 _salt, uint256 _index_ball, uint256 _epoch) public{
        require(myball[_index_ball].reward == 0, 'Already Saved');
        (uint8 reward_num, , ) = check_ball_internal(nums, _salt, _index_ball, _epoch, msg.sender);
        if(reward_num == 0){
            myball[_index_ball].reward = 8;
        }else{
            myball[_index_ball].reward = reward_num;
        }
        // emit updatebuyballreward(_index_ball, reward_num);
        myevent.emit_updatebuyballreward(_index_ball, reward_num);
    }

    function check_ball_internal(uint32[6] memory nums, uint256 _salt, uint256 _index_ball, uint256 _epoch, address _addr) private view returns(uint8, uint32[] memory, uint32){
        // bytes32 _hashball = keccak256(abi.encodePacked(nums, _salt, _addr));
        bytes32 _hashball = keccak256(abi.encodePacked(nums, _salt));
        require(myball[_index_ball].ballhash == _hashball, "not the same hash");
        require(myball[_index_ball].owner == _addr, "not owner");
        require(myball[_index_ball].epoch == _epoch, "not the same epoch");

        return mycompare.check_ball(nums, _epoch);
    }

    function deal_reward_pool(uint256 _index_ball, uint256 _epoch, uint256 _amount, address _addr) private {
        myball[_index_ball].has_claimed = true;
        (bool success, ) = (_addr).call{value: _amount}("");
        if(!success){
            revert('call failed');
        }
        mydrawwinner.add_claimed_money(_epoch, _amount);
    }

    function get_prize_member_reward(uint256 _epoch) public view returns(uint256[6] memory, uint256, uint256[6] memory, uint256[6] memory){
        uint256  jackpot = epoch_prize1_value[_epoch] + epoch_prize2_value[_epoch] + epoch_prize3_value[_epoch] + epoch_prize4_value[_epoch] + epoch_prize5_value[_epoch] + epoch_prize6_value[_epoch];
        return ([epoch_prize1_members[_epoch], epoch_prize2_members[_epoch], epoch_prize3_members[_epoch], epoch_prize4_members[_epoch], epoch_prize5_members[_epoch], epoch_prize6_members[_epoch]], jackpot, [epoch_prize1_value[_epoch], epoch_prize2_value[_epoch], epoch_prize3_value[_epoch], epoch_prize4_value[_epoch], epoch_prize5_value[_epoch], epoch_prize6_value[_epoch]], [epoch_prize1_claimed_value[_epoch], epoch_prize2_claimed_value[_epoch], epoch_prize3_claimed_value[_epoch], epoch_prize4_claimed_value[_epoch], epoch_prize5_claimed_value[_epoch], epoch_prize6_claimed_value[_epoch]]);
    }

}
