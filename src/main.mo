import Blob "mo:base/Blob";
// import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import IC "./ic";
import CyclesWallet "./CyclesWallet";
import List "mo:base/List";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int64 "mo:base/Int64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import SHA256 "mo:sha256/SHA256";
import Trie "mo:base/Trie";
import Types "./types";
import Time "mo:base/Time";
import Buffer "./Buffer";
import Result "mo:base/Result";
// import AccountBlob "mo:principal/blob/AccountIdentifier";
// import Ext "mo:ext/Ext";
// import Actor "actor";
import Bool "mo:base/Bool";
import Error "mo:base/Error";
import AccountId "mo:accountid/AccountId";

import CanisterManager "./CanisterManager";
import Text "mo:base/Text";
import Utils "Utils";
import Ledger "./Ledger";
import XDR "xdr";
import Float "mo:base/Float";

shared (init) actor class () = self {
    var members : [Principal] = [ init.caller ];
    // var canisters : HashMap.HashMap<IC.canister_id, Bool> = HashMap.HashMap<IC.canister_id, Bool>(0, func(x: IC.canister_id, y: IC.canister_id) {x==y}, Principal.hash);
    // private stable var cid               : Principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");  
    private stable var _canisterIdx      : Nat = 0;  
    private stable var _historyIdx       : Nat = 0;  
    private stable var _imageIdx         : Nat = 1_000;  //Start with 1_000
    private stable var _imageCatIdx      : Nat = 0;  

    private stable var _nextSubAccount   : Nat = 0;
    private stable var _tranIdx          : Nat = 0;

    //Payment - use _nextSubAccount as index

    private stable var _canisterPrice          : Nat = 16_130*100_000_000;
    private stable var _burnRate              : Nat = 65;//Ration to burn when transaction completed
    private stable var _pendingPayments        : [(Nat, Types.Payment)] = []; //Canister List
    private var pendingPayments                : HashMap.HashMap<Nat, Types.Payment> = HashMap.fromIter(_pendingPayments.vals(), 0, Nat.equal, Nat32.fromNat);

    private stable var _payments        : [(Nat, Types.Payment)] = []; //Canister List
    private var payments                : HashMap.HashMap<Nat, Types.Payment> = HashMap.fromIter(_payments.vals(), 0, Nat.equal, Nat32.fromNat);



    // Heartbeat - System cronjob
    private stable var s_heartbeatIntervalSeconds   : Nat = 60*10;//Run cronjob every second(s)
    private stable var s_heartbeatLastBeat          : Int = 0;
    private stable var s_heartbeatOn                : Bool = true;
    private stable var _systemEnabled               : Bool = true; //Set = false if skip create new canister

    private stable var _canisters        : [(Nat, Types.CanisterInfo)] = []; //Canister List
    private var canisters                : HashMap.HashMap<Nat, Types.CanisterInfo> = HashMap.fromIter(_canisters.vals(), 0, Nat.equal, Nat32.fromNat);
    private stable var _histories        : [(Nat, Types.CanisterHistory)] = []; //Canister History
    private var histories                : HashMap.HashMap<Nat, Types.CanisterHistory> = HashMap.fromIter(_histories.vals(), 0, Nat.equal, Nat32.fromNat);

    private stable var _imageCategories  : [(Nat, Types.CanisterImageCategory)] = []; //Canister Images Category
    private var imageCategories          : HashMap.HashMap<Nat, Types.CanisterImageCategory> = HashMap.fromIter(_imageCategories.vals(), 0, Nat.equal, Nat32.fromNat);

    private stable var _canisterImages   : [(Nat, Types.CanisterImage)] = []; //Canister Images
    private var canisterImages           : HashMap.HashMap<Nat, Types.CanisterImage> = HashMap.fromIter(_canisterImages.vals(), 0, Nat.equal, Nat32.fromNat);

    private stable var _users            : [(Principal, Types.UserInfo)] = []; //Store user Info
    private var users                    : HashMap.HashMap<Principal, Types.UserInfo> = HashMap.fromIter(_users.vals(), 0, Principal.equal, Principal.hash);

    //Topup Cycle to Canister history
    private stable var _cycleIdx                : Nat = 0;
    private stable var _cyclesTransactions       : [(Nat, Types.CyclesTransaction)] = []; //Cycles transactions
    private var cyclesTransactions               : HashMap.HashMap<Nat, Types.CyclesTransaction> = HashMap.fromIter(_cyclesTransactions.vals(), 0, Nat.equal, Nat32.fromNat);

    //Deposit cycles from ICP or XCANIC
    private stable var _depositIdx              : Nat = 0;
    private stable var _depositTransactions     : [(Nat, Types.DepositTransaction)] = [];
    private var depositTransactions             : HashMap.HashMap<Nat, Types.DepositTransaction> = HashMap.fromIter(_depositTransactions.vals(), 0, Nat.equal, Nat32.fromNat);


    var logs: [(Text)] = [];
    // The upload buffer, for adding additional assets.
    private let buffer : Buffer.Buffer<Blob> = Buffer.Buffer(0);

    private var owner:Principal = init.caller;// Principal.fromText("lekqg-fvb6g-4kubt-oqgzu-rd5r7-muoce-kppfz-aaem3-abfaj-cxq7a-dqe");

    //////////////// ICP Ledger configuration ////////////////
    private let ledger  : Ledger.Interface  = actor(Ledger.CANISTER_ID);
    let ICP_FEE = 10_000 : Nat64;
    let E8S:Nat = 100_000_000;
    // Minimum ICP deposit required before converting to cycles.
    let MIN_DEPOSIT = ICP_FEE * 10;
    let CYCLE_MINTING_CANISTER = Principal.fromText("rkp4c-7iaaa-aaaaa-aaaca-cai");//Hardcode the minting canister
    let TOP_UP_CANISTER_MEMO = 0x50555054 : Nat64;
    private stable var DEFAULT_CYCLE_INIT : Nat= 300_000_000_000 ;//0.3 T, with 0.1T for fees
    private stable var MAX_CANISTER_PER_USER : Nat = 3;
    private let cycles  : XDR.Interface     = actor(XDR.CANISTER_ID);
    private stable var CYCLES_RATE: Nat = 2806700000000;//set default

  /*
  * upgrade functions
  */
  system func preupgrade() {
    _canisters          := Iter.toArray(canisters.entries());
    _histories          := Iter.toArray(histories.entries());
    _canisterImages     := Iter.toArray(canisterImages.entries());
    _imageCategories    := Iter.toArray(imageCategories.entries());
    _pendingPayments    := Iter.toArray(pendingPayments.entries());
    _payments           := Iter.toArray(payments.entries());
    _users              := Iter.toArray(users.entries());
    _cyclesTransactions := Iter.toArray(cyclesTransactions.entries());
    _depositTransactions := Iter.toArray(depositTransactions.entries());
  };

  system func postupgrade() {
    _canisters          := [];
    _histories          := [];
    _canisterImages     := [];
    _imageCategories    := [];
    _pendingPayments    := [];
    _payments           := [];
    _users              := [];
    _cyclesTransactions  := [];
    _depositTransactions := [];
  };

    // var canisters : List.List<Principal> = List.nil<Principal>();
    // var proposals : List.List<Types.Proposal> = List.nil<Types.Proposal>();
    let PASS_NUM : Nat = 2;

  ////////////////
  // Heartbeat //
  //////////////


  system func heartbeat() : async () {
      if (not s_heartbeatOn) return;

      // Limit heartbeats
      let now = Time.now();
      if (now - s_heartbeatLastBeat < s_heartbeatIntervalSeconds * 1_000_000_000) return;
      s_heartbeatLastBeat := now;
      try{
        await get_cycles_per_icp();
        // await cronUpdateEarned();
      }catch(e){
        //Nothing
      }
      // Run jobs
  };

    ////// HEART BEAT /////////////////////////
    //Todo: Get XDR rate: Cycles per ICP
    func get_cycles_per_icp() : async (){
        let resp = await cycles.get_icp_xdr_conversion_rate();
        CYCLES_RATE := (Nat64.toNat(resp.data.xdr_permyriad_per_icp)*XDR.CYCLES_PER_XDR)/10_000;
        // add_log("CYCLES_RATE: "#debug_show(CYCLES_RATE) # "| XDR: "#debug_show(Nat64.toNat(resp.data.xdr_permyriad_per_icp)));
    };

    //Show current canister cycles rate
    public query func cycles_rate() : async Nat{
        CYCLES_RATE;
    };
    //Show current canister cycles rate
    public query func settings() : async Types.InitResponse{
        {
            cycle_rate      = CYCLES_RATE;
            canister_limit  = MAX_CANISTER_PER_USER;
            canister_price  = DEFAULT_CYCLE_INIT;
            min_deposit     = MIN_DEPOSIT;
        };
    };
    //Show current canister price
    public query func price() : async Nat{
        _canisterPrice;
    };
    //Set canister price ($XCANIC)
    public shared ({ caller }) func setPrice (i : Nat ) : async (){
        assert(check_member(caller));
        _canisterPrice := i*100_000_000;
    };
    //Change init cycles for new canister
    public shared ({ caller }) func setInitCycles (i : Nat ) : async (){
        assert(check_member(caller));
        DEFAULT_CYCLE_INIT := i;
    };
    //Change maximum canister per user
    public shared ({ caller }) func setLimitCanister(i : Nat ) : async (){
        assert(check_member(caller));
        MAX_CANISTER_PER_USER := i;
    };
    //Show current burn rate price
    public query func burnRate() : async Nat{
        _burnRate;
    };
    //Set burn rate
    public shared ({ caller }) func setBurnRate (i : Nat ) : async (){
        assert(check_member(caller));
        _burnRate := i;
    };
    //Set system status
    public shared ({ caller }) func setSystemEnabled (i : Bool ) : async (){
        assert(check_member(caller));
        _systemEnabled := i;
    };

    //Get current root bucket Balance
    // public shared ({ caller }) func getBalance () : async Nat {
    //     let cid = Principal.fromActor(self);
    //     await Token.balanceOf(cid);
    // };

    //Todo: Ping before deposit
    public shared ({caller}) func deposit_ping(deposit_req: Types.DepositPing): async Result.Result<Nat, Text> {
        assert(not Principal.isAnonymous(caller));//Prevent not login
        let _user = await findOrCreateNewUser(caller);//Find or create
        let _currentIdx = _depositIdx;
        depositTransactions.put(_currentIdx, {
            deposit_req with
            amount = deposit_req.amount;
            from = caller;
            status = 0;
            created_at = Time.now();
            completed_at = 0;
            block_height = 0;
            cycles = 0;
        });//Push to pending
        _depositIdx += 1;
        #ok(_currentIdx);
    };
    //Todo: Update user cycle balance
    func update_user_cycle(user_id: Principal, cycles: Nat, method: Text): (){
        switch(users.get(user_id)){
            case (?user){
                var new_cycle_balance = user.cycle_balance;
                if(method == "add"){
                    new_cycle_balance := user.cycle_balance + cycles;
                }else{
                    new_cycle_balance := user.cycle_balance - cycles;
                };
                users.put(user_id, {
                    user with
                    cycle_balance = new_cycle_balance
                });
            };
            case _{
                ()
            }
        }
    };

    //Todo: Get caller deposits
    public query ({caller}) func my_deposits() : async [(Nat, Types.DepositTransaction)] {
        let my_array = Buffer.Buffer<(Nat, Types.DepositTransaction)>(0);
        for ((idx, deposit) in depositTransactions.entries()) {
            if(deposit.from == caller){
                my_array.add(idx, deposit);
            };
        };
        my_array.toArray();
    };
    //Todo: Get caller cycles history
    public query ({caller}) func cycles_history() : async [(Nat, Types.CyclesTransaction)] {
        let my_array = Buffer.Buffer<(Nat, Types.CyclesTransaction)>(0);
        for ((idx, history) in cyclesTransactions.entries()) {
            if(history.from == caller or history.to == caller){
                my_array.add(idx, history);
            };
        };
        my_array.toArray();
    };

    //Notify deposit by Idx
    public shared ({caller}) func deposit_notify(idx: Nat): async Result.Result<Nat, Text>{
         await notify_transaction(idx, caller);
    };
    //Todo: Proces deposit by idx
    public shared ({caller}) func deposit_process(idx: Nat): async Result.Result<Nat, Text>{
        switch(depositTransactions.get(idx)){
            case (?deposit){
                assert(deposit.status == 0 and deposit.from == caller);//Only accept status = 0: pending
                let _cid = Principal.fromActor(self);
                let from_subaccount = Utils.principalToSubAccount(deposit.from);
                let account = Utils.getAccountArrByUserId(_cid, deposit.from);
                let cycle_account = Utils.getAccountArrByUserId(CYCLE_MINTING_CANISTER, _cid);
                let to_subaccount = Utils.principalToSubAccount(Principal.fromActor(self));

                    // let icp_balance = await ledger.account_balance({ account = Blob.fromArray(account) });
                    // add_log("Balance: "#debug_show(icp_balance));
                    try {
                        let result = await ledger.transfer({
                                        to = Blob.fromArray(cycle_account);
                                        fee = { e8s = ICP_FEE };
                                        memo = TOP_UP_CANISTER_MEMO;
                                        from_subaccount = ?Blob.fromArray(from_subaccount);
                                        amount = { e8s = deposit.amount - 2*ICP_FEE };
                                        created_at_time = null;
                                    });
                        // add_log("result: " # debug_show(result));
                        switch(result){
                            case(#Ok(height)){
                                depositTransactions.put(idx, {
                                    deposit with
                                    status = 1;//Depositing
                                    block_height = Nat64.toNat(height);
                                    amount = deposit.amount;
                                    completed_at = Time.now();
                                });
                                // add_log("Height: "#debug_show(height));

                                //Todo: Notify
                                await notify_transaction(idx, caller);
                                // return #ok(Nat64.toNat(height));
                            };
                            case (#Err(#InsufficientFunds { balance })) {
                                #err("Top me up! The balance is only " # debug_show balance # " e8s");
                            };
                            case(#Err(e)){
                                #err("Can not topup! "# debug_show(e))
                            };
                        };
                    }catch(err){
                        #err(Error.message(err))
                    }
                };
                case _ {
                   #err("Transaction not found!")
                }
            };
    };

    //Todo: Notify DFX
    func notify_transaction(idx: Nat, depositer: Principal): async Result.Result<Nat, Text>{
         switch(depositTransactions.get(idx)){
            case (?deposit){
                assert(deposit.status == 1 and deposit.from == depositer);//Only accept status = 1 - depositing
                let from_subaccount = Utils.principalToSubAccount(deposit.from);
                let to_subaccount = Utils.principalToSubAccount(Principal.fromActor(self));
                let originICP = deposit.amount - 2*ICP_FEE;
                let deposited_cycles = (Nat64.toNat(originICP)*CYCLES_RATE)/E8S;
                // let ending_cycles = Cycles.balance();
                // add_log("originICP: "#debug_show(originICP)#" | cyclesRate: "#debug_show(CYCLES_RATE)#" | deposited_cycles: " # debug_show(deposited_cycles));


                // let starting_cycles: Nat = Cycles.balance();
                try {
                     if (deposited_cycles > 0) {
                        let result_notify = await ledger.notify_dfx({
                                                to_canister = CYCLE_MINTING_CANISTER;
                                                block_height = Nat64.fromNat(deposit.block_height);
                                                from_subaccount = ?Blob.fromArray(from_subaccount);
                                                to_subaccount = ?Blob.fromArray(to_subaccount);
                                                max_fee = { e8s = ICP_FEE };
                                            });
                        // add_log("result_notify: " # debug_show(result_notify));
                   
                        // TODO: notify user
                        // let deposited_cycles: Nat = ending_cycles - starting_cycles;//Caculate the cycles balance
                        // add_log("Start: " # debug_show(starting_cycles) # " | Ending: "#debug_show(ending_cycles)#" | Deposited: "#debug_show(deposited_cycles));
                        update_user_cycle(deposit.from, deposited_cycles, "add");//Update user's cycles

                        //Completed transaction
                        depositTransactions.put(idx, {
                                            deposit with
                                            status = 2;//Completed
                                            cycles = deposited_cycles;
                                            completed_at = Time.now();
                                        });
                        //Add deposit transaction
                        add_cycles_transaction({
                            from = Principal.fromActor(self);
                            to = deposit.from;
                            amount = deposited_cycles;
                            time = Time.now();
                            method = 0;
                        }); 
                         #ok(1);              
                    }else{
                         #err("Deposit amount is invalid, please check again!");
                    }
                   
                }catch(err){
                    #err(Error.message(err))
                }
            };
            case _ {
                #err("Transaction not found!")
            }
         }
    };

    public query({caller}) func get_users() : async [(Principal, Types.UserInfo)] {
        assert(check_member(caller));
        Iter.toArray(users.entries());
    };
    public query({caller}) func get_deposits() : async [(Nat, Types.DepositTransaction)] {
        assert(check_member(caller));
        Iter.toArray(depositTransactions.entries());
    };

    func add_log(txt: Text):(){
        var _logs = List.fromArray(logs);
        logs := List.toArray(List.push(txt, _logs));
    };
    public query({caller}) func get_logs() : async [(Text)] {
        assert(check_member(caller));
        logs;
    };

    //Todo: Find existing user or create new
    func findOrCreateNewUser(userId: Principal): async Types.UserInfo{
        switch(users.get(userId)){
            case (?user){
                user;
            };
            case _ {
                let subaccount = Utils.principalToSubAccount(userId);
                let _account = Utils.toHex(AccountId.fromPrincipal(Principal.fromActor(self), ?subaccount));
                let _userInfo = {
                    id              = userId;
                    username        = "";
                    account         = _account; //Set account id by user principal, for topup cycle
                    verified        = false;
                    bio             = "";
                    cycle_balance   = 0;//Available to Topup
                    title           = "";//Member, Canister Team, Dfinity Foundation...ect
                    links           = ?[];//Social Link, email..
                    updated_at      = Time.now();
                    created_at      = Time.now();
                };
                users.put(userId, _userInfo);
                _userInfo;
            };
        };

    };
    //Todo: Check user info
    func get_user_info(userId: Principal): Types.UserInfo{
        switch(users.get(userId)){
            case (?user){
                user;
            };
            case _ {
                let subaccount = Utils.principalToSubAccount(userId);
                let _account = Utils.toHex(AccountId.fromPrincipal(Principal.fromActor(self), ?subaccount));
                let _userInfo = {
                    id              = userId;
                    username        = "";
                    account         = _account; //Set account id by user principal, for topup cycle
                    verified        = false;
                    bio             = "";
                    cycle_balance   = 0;//Available to Topup
                    title           = "";//Member, Canister Team, Dfinity Foundation...ect
                    links           = ?[];//Social Link, email..
                    updated_at      = Time.now();
                    created_at      = Time.now();
                };
                _userInfo;
            };
        };
    };

    public query ({ caller }) func me() : async Types.UserInfo {
        assert(not Principal.isAnonymous(caller));//Prevent not login
        get_user_info(caller);
    };


    //Get my canister
    public query ({ caller }) func my_canister() : async Types.CanisterResponse {
        // var my_canisters : [(Nat, Types.CanisterInfo)] = [];
        let my_canisters = Buffer.Buffer<(Nat, Types.CanisterInfo)>(0);
        for ((idx, canis) in canisters.entries()) {
            if(canis.owner == caller){
                // my_canisters := Array.append(my_canisters, [(idx, canis)]);
                my_canisters.add(idx, canis);
            };
        };
        my_canisters.toArray();
    };

    //get canister detail
    public query ({ caller }) func get_canister(canister_id: IC.canister_id) : async Result.Result<Types.CanisterInfo, Text> {
        let _currentIdx = findIdxByCanisterId(canister_id);
        switch(canisters.get(_currentIdx)){
            case (?canister){
                #ok(canister);
            };
            case _ {
                #err("Not found or unauthorized!");
            };
        };
    };
    //get canister status from IC
    public shared ({ caller }) func get_canister_status(canister_id: IC.canister_id) : async Result.Result<Types.CanisterStatus, Text> {
        try{
            let ic_canister_status  = await CanisterManager.canister_status(canister_id);
            update_canister_cycles(canister_id, ic_canister_status.cycles);//Update cycles -> canisterInfo to monitor!
            #ok(ic_canister_status);
        }catch(e){
            let message = Error.message(e);
            #err(message);
         }
    };

    //Get payment transactions
    public query func transactions () : async [(Nat, Types.Payment)] {
        Iter.toArray(payments.entries());
    };
    //Use must approved *amount* TOKEN before
        // public shared ({ caller }) func makePayment() : async Result.Result<IC.canister_id, Text>{
        //   //Step 1. TransferFrom approved
        //    assert(_systemEnabled);//Check system status!
        //    switch(await settle(caller, _canisterPrice)){
        //         case(#Ok(txId)){
        //             //Step 2. Create Canister
        //             let _canisterId = await create_canister(caller, "My Canister");
        //             return _canisterId;
        //         };
        //         case(#Err(error)){
        //            return #err("Error");
        //         };
        //    };
        // };

    //Todo: Add cycles transaction
    func add_cycles_transaction(data: Types.CyclesTransaction): (){
        cyclesTransactions.put(_cycleIdx, data);
        _cycleIdx += 1;//Increase idx
    };
    func get_user_canister(owner: Principal): Nat{
        var _counter:Nat = 0;
        for ((idx, canis) in canisters.entries()) {
            if(canis.owner == owner){
               _counter += 1;
            };
        };
        _counter;
    };
    //Open create new canister without authen
    public shared ({ caller }) func create_new_canister(canisterName: Text) : async Result.Result<IC.canister_id, Text>{
       assert(_systemEnabled);//Check system status!
       assert(not Principal.isAnonymous(caller));//Prevent not login
       //Check user cycle balance
       let user = get_user_info(caller);
       let user_canister = get_user_canister(caller);//Count the canister of user
       if(user.cycle_balance < DEFAULT_CYCLE_INIT){
            #err("Insufficient cycle balance, please deposit to continue!");
       }else if(user_canister >= MAX_CANISTER_PER_USER){
            #err("You have reached the limit canister: "#Nat.toText(MAX_CANISTER_PER_USER));
       }else{
            switch(await create_canister(caller, canisterName)){
                case (#ok(canisterId)){
                    update_user_cycle(caller, DEFAULT_CYCLE_INIT, "minus");//Minus from user's cycle balance
                    //Add transaction
                    add_cycles_transaction({
                            from = caller;
                            to = canisterId;
                            amount = DEFAULT_CYCLE_INIT;
                            time = Time.now();
                            method = 1;
                        });
                    #ok(canisterId);
                };
                case(#err(e)){
                    #err(debug_show(e))
                };
            }
       }
       
       
    };

    //Transfer token from approved
    // func settle(from: Principal, amount: Nat): async Actor.TxReceipt{
    //    let cid = Principal.fromActor(self);

    //    switch(await Token.transferFrom(from, cid, amount)){
    //     case(#Ok(txId)){
    //         //Add to payment
    //         payments.put(_tranIdx, {
    //                 txId        = txId;
    //                 from        = from;
    //                 to          = cid;//pay Address
    //                 amount      = amount;//Discount
    //                 time        = Time.now();
    //             });
    //         _tranIdx += 1;
    //         return #Ok(txId);
    //     };
    //     case(#Err(error)){
    //         return #Err(error);
    //     };
    //    }
    // };
    /////// END PAYMENT ////////////////////////
    //Create and store WASM module
    public shared({caller}) func upload(
            bytes   : [Blob],
        ) : () {
        assert(check_member(caller));
            for (byte in bytes.vals()) {
                buffer.add(byte);
            }
    };
    // Clear the upload buffer
    public shared({caller}) func upload_clear() : () {
        assert(check_member(caller));
        buffer.clear();
    };

    //Finalize upload and add module
    public shared({caller}) func add_canister_image(image: Types.CanisterImageInit) : async (){
        assert(check_member(caller));
        let _wasm = buffer.toArray();

        let _wasm_module: Types.CanisterImage = {
            name        = image.name;
            thumbnail   = image.thumbnail;
            code        = image.code;
            creator     = caller;
            brief       = image.brief;
            price       = image.price;
            metadata    = image.metadata;
            description = image.description;
            wasm        = _wasm;
            category    = image.category;
            repo        = image.repo;
            created     = Time.now();
            updated     = Time.now();
            approved    = true;
            verified    = true;
        };
        await local_add_image(_wasm_module);
        buffer.clear();
    };

    //Edit canister template
    public shared({caller}) func edit_canister_image(imageId: Nat, image: Types.CanisterImageInit) : async Result.Result<Bool, Text>{
        assert(check_member(caller));
        switch (canisterImages.get(imageId)) {
            case (?imageCheck){
                let _image = {
                    imageCheck with
                    name        = image.name;
                    thumbnail   = image.thumbnail;
                    code        = image.code;
                    description = image.description;
                    category    = image.category;
                    brief       = image.brief;
                    price       = image.price;
                    metadata    = image.metadata;
                    repo        = image.repo;
                    updated     = Time.now();
                };
                await local_edit_image(imageId, _image);
                #ok(true);
            };
            case _ {
                #err("Image Not found");
            };
        }
    };

    // Get Category
    public query func get_categories() : async Types.ImageCategoryResponse {
       Iter.toArray(imageCategories.entries());
    };
    // Create Category
    public shared({caller}) func create_category(name: Text, description: Text) : () {
        assert(check_member(caller));
        imageCategories.put(_imageCatIdx, {
            name        = name;
            description = description;
            status      = 1;
        });
        _imageCatIdx +=1;
    };

    // Get All Images
    public query func get_images() : async Types.CanisterImageResponse {
       Iter.toArray(canisterImages.entries());
    };

    //Get all image: Return by id and name - Mapping
    public query ({ caller }) func get_images_list() : async Types.CanisterImageMapping {
        let images = Buffer.Buffer<(Nat, Types.ImageMapping)>(0);
        for ((idx, img) in canisterImages.entries()) {
           images.add(idx, { name = img.name; code = img.code });
        };
        images.toArray();
    };

    // Update Template use function edit_canister_image
    // Delete template
    public shared({caller}) func delete_templates(idx: Nat) : async Result.Result<Bool, Text> {
        assert(check_member(caller));
        switch (canisterImages.get(idx)) {
            case (?image){
                canisterImages.delete(idx);
                #ok(true);
            };
            case _ {
                #err("Template not found");
            };
        }
    };

    public query func get_image(idx: Nat): async Result.Result<Types.CanisterImageNoWasm, Text>{
        switch (canisterImages.get(idx)) {
            case (?image){
                #ok(image);
            };
            case _ {
                #err("Not found");
            };
        }
    };

    //Local function, create canister with creator params
    func create_canister(creator: Principal, canisterName: Text) : async Result.Result<IC.canister_id, Text> {
        // assert(check_member(caller));
         switch(await CanisterManager.create_canister(Principal.fromActor(self), creator, DEFAULT_CYCLE_INIT)){
            case (#ok(canister_id)){
                canisters.put(_canisterIdx, {
                    canisterId  = canister_id;
                    canisterName= canisterName;
                    owner       = creator;
                    created     = Time.now();
                    updated     = Time.now();
                    imageId     = 0;
                    status      = 0;
                    canisterType= 0;//Created
                    cycles      = DEFAULT_CYCLE_INIT;//Initial Cycles
                    cycles_updated = Time.now();
                });
                _canisterIdx += 1;
                // update_canister_status(result.canister_id, 0);
                add_canister_history(canister_id, 0, "create", creator, canisterName, "");
                #ok(canister_id);
            };
            case (#err(e)) {
                return #err(e);
            };
        };
    };

    //control canister: Install-Reinstall
    public shared({caller}) func canister_control(canister_id : IC.canister_id, canister_name: Text, action: Text, image_id: Nat, arg: [Nat8]) : async Result.Result<Bool, Text>{
        assert(check_canister_owner(caller, canister_id));
        switch(action){
            case ("install"){
                await install_code(canister_id, canister_name, image_id, caller, arg);
            };
            case ("reinstall"){
                await reinstall_code(canister_id, canister_name, image_id, caller, arg);
            };
            case _ {
                #err("Action not valid!");
            }
        }
    };

    //canister action: start/stop/delete
    public shared({caller}) func canister_action(canister_id : IC.canister_id, action: Text) : async Result.Result<Bool, Text>{
        assert(check_canister_owner(caller, canister_id));
        switch(action){
            case ("start"){
                let _status = await start_canister(canister_id, caller);
                _status;
            };
            case ("stop"){
                let _status = await stop_canister(canister_id, caller);
                _status;
            };
            case ("delete"){
                let _status = await delete_canister(canister_id, caller);
                _status;
            };
            case _ {
                #err("Action not valid!");
            }
        }
    };

    //Install canister module with image id
    func install_code(canister_id : IC.canister_id, canister_name: Text, image_id : Nat, caller: Principal, arg: [Nat8]) : async Result.Result<Bool, Text>{
        switch (canisterImages.get(image_id)) {
            case (?image){
                var _image = await _flattenPayload(image.wasm);
                switch(await CanisterManager.install_code(canister_id, arg, _image)){
                    case (#ok(_)){
                        add_canister_history(canister_id, image_id, "install", caller, canister_name, image.name);
                            //Update canister with image id
                            update_canister_image(canister_id, canister_name, image_id);
                            let _nextStatus = await start_canister(canister_id, caller); //Start after installed
                            return #ok(true);
                    };
                    case (#err(e)) {
                        return #err(e);
                    };
                }
            };
            case _ {
                return #err("Canister image not found, please check it again.");
            };
        }
        
    };

    //Reinstall code with image id
    func reinstall_code(canister_id : IC.canister_id, canister_name: Text, image_id : Nat, caller: Principal, arg: [Nat8]) : async Result.Result<Bool, Text>{
         switch (canisterImages.get(image_id)) {
            case (?image){
                var _image = await _flattenPayload(image.wasm);
                switch(await CanisterManager.reinstall_code(canister_id, arg, _image)){
                    case (#ok(_)){
                        add_canister_history(canister_id, image_id, "reinstall", caller, canister_name, image.name);
                        update_canister_image(canister_id, canister_name, image_id);
                        let _nextStatus = await start_canister(canister_id, caller); //Start after reinstalled
                        return #ok(true);
                    };
                    case (#err(e)) {
                        return #err(e);
                    };
                }
            };
            case _ {
               return #err("Canister image not found, please check it again.");
            };
        }
    };

    //Start canister
    func start_canister(canister_id : IC.canister_id, caller: Principal) : async Result.Result<Bool, Text>{
         try{
            await CanisterManager.start_canister(canister_id);
            add_canister_history(canister_id, 0, "start", caller, "", "");
            //Update Canister status
            update_canister_status(canister_id, 1); //Running
            return #ok(true);
         }catch(e){
            let message = Error.message(e);
            return #err(message);
         }
    };

    //Stop canister
    func stop_canister(canister_id : IC.canister_id, caller: Principal) : async Result.Result<Bool, Text>{
         try{
            await CanisterManager.stop_canister(canister_id);
            add_canister_history(canister_id, 0, "stop", caller, "", ""); //Add history
            update_canister_status(canister_id, 2);//Stopped => Update Canister status
            return #ok(true);
         }catch(e){
            let message = Error.message(e);
            return #err(message);
         }
    };

    //Delete canister
    func delete_canister(canister_id : IC.canister_id, caller: Principal) : async Result.Result<Bool, Text>{
        try{
            await CanisterManager.delete_canister(canister_id);
            add_canister_history(canister_id, 0, "delete", caller, "", "");
            //Update Canister status
            update_canister_status(canister_id, 3);//Deleted => Update Canister status
            return #ok(true);
        }catch(e){
            let message = Error.message(e);
            return #err(message);
        }
    };

    public shared({caller})  func get_cycles() : async Types.Balance {
        let _cycles = {
            available   = Cycles.available();
            balance     = Cycles.balance();
        };
        _cycles;
    };

    //Receive Cycles
     public func wallet_receive(): async (){
        let amout = Cycles.available();
        let accepted = Cycles.accept(amout);
    };
    //cycles withdraw: _onlyOwner
    public shared({caller}) func cycles_withdraw(_wallet: Principal, _amount: Nat): async (){
        assert(check_member(caller));
        let cyclesWallet: CyclesWallet.Self = actor(Principal.toText(_wallet));
        let balance = Cycles.balance();
        var value: Nat = _amount;
        if (balance <= _amount) {
            value := balance;
        };
        Cycles.add(value);
        await cyclesWallet.wallet_receive();
        //Cycles.refunded();
    };
    

    // show Admin
    public query func get_admins() : async [Principal] {
        members
    };

    // get canister history
    public query func get_canister_history(canister_id: IC.canister_id) : async Types.HistoryResponse{
        // var _canister_history : Types.HistoryResponse = [];

         let _canister_history = Buffer.Buffer<(Nat, Types.CanisterHistory)>(0);
        for ((idx, history) in histories.entries()) {
             if(history.canisterId == canister_id){
                // _canister_history := Array.append(_canister_history, [(idx, history)]);
                _canister_history.add(idx, history);
            };
           
        };
        _canister_history.toArray();

        // for ((idx, history) in histories.entries()) {

        //     if(history.canisterId == canister_id){
        //         _canister_history := Array.append(_canister_history, [(idx, history)]);
        //     };
        // };
        // _canister_history;
    };

    // get canisters
    public query({caller}) func get_canisters() : async Types.CanisterResponse{
        assert(check_member(caller));
        Iter.toArray(canisters.entries());
    };

    // get caller Principal
    public shared (msg) func whoami() : async Principal {
        Debug.print("caller : " # Principal.toText(msg.caller));
        msg.caller
    };


    // local func ###################################################
    func update_canister_cycles(canister_id: IC.canister_id, cycles: Nat){
         let _currentIdx = findIdxByCanisterId(canister_id);
        switch(canisters.get(_currentIdx)){
            case (?canister){
                canisters.put(_currentIdx, {
                        canister with
                        cycles      = cycles;
                        cycles_updated = Time.now();
                    });
            };
            case _ {
                return;
            };
        };
    };
    func update_canister_status(canister_id: IC.canister_id, status: Nat){
        let _currentIdx = findIdxByCanisterId(canister_id);
        // let _canister = canisters.get(_currentIdx); //Get canister info
        switch(canisters.get(_currentIdx)){
            case (?canister){
                canisters.put(_currentIdx, {
                        canister with 
                        status = status;//0-Ready, 1-Running, 2-Stoped, 3-Deleted
                        updated = Time.now();
                    });
            };
            case _ {
                return;
            };
        };
    };
    //Update image when install/reinstall, set status = 0 - ready
    func update_canister_image(canister_id: IC.canister_id, canister_name: Text, imageId: Nat){
        let _currentIdx = findIdxByCanisterId(canister_id);
        // let _canister = canisters.get(_currentIdx); //Get canister info
        switch(canisters.get(_currentIdx)){
            case (?canister){
                canisters.put(_currentIdx, {
                        canister with 
                        imageId;
                        canisterName= canister_name;
                        cycles      = 0;
                        cycles_updated = Time.now();
                        status      = 0; //0-Ready, 1-Running, 2-Stoped, 3-Deleted
                    });
            };
            case _ {
                return;
            };
        };
    };
    //Create canister history
    func add_canister_history(canister_id: IC.canister_id, image_id: Nat, action: Text, maker: Principal, canisterName: Text, imageName: Text): () {
         histories.put(_historyIdx, {
            canisterId  = canister_id;
            maker       = maker;
            imageId     = image_id;
            action      = action;
            imageName   = imageName;
            canisterName= canisterName;
            time        = Time.now();
        });
        _historyIdx += 1;
    };
    // check if caller is in member list
    func check_member(principal : Principal) : Bool{
        let l = List.fromArray(members);
        List.some(l, func (a : Principal) : Bool { a == principal})
    };

    // check owner of canister
    func check_canister_owner(caller: Principal, canister_id: IC.canister_id): Bool{
        switch (canisters.get(findIdxByCanisterId(canister_id))) {
            case (?canister){
                return (canister.owner == caller);
            };
            case _ {
                return false;
            };
        }
    };
    // add pricipal to member list
    func addMember(principal : Principal) {
        var memberList = List.fromArray(members);
        members := List.toArray(List.push(principal, memberList));
    };

    // del principal to member list
    func deleteMember(principal : Principal) {
        var memberList = List.fromArray(members);
        let a = List.filter(memberList, func(t : Principal) : Bool { t == principal});
    };

    // Turn a list of blobs into one blob.
    func _flattenPayload (payload : [Blob]) : async Blob {
        Blob.fromArray(
            Array.foldLeft<Blob, [Nat8]>(payload, [], func (a : [Nat8], b : Blob) {
                Array.append(a, Blob.toArray(b));
            })
        );
    };
    //Find index by canister id
    func findIdxByCanisterId(canisterId: IC.canister_id) : Nat {
        var currentIdx:Nat = 0;
        for ((idx, canister) in canisters.entries()) {
            if(canister.canisterId == canisterId){
                currentIdx := idx;
            }
        };
        return currentIdx;
    };

    
    func local_add_image(record : Types.CanisterImage) : async () {
        canisterImages.put(_imageIdx, record);
        _imageIdx +=1;
    };
    func local_edit_image(imageIdx: Nat, record : Types.CanisterImage) : async () {
        canisterImages.put(imageIdx, record);
    };
};
