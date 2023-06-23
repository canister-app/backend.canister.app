import List "mo:base/List";
import IC "./ic";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";

module {
    public type ExecuteMethod = {
        #create;
        #install;
        #reinstall;
        #start;
        #stop;
        #delete;
    };

    //User map
    public type User = {
        id              : Principal;
        var username        : Text;
        account         : Text; //Set account id by user principal, for topup cycle
        var verified        : Bool;
        var bio             : Text;
        var cycle_balance   : Nat;//Available to Topup
        var title           : Text;//Member, Canister Team, Dfinity Foundation...ect
        var links           : ?[(Text, Text)];//Social Link, email..
        var updated_at      : Time.Time;
        created_at      : Time.Time;
    };
    public type UserInfo = {
        id              : Principal;
        username        : Text;
        account         : Text; //Set account id by user principal, for topup cycle
        verified        : Bool;
        bio             : Text;
        cycle_balance   : Nat;//Available to Topup
        title           : Text;//Member, Canister Team, Dfinity Foundation...ect
        links           : ?[(Text, Text)];//Social Link, email..
        updated_at      : Time.Time;
        created_at      : Time.Time;
    };

    //Topup transactions
    public type CyclesTransaction = {
        from           : Principal;//From account 
        to             : Principal;//Canister ID
        amount         : Nat;//Cycles
        method         : Nat;//0: From Deposit, 1: Create new canister, 2: Topup to other canister
        time           : Time.Time;           
    };
    //Deposit transactions
    public type DepositPing = {
        from_account   : Text;
        to_account     : Text;//Sub account, generate by "to" principal
        amount         : Nat64;//ICP e8s
    };

    public type DepositTransaction = {
        from           : Principal;
        from_account   : Text;
        to_account     : Text;//Sub account, generate by "to" principal
        amount         : Nat64;//ICP e8s
        cycles         : Nat;//Cycle balance swap from ICP
        block_height   : Nat;
        status         : Nat;//0: Pending, 1: Processing, 2: Completed
        created_at     : Time.Time;           
        completed_at   : Time.Time;           
    };

    public type CanisterInfo = {
        canisterId      : IC.canister_id;
        canisterName    : Text;//Custom name
        canisterType    : Nat;//0-created, 1-linked (allow link from existed canister)
        imageId         : Nat; //ID of image
        created         : Time.Time;
        updated         : Time.Time;
        cycles          : Nat;
        cycles_updated  : Time.Time; 
        owner           : Principal; //Canister owner
        status          : Nat;//0-Created, 1-Running, 2-Stoped, 3-Deleted 
    };

    public type InitResponse = {
        cycle_rate      : Nat;
        canister_limit  : Nat;
        canister_price  : Nat;
        min_deposit     : Nat64;
    };
    public type CanisterResponse = [(
        Nat,
        CanisterInfo
    )];

    public type HistoryResponse = [(
        Nat,
        CanisterHistory
    )];
    
    public type CanisterImageResponse = [(
        Nat,
        CanisterImageNoWasm
    )];

    public type CanisterImageMapping = [(
        Nat,
        ImageMapping
    )];
    
    public type ImageMapping = {
        name        : Text;
        code        : Text;
    };
    public type ImageCategoryResponse = [(
        Nat,
        CanisterImageCategory
    )];

    public type CanisterHistory = {
        canisterId  : IC.canister_id; //Canister Index
        maker       : Principal;
        action      : Text;
        imageName   : Text;//Tracking install image
        canisterName: Text;//Tracking canister name
        time        : Time.Time;
    };

    public type ImageStats = {
        deployed    : Nat;//
        lastDeployed: Time.Time;
    };
    public type Balance = {
        available   : Nat;
        balance     : Nat;
    };

    public type CanisterImageInit = {
        name        : Text;
        thumbnail   : ?Text;//Base64 logo
        code        : Text;
        category    : Nat; //Idx of Image Category
        brief       : Text;
        description : Text;
        price       : Nat64; //0-Free
        repo        : Text; //Github, gitlab..
        metadata    : ?[(Text, Text)];//Extra metadata. ex version
    };

    public type CanisterImage = {
        name        : Text;
        thumbnail   : ?Text;//Base64 logo
        code        : Text;
        creator     : Principal;
        wasm        : [Blob];
        category    : Nat; //Idx of Image Category
        brief       : Text;
        description : Text;
        price       : Nat64; //0-Free
        metadata    : ?[(Text, Text)];//Extra metadata.
        repo        : Text; //Github, gitlab..
        // hash        : [Nat8];
        //Managed by system
        created     : Time.Time;
        updated     : Time.Time;
        approved    : Bool;//Every image uploaded by user need to be approved by Canister team
        verified    : Bool;//Checkmark for real publisher (manual check by Canister team)
    };

    public type CanisterImageCategory = {
        name        : Text;
        description : Text;
        status      : Nat; //0-Inactive, 1-Active
    };

    public type CanisterImageNoWasm = {
        name        : Text;
        thumbnail   : ?Text;//Base64 logo
        code        : Text;
        creator     : Principal;
        brief       : Text;        
        description : Text;
        price       : Nat64; //0-Free
        metadata    : ?[(Text, Text)];//Extra metadata.
        repo        : Text;
        // hash        : [Nat8];
        category    : Nat; //Idx of Image Category
        created     : Time.Time;
        updated     : Time.Time;
        approved    : Bool;//Every image uploaded by user need to be approved by Canister team
        verified    : Bool;//Checkmark for real publisher (manual check by Canister team)
    };

    public type Payment = {
        txId        : Nat;
        from        : Principal;
        // account     : Nat;//Subaccount of pay address. Use index as subacc
        to          : Principal;//pay Address
        amount      : Nat;//Discount
        time        : Time.Time;
    };

    public type CanisterSettings = {
        freezing_threshold  : Nat;
        controllers         : [Principal];
        memory_allocation   : Nat;
        compute_allocation  : Nat;
    };
    public type CanisterStatus = {
        status              : { #stopped; #stopping; #running };
        freezing_threshold  : Nat;
        memory_size         : Nat;
        cycles              : Nat;
        settings            : CanisterSettings;
        module_hash         : ?[Nat8];
        // idle_cycles_burned_per_second : Float;
    };
    public type CanisterStatusResponse = {
        canister_status : CanisterStatus;
        canister_info   : CanisterInfo;
    };

    public type PaymentResponse = {
        #Ok : Principal;
        #Err : {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other : Text;
            #BlockUsed;
            #AmountTooSmall;
        };
    };
    public type Whoami = actor{
        whoami : shared() -> async Principal;
    }
    
}