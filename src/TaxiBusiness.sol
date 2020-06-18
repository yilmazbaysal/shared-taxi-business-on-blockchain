pragma solidity >= 0.6.5;

contract TaxiBusiness {
    /********************************************* STRUCTS *********************************************/
    struct Participant {
        address payable participantAdress;
        uint account;
    }
    
    struct TaxiDriver {
        address payable driverAdress;
        uint salary;
        uint account;
    }
    
    struct ProposedDriver {
        TaxiDriver taxiDriver;
        uint8 approvalState;
        mapping (address => bool) approvedParticipants;
    }
    
    struct ProposedCar {
        uint256 carID;
        uint price;
        uint offerValidTime;
        uint8 approvalState;
        mapping (address => bool) approvedParticipants;
    }
    
    /***************************************** STATE VARIABLES *****************************************/
    address payable public manager;
    address payable public carDealer;
    
    address payable[] public participantArray;
    mapping(address => Participant) public participants;
    
    uint256 public contractBalance;
    uint fixedExpenses = 10 ether;
    uint participationFee = 100 ether;
    
    TaxiDriver public taxiDriver;
    ProposedDriver proposedDriver;
    
    uint256 public ownedCar;
    ProposedCar proposedCar;
    ProposedCar proposedRepurchaseCar;
    
    
    // Timing
    uint256 startTime;
    uint256 lastSalaryTime;
    uint256 lastDividendTime;
    uint256 lastCarExpensesTime;
    
    // Events
    event MaintenanceExpenseEvent (
        string eventType,
        address to,
        uint timestamp,
        uint amount
    );
    
    /******************************************** MODIFIERS ********************************************/
    modifier onlyManager {
        require(msg.sender == manager, "Only manager can call this function.");
        _;
    }
    
    modifier onlyCarDealer {
        require(msg.sender == carDealer, "Only car dealer can call this function.");
        _;
    }
    
    modifier onlyDriver {
        require(msg.sender == taxiDriver.driverAdress, "Only the driver can call this function.");
        _;
    }
    
    modifier onlyParticipants {
        require(participants[msg.sender].participantAdress == msg.sender, "Only participants can call this function.");
        _;
    }
    
    /******************************************* CONSTRUCTOR *******************************************/
    constructor() public {
        manager = msg.sender;
        contractBalance = 0;
        
        // Set times
        startTime = now;
        lastDividendTime = now;
        lastCarExpensesTime = now;
    }
    
    /******************************************** GETTERS **********************************************/
    function getParticipantCount() public view returns(uint) {
        return participantArray.length;
    }
    
    function getParticipantDetails(uint participantIndex) public view returns(uint, address payable, uint, uint) {
        return (
            participantIndex,
            participantArray[participantIndex],
            address(participantArray[participantIndex]).balance,
            participants[participantArray[participantIndex]].account
        );
    }
    
    /******************************************* FUNCTIONS *********************************************/
    //
    function join() external payable {
        require(participantArray.length < 9, 'Maximum participant count (9) has been reached!');
        require(msg.value == participationFee, 'Sent value must be 100 ether!');
        require(participants[msg.sender].participantAdress != msg.sender, 'This account already participated into the contract');
        
        // Increase the contractBalance
        contractBalance += participationFee;
    
        // Insert the address into participants
        participants[msg.sender] = Participant({participantAdress: msg.sender, account: 1 ether});
        participantArray.push(msg.sender);
    }
    
    //
    function setCarDealer(address payable _carDealer) public onlyManager {
        carDealer = _carDealer;
    }
    
    //
    function carProposeToBusiness(uint256 _carID, uint _price, uint _offerValidTime) public onlyCarDealer {
        proposedCar = ProposedCar({
            carID: _carID,
            price: _price,
            offerValidTime: _offerValidTime,
            approvalState: 0
        });
        
        // Clear participant votings
        for (uint i = 0; i < participantArray.length; i++) {
            proposedCar.approvedParticipants[participantArray[i]] = false;
        }
    }
    
    //
    function approvePurchaseCar() public onlyParticipants {
        require(proposedCar.approvedParticipants[msg.sender] == false, 'This participant already approved for this car.');

        proposedCar.approvedParticipants[msg.sender] = true;
        proposedCar.approvalState++;
    }
    
    //
    function purchaseCar() public onlyManager {
        require(now < proposedCar.offerValidTime, 'Offer valid time has been exeeded.');
        require(proposedCar.approvalState > (participantArray.length / 2), 'More than half of the participants must approve to be able to purchase the car.');
        
        ownedCar = proposedCar.carID;
        
        emit MaintenanceExpenseEvent('Car Purchase', carDealer, now, proposedCar.price);
        carDealer.transfer(proposedCar.price);  // Transfer the price
    }
    
    // 
    function repurchaseCarPropose(uint256 _carID, uint _price, uint _offerValidTime) public onlyCarDealer {
        proposedRepurchaseCar = ProposedCar({
            carID: _carID,
            price: _price,
            offerValidTime: _offerValidTime,
            approvalState: 0
        });
        
        // Clear participant votings
        for (uint i = 0; i < participantArray.length; i++) {
            proposedRepurchaseCar.approvedParticipants[participantArray[i]] = false;
        }
    }
    
    //
    function approveSellProposal() public onlyParticipants {
        require(proposedRepurchaseCar.approvedParticipants[msg.sender] == false, 'This participant already approved for this car.');
        
        proposedRepurchaseCar.approvedParticipants[msg.sender] = true;
        proposedRepurchaseCar.approvalState++;
    }
    
    //
    function repurchaseCar() public payable onlyCarDealer {
        require(now < proposedRepurchaseCar.offerValidTime && proposedRepurchaseCar.approvalState > (participantArray.length / 2));
    }
    
    // 
    function proposeDriver(address payable _driverAdress, uint _salary) public onlyManager {
        proposedDriver = ProposedDriver({
            taxiDriver: TaxiDriver({
                driverAdress: _driverAdress,
                salary: _salary,
                account: 0
            }),
            approvalState: 0
        });
        
        // Clear participant votings
        for (uint i = 0; i < participantArray.length; i++) {
            proposedDriver.approvedParticipants[participantArray[i]] = false;
        }
    }
    
    //
    function approveDriver() public onlyParticipants {
        require(proposedDriver.approvedParticipants[msg.sender] == false, 'This participant already approved for this car.');

        proposedDriver.approvedParticipants[msg.sender] = true;
        proposedDriver.approvalState++;
    }
    
    //
    function setDriver() public onlyManager {
        require(proposedDriver.approvalState > (participantArray.length / 2), 'More than half of the participants must approve to be able to purchase the car.');

        taxiDriver = proposedDriver.taxiDriver;
        lastSalaryTime = now;
    }
    
    //
    function fireDriver() public onlyManager {
        taxiDriver.account += taxiDriver.salary;
        contractBalance -= taxiDriver.salary;
    }
    
    //
    function getCharge() public payable {
        contractBalance += msg.value;
    }
    
    //
    function releaseSalary() public onlyManager {
        require(now >= lastSalaryTime + 30 days);
        lastSalaryTime = now;
        
        taxiDriver.account += taxiDriver.salary;
        contractBalance -= taxiDriver.salary;
    }
    
    // 
    function getSalary() public onlyDriver {
        require (taxiDriver.account > 0);
        
        // Copy account balance
        uint tmp_account = taxiDriver.account;
        taxiDriver.account = 0;
        
        // Log the event
        emit MaintenanceExpenseEvent('Driver Salary', taxiDriver.driverAdress, now, tmp_account);
        
        // Withdraw the money
        taxiDriver.driverAdress.transfer(tmp_account);
    }
    
    // 
    function carExpenses() public onlyManager {
        require(now >= lastCarExpensesTime + 180 days);
        lastCarExpensesTime = now;
        
        // Decrement the contract balance
        contractBalance -= fixedExpenses;
        
        // Log the event
        emit MaintenanceExpenseEvent('Car Expenses', carDealer, now, fixedExpenses);
        
        // Transfer the expenses
        carDealer.transfer(fixedExpenses);
    }
    
    // 
    function payDividend() public onlyManager {
        require(now >= lastDividendTime + 180 days);
        
        // Expenses
        carExpenses();
        releaseSalary();
        
        // Share the profit among the participants
        uint dividend = contractBalance / participantArray.length;
        for (uint i = 0; i < participantArray.length; i++) {
            participants[participantArray[i]].account += dividend;
            contractBalance -= dividend;
        }
        
        lastDividendTime = now;
    }
    
    //
    function getDividend() public onlyParticipants {
        uint tmp_participant_balance = participants[msg.sender].account;
        participants[msg.sender].account = 0;
        
        // Log the event
        emit MaintenanceExpenseEvent('Participant Dividend', msg.sender, now, tmp_participant_balance);
        
        // Withdraw the money
        msg.sender.transfer(tmp_participant_balance);
    }
    
    // Fallback
    fallback() external {
        revert ();
    }
    
    receive() external payable {
        revert ();
    }
}

