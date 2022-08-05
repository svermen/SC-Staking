// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking{

    //aqui definimos un token para el staking y un token para el reward (podria ser el mismo)
    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    //address -> cuanto ha stakeado
    mapping(address => uint256) public s_balances;
    //reward que obtiene cada address
    mapping(address => uint256) public s_rewards;
    //cuanto se le ha pagado al usuario x cada token
    mapping(address => uint256) public s_userRewardPerTokenPaid;
    //
 

    //total de tokens bloqueados
    uint256 public s_totalSupply;
    // cantidad de reward por token bloqueado
    uint256 public s_rewardPerTokenStored;
    // la ultima vez que se ejecuto el modifier updateReward
    uint256 public s_lastUpdateTime;

    //cantidad de reward por segundo
    uint256 public constant REWARD_RATE = 100;


    constructor(address _stakingToken, address _rewardToken){
        s_stakingToken = IERC20(_stakingToken);
        s_rewardToken = IERC20(_rewardToken);
    }

    modifier updateReward(address account) {
        // definiremos una estructura de datos que nos ayudaran con el calculo
        // necesitamos:
        // reward x token
        // ultimo time stamp
        s_rewardPerTokenStored = rewardPerToken();
        s_lastUpdateTime = block.timestamp; //tiempo actual Datetime.Now
        //creamos un mapping para guardar los rewards
        //basado en el resultado de una funcion que llamaremos earned
        s_rewards[account] = earned(account);
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        require(amount > 0, "Amount debe ser mayor que cero");
        _;        
    }

    //obtendremos el reward de esta persona
    function earned(address account) public view returns(uint256){
        //el balance de lo que han stakeado
        uint256 currentBalance = s_balances[account];
        //cuanto ya han recibido
        uint256 amountPaid = s_userRewardPerTokenPaid[account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = s_rewards[account];
        uint256 totalEarned = ((  currentBalance * (currentRewardPerToken - amountPaid)) / 1e18 ) + pastRewards;
        return totalEarned;

    }

    function rewardPerToken() public view returns(uint256){
        if(s_totalSupply == 0){
            return s_rewardPerTokenStored;
        }
        // de otro modo hacemos lo siguiente:
        //
        return s_rewardPerTokenStored + (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply );
    }

    //obtener el reward  o reclamar el reward
    function claimReward() updateReward(msg.sender) external{
        uint256 reward = s_rewards[msg.sender];
        s_rewards[msg.sender] = 0;
        bool success = s_rewardToken.transfer(msg.sender, reward);
        require(success, "ClaimReward: Fallo la tx");
        //cuantos reward obtendra?
        //el mas utilizado es este tipo de contrato, que emite X tokens por sec
        //y los repartira para todos los stakers

        // 100 rewards tokens X sec
        //
        // Segundo 1
        // P1: 80 staking, ganado: 80, sacado:0
        // P2: 20 staking, ganado:20, sacado: 0
        //
        // Segundo 2
        // P1: 80 staking, ganado: 160, sacado:0
        // P2: 20 staking, ganado:40, sacado: 0
        //
        //Segundo 3 
        // La P1 retiro 10 tokens, entonces:
        // P1: 70 staking, ganado: 160 + (70) => 230, sacado:10
        // La P2 deposito 10 tokens más, entonces:
        // P2: 30 staking, ganado:40 + (30) => 70, sacado: 0

    }

    function stake(uint256 amount) updateReward(msg.sender) moreThanZero(amount) external { 
        // tendremos registro de cuando el usuario ha stakeado
        // tener un registro total de tokens
        // transferir los tokens a este contrato
        s_balances[msg.sender] = s_balances[msg.sender] + amount;
        s_totalSupply = s_totalSupply + amount;
        bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Stake fallo la transaccion");
         //emit evento

    }

    function withdraw(uint256 amount) updateReward(msg.sender) moreThanZero(amount) external { 
        s_balances[msg.sender] = s_balances[msg.sender] - amount;
        s_totalSupply = s_totalSupply - amount;
        bool success = s_stakingToken.transfer(msg.sender, amount);
        require(success, "Withdraw: fallo la transaccion");
    }
}